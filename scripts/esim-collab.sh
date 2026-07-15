#!/usr/bin/env bash
# 电脑端协作闭环（与手机端 Working Copy / GitHub App 配合）:
#   1) 发现 ESIM_B / ESIM_A / ESIM_I
#   2) 从 GitHub pull（拿手机端刚推的改动）
#   3) 启动三项目联调
#   4) 常驻：本地改动自动 commit/push（手机再 pull）
#
# 用法:
#   make collab
#   bash scripts/esim-collab.sh
#   ESIM_ROOT=/父目录 bash scripts/esim-collab.sh
#   bash scripts/esim-collab.sh --once          # 只同步+启动一轮，不常驻监听
#   bash scripts/esim-collab.sh --no-start      # 只 git 同步，不启动
#   bash scripts/esim-collab.sh --no-discover   # 不重新发现，沿用 projects.json
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ONCE=0
NO_START=0
NO_DISCOVER=0
for arg in "$@"; do
  case "$arg" in
    --once) ONCE=1 ;;
    --no-start) NO_START=1 ;;
    --no-discover) NO_DISCOVER=1 ;;
  esac
done

echo "============================================"
echo " BugKiller × ESIM 电脑端协作"
echo " 手机改代码 → GitHub → 本机 pull → 启动联调"
echo " 本机改代码 → 自动 commit/push → 手机 pull"
echo "============================================"

# 已知本机路径时可直接用 projects.esim.json，不必再 discover
if [[ ! -f "$ROOT/projects.json" && -f "$ROOT/projects.esim.json" ]]; then
  echo "[collab] 使用已配置路径 projects.esim.json → projects.json"
  cp "$ROOT/projects.esim.json" "$ROOT/projects.json"
fi

if [[ "$NO_DISCOVER" != "1" && ! -f "$ROOT/projects.json" ]]; then
  echo
  echo "[collab] ① 发现 ESIM_B / ESIM_A / ESIM_I …"
  if [[ -n "${ESIM_ROOT:-}" ]]; then
    ESIM_ROOT="$ESIM_ROOT" bash "$ROOT/scripts/discover-esim.sh" --write
  else
    ESIM_ROOT="${ESIM_ROOT:-/Users/air/Documents/code/ESIM}" bash "$ROOT/scripts/discover-esim.sh" --write
  fi
fi

if [[ ! -f "$ROOT/projects.json" && -f "$ROOT/projects.esim.json" ]]; then
  cp "$ROOT/projects.esim.json" "$ROOT/projects.json"
fi

if [[ ! -f "$ROOT/projects.json" ]]; then
  echo "[collab] 缺少 projects.json。请设置 ESIM_ROOT 后重试。" >&2
  exit 1
fi

# 校验至少有一个 enabled 且路径存在
node --input-type=module <<'EOF' || exit 1
import { readFileSync, existsSync } from "node:fs";
import { resolve, isAbsolute, join } from "node:path";
const root = process.cwd();
const raw = JSON.parse(readFileSync(join(root, "projects.json"), "utf8"));
const projectsRoot = (process.env.ESIM_ROOT || raw.projectsRoot || "").trim();
const base = projectsRoot
  ? isAbsolute(projectsRoot) ? projectsRoot : resolve(root, projectsRoot)
  : root;
let ok = 0;
for (const p of raw.projects || []) {
  if (p.enabled === false) continue;
  const abs = isAbsolute(p.path) ? p.path : resolve(base, p.path);
  if (existsSync(abs)) {
    ok++;
    console.log(`[collab]   · ${p.name} → ${abs}`);
  } else {
    console.warn(`[collab]   · ${p.name} 缺失: ${abs}`);
  }
}
if (ok === 0) {
  console.error("[collab] 未找到任何 ESIM 项目目录。请设置 ESIM_ROOT=/三项目父目录");
  process.exit(1);
}
EOF

echo
echo "[collab] ② 与 GitHub 双向同步（本地改动先 commit，再 pull 手机更新，再 push）…"
node "$ROOT/scripts/watch-and-commit.mjs" --once

if [[ "$NO_START" != "1" ]]; then
  echo
  echo "[collab] ③ 启动三项目联调…"
  bash "$ROOT/scripts/start-esim-projects.sh" --restart
fi

echo
if [[ "$ONCE" == "1" ]]; then
  echo "[collab] 完成（--once）。手机端可 Working Copy → Pull。"
  echo "  常驻监听请运行: make collab"
  exit 0
fi

echo "[collab] ④ 常驻监听：本地改动 → 各自 commit/push；定时 pull 手机更新"
echo "         Ctrl+C 结束监听（服务进程仍在时可用 make stop-esim 停止）"
echo
node "$ROOT/scripts/watch-and-commit.mjs"
