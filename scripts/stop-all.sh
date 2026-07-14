#!/usr/bin/env bash
# 停止 scripts/dev-all.sh 拉起的后台进程
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PID_FILE="$ROOT/logs/dev-all.pids"

if [[ ! -f "$PID_FILE" ]]; then
  echo "[stop-all] 无 PID 文件，尝试按端口清理"
else
  while read -r pid; do
    [[ -z "${pid:-}" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      echo "[stop-all] kill $pid (含子进程)"
      # npm run / node --watch 常把真正监听进程放在子树里
      pkill -P "$pid" 2>/dev/null || true
      kill "$pid" 2>/dev/null || true
    fi
  done < "$PID_FILE"
  rm -f "$PID_FILE"
fi

# 兜底：释放常用端口上的 node 监听（仅本机开发端口）
for port in 5173 8787; do
  if command -v lsof >/dev/null 2>&1; then
    pids="$(lsof -tiTCP:$port -sTCP:LISTEN 2>/dev/null || true)"
    if [[ -n "${pids:-}" ]]; then
      echo "[stop-all] 释放端口 $port → $pids"
      # shellcheck disable=SC2086
      kill $pids 2>/dev/null || true
    fi
  fi
done

echo "[stop-all] 完成"
