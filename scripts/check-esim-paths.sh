#!/usr/bin/env bash
# 校验 ESIM_A/B/I 本机路径是否存在，并提示应在哪台机器上运行
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f "$ROOT/projects.json" ]]; then
  export CFG="$ROOT/projects.json"
elif [[ -f "$ROOT/projects.esim.json" ]]; then
  export CFG="$ROOT/projects.esim.json"
else
  echo "[check-esim] 缺少 projects.json / projects.esim.json"
  exit 1
fi

echo "[check-esim] 配置文件: $CFG"
echo "[check-esim] 当前系统: $(uname -s) 主机: $(hostname)"
echo

node --input-type=module <<'EOF'
import { readFileSync, existsSync } from "node:fs";
import { isAbsolute, resolve } from "node:path";
import os from "node:os";

const cfgPath = process.env.CFG;
const raw = JSON.parse(readFileSync(cfgPath, "utf8"));
const projectsRoot = (process.env.ESIM_ROOT || raw.projectsRoot || "").trim();
const base = projectsRoot
  ? isAbsolute(projectsRoot)
    ? projectsRoot
    : resolve(process.cwd(), projectsRoot)
  : process.cwd();

let ok = 0;
let miss = 0;
const missing = [];
for (const p of raw.projects || []) {
  if (p.enabled === false) continue;
  const abs = isAbsolute(p.path) ? p.path : resolve(base, p.path);
  if (existsSync(abs)) {
    ok++;
    console.log(`  OK   ${p.name} → ${abs}`);
  } else {
    miss++;
    missing.push({ name: p.name, abs });
    console.log(`  MISS ${p.name} → ${abs}`);
  }
}

const looksMac = missing.some((m) => m.abs.startsWith("/Users/"));
const isDarwin = os.platform() === "darwin";

console.log("");
if (ok > 0 && miss === 0) {
  console.log("[check-esim] 三个路径均可用，可以执行: make collab");
  process.exit(0);
}

if (looksMac && !isDarwin) {
  console.error("[check-esim] 当前不在 Mac 本机（检测到 Linux/云端）。");
  console.error("  /Users/air/... 只存在于你的 Mac，云端 Agent 访问不到。");
  console.error("");
  console.error("请打开 Mac「终端.app」或本机 Cursor 底部终端（不要用云端 Agent），执行：");
  console.error("  cd <bugkiller仓库目录>");
  console.error("  git pull");
  console.error("  ls /Users/air/Documents/code/ESIM");
  console.error("  make check-esim");
  console.error("  make collab");
  process.exit(2);
}

if (isDarwin && miss > 0) {
  console.error("[check-esim] 本机是 Mac，但目录不存在。请执行：");
  console.error("  ls -la /Users/air/Documents/code/ESIM");
  console.error("若三个文件夹不在，请先 clone 到该路径后再 make collab。");
  process.exit(1);
}

console.error("[check-esim] 路径不可用。请设置 ESIM_ROOT 后: make discover-esim");
process.exit(1);
EOF
