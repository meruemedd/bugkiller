#!/usr/bin/env bash
# 停止 scripts/start-esim-projects.sh 拉起的进程
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT/logs/esim-dev.pids"

if [[ ! -f "$PID_FILE" ]]; then
  echo "[stop-esim] 无 PID 文件 $PID_FILE"
  exit 0
fi

while read -r pid; do
  [[ -z "${pid:-}" ]] && continue
  if kill -0 "$pid" 2>/dev/null; then
    echo "[stop-esim] kill $pid (含子进程)"
    pkill -P "$pid" 2>/dev/null || true
    kill "$pid" 2>/dev/null || true
  fi
done <"$PID_FILE"
rm -f "$PID_FILE"
echo "[stop-esim] 完成"
