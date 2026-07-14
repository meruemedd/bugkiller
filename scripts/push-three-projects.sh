#!/usr/bin/env bash
# 将配置中的 ESIM_B / ESIM_A / ESIM_I（或 projects.json 全部启用项）
# 分别 commit 并 push 到各自 GitHub remote。
#
# 用法:
#   bash scripts/push-three-projects.sh           # 读 projects.json
#   bash scripts/push-three-projects.sh --dry-run
#   bash scripts/push-three-projects.sh --discover # 先自动发现本机目录再推
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY=0
DO_DISCOVER=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --discover) DO_DISCOVER=1 ;;
  esac
done

if [[ "$DO_DISCOVER" == "1" ]] || [[ ! -f "$ROOT/projects.json" ]]; then
  echo "[push-three] 先发现 ESIM_B / ESIM_A / ESIM_I …"
  bash "$ROOT/scripts/discover-esim.sh" --write
fi

if [[ ! -f "$ROOT/projects.json" ]]; then
  echo "[push-three] 缺少 projects.json。请先:" >&2
  echo "  cp projects.example.json projects.json" >&2
  echo "  # 或: make discover-esim" >&2
  exit 1
fi

ARGS=(--once)
if [[ "$DRY" == "1" ]]; then
  ARGS+=(--dry-run)
fi

echo "[push-three] 分别提交并推送 projects.json 中的工程（ESIM_B / ESIM_A / ESIM_I）…"
node "$ROOT/scripts/watch-and-commit.mjs" "${ARGS[@]}"
