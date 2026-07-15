#!/usr/bin/env bash
# 电脑端协作闭环（与手机端 Working Copy / GitHub App 配合）:
#   必须在 Mac 本机终端运行（路径 /Users/air/...），云端 Agent 无法访问。
#
# 用法:
#   make collab
#   bash scripts/esim-collab.sh --once
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
echo "[collab] 系统=$(uname -s) 主机=$(hostname)"

# 已知本机路径时可直接用 projects.esim.json
if [[ ! -f "$ROOT/projects.json" && -f "$ROOT/projects.esim.json" ]]; then
  echo "[collab] 使用已配置路径 projects.esim.json → projects.json"
  cp "$ROOT/projects.esim.json" "$ROOT/projects.json"
fi

# 若配置了 Mac 绝对路径但当前不在 Mac，直接给出清晰错误
if [[ -f "$ROOT/projects.json" ]] || [[ -f "$ROOT/projects.esim.json" ]]; then
  if ! bash "$ROOT/scripts/check-esim-paths.sh"; then
    code=$?
    if [[ "$code" == "2" ]]; then
      exit 2
    fi
    # Darwin 上路径缺失：尝试用 ESIM_ROOT 再发现一次
    if [[ "$(uname -s)" == "Darwin" && "$NO_DISCOVER" != "1" ]]; then
      echo
      echo "[collab] ① 本机路径缺失，尝试 discover…"
      ESIM_ROOT="${ESIM_ROOT:-/Users/air/Documents/code/ESIM}" bash "$ROOT/scripts/discover-esim.sh" --write
      bash "$ROOT/scripts/check-esim-paths.sh" || exit 1
    else
      exit "$code"
    fi
  fi
else
  if [[ "$NO_DISCOVER" != "1" ]]; then
    echo
    echo "[collab] ① 发现 ESIM_B / ESIM_A / ESIM_I …"
    ESIM_ROOT="${ESIM_ROOT:-/Users/air/Documents/code/ESIM}" bash "$ROOT/scripts/discover-esim.sh" --write
  fi
  bash "$ROOT/scripts/check-esim-paths.sh" || exit 1
fi

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
