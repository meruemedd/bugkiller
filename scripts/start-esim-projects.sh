#!/usr/bin/env bash
# 启动本机 ESIM_B / ESIM_A / ESIM_I（从 projects.json 读取 path + start 命令）
# 用法:
#   bash scripts/start-esim-projects.sh
#   bash scripts/start-esim-projects.sh --restart
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

RESTART=0
for arg in "$@"; do
  case "$arg" in
    --restart) RESTART=1 ;;
  esac
done

CONFIG="$ROOT/projects.json"
if [[ ! -f "$CONFIG" && -f "$ROOT/projects.esim.json" ]]; then
  echo "[start-esim] 使用 projects.esim.json → projects.json"
  cp "$ROOT/projects.esim.json" "$CONFIG"
fi
if [[ ! -f "$CONFIG" ]]; then
  echo "[start-esim] 缺少 projects.json，先 discover…"
  ESIM_ROOT="${ESIM_ROOT:-/Users/air/Documents/code/ESIM}" bash "$ROOT/scripts/discover-esim.sh" --write
fi

if [[ "$RESTART" == "1" ]]; then
  bash "$ROOT/scripts/stop-esim-projects.sh" || true
fi

# 用 node 解析 JSON，避免依赖 jq
mapfile -t LINES < <(node --input-type=module <<'EOF'
import { readFileSync, existsSync } from "node:fs";
import { resolve, isAbsolute, join } from "node:path";

const root = process.env.BK_ROOT || process.cwd();
const cfgPath = join(root, "projects.json");
const raw = JSON.parse(readFileSync(cfgPath, "utf8"));
const projectsRoot = (process.env.ESIM_ROOT || raw.projectsRoot || "").trim();
const base = projectsRoot
  ? isAbsolute(projectsRoot)
    ? projectsRoot
    : resolve(root, projectsRoot)
  : root;

function absPath(p) {
  return isAbsolute(p) ? p : resolve(base, p);
}

function detectStart(abs, name) {
  const pkg = join(abs, "package.json");
  if (existsSync(pkg)) {
    try {
      const j = JSON.parse(readFileSync(pkg, "utf8"));
      if (j.scripts?.dev) return "npm run dev";
      if (j.scripts?.start) return "npm start";
      if (j.scripts?.serve) return "npm run serve";
    } catch {}
  }
  if (existsSync(join(abs, "docker-compose.yml")) || existsSync(join(abs, "compose.yaml"))) {
    return "docker compose up";
  }
  if (existsSync(join(abs, "gradlew"))) {
    return "bash ./gradlew installDebug";
  }
  if (existsSync(join(abs, "Pom.xml")) || existsSync(join(abs, "pom.xml"))) {
    return "mvn -q spring-boot:run";
  }
  // iOS / Android 提示型命令
  if (name === "ESIM_I" || existsSync(join(abs, "Podfile"))) {
    return "echo '[ESIM_I] 请用 Xcode 打开工程并 Run 模拟器/真机'";
  }
  if (name === "ESIM_A") {
    return "echo '[ESIM_A] 请用 Android Studio 打开工程，或配置 start 命令'";
  }
  if (name === "ESIM_B") {
    return "echo '[ESIM_B] 未检测到可启动脚本，请在 projects.json 设置 start'";
  }
  return "";
}

for (const p of raw.projects || []) {
  if (p.enabled === false) continue;
  const abs = absPath(p.path);
  const start = (p.start && String(p.start).trim()) || detectStart(abs, p.name);
  const health = p.healthUrl || "";
  console.log([p.name, abs, start, health].join("\t"));
}
EOF
)

export BK_ROOT="$ROOT"

PID_FILE="logs/esim-dev.pids"
: >"$PID_FILE"

started=0
for line in "${LINES[@]:-}"; do
  [[ -z "${line:-}" ]] && continue
  IFS=$'\t' read -r name abs start health <<<"$line"
  if [[ ! -d "$abs" ]]; then
    echo "[start-esim] 跳过 $name：目录不存在 $abs"
    continue
  fi
  if [[ -z "${start:-}" ]]; then
    echo "[start-esim] 跳过 $name：无 start 命令（可在 projects.json 配置）"
    continue
  fi

  # 纯 echo 提示：前台打印即可，不当作常驻进程
  if [[ "$start" == echo\ * ]] || [[ "$start" == echo\ [* ]]; then
    echo "[start-esim] $name 指引:"
    (cd "$abs" && bash -lc "$start") || true
    continue
  fi

  log="logs/esim-${name}.log"
  echo "[start-esim] 启动 $name → $start  (日志 $log)"
  (
    cd "$abs"
    # 有 package.json 时尽量装依赖
    if [[ -f package.json && ! -d node_modules ]]; then
      npm install >>"$ROOT/$log" 2>&1 || true
    fi
    nohup bash -lc "$start" >>"$ROOT/$log" 2>&1 &
    echo $! >>"$ROOT/$PID_FILE"
  )
  started=$((started + 1))
  ln -sfn "esim-${name}.log" "logs/esim-${name}-latest.log" 2>/dev/null || true

  if [[ -n "${health:-}" ]]; then
    ok=0
    for i in 1 2 3 4 5 6 7 8 9 10; do
      if curl -fsS --max-time 1 "$health" >/dev/null 2>&1; then
        echo "[start-esim] $name 健康检查通过 $health"
        ok=1
        break
      fi
      sleep 1
    done
    if [[ "$ok" != "1" ]]; then
      echo "[start-esim] 警告: $name 尚未通过健康检查 $health（可能仍在启动）"
    fi
  fi
done

echo "[start-esim] 已尝试启动 $started 个常驻进程。PID → $PID_FILE"
echo "[start-esim] 停止: make stop-esim"
echo "[start-esim] 联调时请把 App 的 API Base 指到电脑局域网 IP（ESIM_B）"
