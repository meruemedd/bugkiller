#!/usr/bin/env bash
# 并行启动三个项目：Web / API / Shared，日志写入 logs/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p logs
STAMP="$(date +%Y%m%d-%H%M%S)"
API_LOG="logs/api-${STAMP}.log"
WEB_LOG="logs/web-${STAMP}.log"
SHARED_LOG="logs/shared-${STAMP}.log"
PID_FILE="logs/dev-all.pids"

if [[ ! -d node_modules ]]; then
  echo "[dev-all] npm install ..."
  npm install
fi

# 停掉可能残留的旧进程
if [[ -f "$PID_FILE" ]]; then
  echo "[dev-all] 发现旧 PID 文件，先执行 stop-all"
  bash "$ROOT/scripts/stop-all.sh" || true
fi

: > "$PID_FILE"

echo "[dev-all] 启动 Shared ..."
(
  npm run dev -w @bugkiller/shared
) >"$SHARED_LOG" 2>&1 &
echo $! >> "$PID_FILE"

echo "[dev-all] 启动 API → logs/$(basename "$API_LOG")"
(
  npm run dev -w @bugkiller/api
) >"$API_LOG" 2>&1 &
echo $! >> "$PID_FILE"

echo "[dev-all] 启动 Web → logs/$(basename "$WEB_LOG")"
(
  npm run dev -w @bugkiller/web
) >"$WEB_LOG" 2>&1 &
echo $! >> "$PID_FILE"

# 方便 collect-logs 找到「当前」日志
ln -sfn "$(basename "$API_LOG")" logs/api-latest.log
ln -sfn "$(basename "$WEB_LOG")" logs/web-latest.log
ln -sfn "$(basename "$SHARED_LOG")" logs/shared-latest.log

sleep 1
echo "[dev-all] 已启动。PID 写入 $PID_FILE"
echo "  Web    http://127.0.0.1:5173"
echo "  API    http://127.0.0.1:8787/health"
echo "  停止   make stop  或  ./scripts/stop-all.sh"
echo "  日志   make logs && make optimize"

# 前台轻量等待，方便用户 Ctrl+C 时顺带停服（若以 nohup/make 后台启动则不会卡住太久）
if [[ "${DEV_ALL_FOREGROUND:-0}" == "1" ]]; then
  trap 'bash "$ROOT/scripts/stop-all.sh"' INT TERM
  wait
fi
