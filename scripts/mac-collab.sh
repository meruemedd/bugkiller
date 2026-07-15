#!/usr/bin/env bash
# 仅在 Mac 本机运行：检查路径 → 同步 GitHub → 启动 ESIM_B/A/I 联调 → 常驻监听
# 用法（在 Mac 终端）:
#   cd /path/to/bugkiller
#   bash scripts/mac-collab.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[mac-collab] 当前不是 macOS。"
  echo "  请在 Mac「终端.app」或本机 Cursor 终端执行本脚本。"
  echo "  云端 Agent 无法访问 /Users/air/Documents/code/ESIM/..."
  exit 2
fi

echo "[mac-collab] bugkiller 目录: $ROOT"
echo "[mac-collab] 拉取 bugkiller 工具更新…"
git pull --ff-only || git pull || true

if [[ -f projects.esim.json ]]; then
  cp projects.esim.json projects.json
fi

echo "[mac-collab] 检查三工程路径…"
bash scripts/check-esim-paths.sh

echo "[mac-collab] 开始协作联调（sync + start + watch）…"
exec bash scripts/esim-collab.sh --no-discover "$@"
