#!/usr/bin/env bash
# git pull 后一键安装依赖并启动三项目
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[pull-and-dev] git pull ..."
  git pull --ff-only || git pull
else
  echo "[pull-and-dev] 非 git 仓库，跳过 pull"
fi

npm install
bash "$ROOT/scripts/dev-all.sh"

if [[ "${WITH_MOBILE_HINT:-1}" == "1" ]]; then
  bash "$ROOT/scripts/mobile-hint.sh" all || true
fi
