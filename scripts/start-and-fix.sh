#!/usr/bin/env bash
# 电脑端闭环：确保服务在跑 → 收集日志 → 自动修复（+ 生成提案）
# 用法:
#   bash scripts/start-and-fix.sh
#   bash scripts/start-and-fix.sh --no-fix
#   bash scripts/start-and-fix.sh --restart
#   bash scripts/start-and-fix.sh --dry-run
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DO_FIX=1
FORCE_RESTART=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --no-fix) DO_FIX=0 ;;
    --restart) FORCE_RESTART=1 ;;
    --dry-run) DRY=1 ;;
  esac
done

mkdir -p logs
PID_FILE="logs/dev-all.pids"

need_start=0
if [[ "$FORCE_RESTART" == "1" ]]; then
  need_start=1
elif [[ ! -f "$PID_FILE" ]]; then
  need_start=1
else
  alive=0
  while read -r pid; do
    [[ -z "${pid:-}" ]] && continue
    if kill -0 "$pid" 2>/dev/null; then
      alive=1
      break
    fi
  done <"$PID_FILE"
  [[ "$alive" == "0" ]] && need_start=1
fi

# 简单健康检查：API 不通也重启/启动
if [[ "$need_start" == "0" ]]; then
  if command -v curl >/dev/null 2>&1; then
    if ! curl -fsS --max-time 2 "http://127.0.0.1:8787/health" >/dev/null 2>&1; then
      echo "[start-and-fix] API 健康检查失败，准备重启"
      need_start=1
    fi
  fi
fi

if [[ "$need_start" == "1" ]]; then
  if [[ "$DRY" == "1" ]]; then
    echo "[start-and-fix] dry-run: 将 stop + dev-all"
  else
    echo "[start-and-fix] 启动 / 重启 Web + API + Shared …"
    bash "$ROOT/scripts/stop-all.sh" || true
    bash "$ROOT/scripts/dev-all.sh"
    # 等监听起来
    for i in 1 2 3 4 5 6 7 8; do
      if curl -fsS --max-time 1 "http://127.0.0.1:8787/health" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
  fi
else
  echo "[start-and-fix] 开发服务已在运行（跳过启动）"
fi

if [[ "$DRY" == "1" ]]; then
  echo "[start-and-fix] dry-run: collect-logs + auto-fix"
  exit 0
fi

echo "[start-and-fix] 收集日志 …"
bash "$ROOT/scripts/collect-logs.sh"

if [[ "$DO_FIX" == "1" ]]; then
  echo "[start-and-fix] 自动修复 …"
  bash "$ROOT/scripts/auto-fix.sh"
else
  echo "[start-and-fix] 跳过自动修复，仅生成提案"
  bash "$ROOT/scripts/optimize-from-logs.sh"
fi

echo "[start-and-fix] 完成。Web http://127.0.0.1:5173  API http://127.0.0.1:8787/health"
echo "[start-and-fix] 提案 proposals/latest.md"
