#!/usr/bin/env bash
# 根据 logs/ 做「可安全自动应用」的修复，并始终生成优化提案。
# 用法: bash scripts/auto-fix.sh [--no-restart] [--dry-run]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs proposals

NO_RESTART=0
DRY=0
for arg in "$@"; do
  case "$arg" in
    --no-restart) NO_RESTART=1 ;;
    --dry-run) DRY=1 ;;
  esac
done

COMBINED="logs/combined-latest.log"
if [[ ! -f "$COMBINED" ]] || [[ ! -s "$COMBINED" ]]; then
  echo "[auto-fix] 无合并日志，先 collect ..."
  bash "$ROOT/scripts/collect-logs.sh"
fi

FIXED=0
ACTIONS=()

log_action() {
  local msg="$1"
  ACTIONS+=("$msg")
  echo "[auto-fix] $msg"
}

apply_or_echo() {
  if [[ "$DRY" == "1" ]]; then
    log_action "dry-run: $*"
    return 0
  fi
  "$@"
}

# 1) 缺依赖
if grep -Eiq 'Cannot find module|MODULE_NOT_FOUND|ERR_MODULE_NOT_FOUND' "$COMBINED" 2>/dev/null; then
  log_action "检测到缺依赖 → npm install"
  apply_or_echo npm install
  FIXED=1
fi

# 2) 端口占用
if grep -Eiq 'EADDRINUSE|address already in use' "$COMBINED" 2>/dev/null; then
  log_action "检测到端口占用 → stop-all"
  apply_or_echo bash "$ROOT/scripts/stop-all.sh"
  FIXED=1
fi

# 3) 演示 boom 错误：关闭 ALLOW_DEMO_BOOM
if grep -Eiq 'Intentional demo error|/api/boom' "$COMBINED" 2>/dev/null; then
  ENV_FILE="$ROOT/.env"
  if [[ -f "$ENV_FILE" ]] && grep -q '^ALLOW_DEMO_BOOM=' "$ENV_FILE"; then
    if grep -q '^ALLOW_DEMO_BOOM=0' "$ENV_FILE"; then
      log_action "演示 boom 已关闭（.env ALLOW_DEMO_BOOM=0）"
    else
      log_action "关闭演示 boom → .env ALLOW_DEMO_BOOM=0"
      if [[ "$DRY" == "1" ]]; then
        log_action "dry-run: 修改 .env ALLOW_DEMO_BOOM=0"
      else
        # portable sed
        tmp="$(mktemp)"
        sed 's/^ALLOW_DEMO_BOOM=.*/ALLOW_DEMO_BOOM=0/' "$ENV_FILE" >"$tmp"
        mv "$tmp" "$ENV_FILE"
      fi
      FIXED=1
    fi
  else
    log_action "关闭演示 boom → 写入 .env ALLOW_DEMO_BOOM=0"
    if [[ "$DRY" != "1" ]]; then
      {
        [[ -f "$ENV_FILE" ]] && cat "$ENV_FILE"
        echo "ALLOW_DEMO_BOOM=0"
      } | awk 'NF' | awk '!seen[$0]++' >"$ENV_FILE.tmp"
      mv "$ENV_FILE.tmp" "$ENV_FILE"
    fi
    FIXED=1
  fi
fi

# 4) uncaught / crash → 标记需要重启
if grep -Eiq 'uncaughtException|unhandledRejection|Fatal|crash' "$COMBINED" 2>/dev/null; then
  log_action "检测到进程异常信号 → 将重启开发服务"
  FIXED=1
fi

# 写一份自动修复记录
STAMP="$(date +%Y%m%d-%H%M%S)"
FIX_LOG="logs/auto-fix-${STAMP}.log"
{
  echo "auto-fix @ $(date -Iseconds) dry=$DRY fixed=$FIXED"
  for a in "${ACTIONS[@]:-}"; do
    echo "- $a"
  done
} >"$FIX_LOG"
ln -sfn "$(basename "$FIX_LOG")" logs/auto-fix-latest.log

# 始终生成人工可读提案（补充自动修复未覆盖的项）
bash "$ROOT/scripts/optimize-from-logs.sh"

# 若有修复且允许重启
if [[ "$FIXED" == "1" && "$NO_RESTART" != "1" && "$DRY" != "1" ]]; then
  log_action "应用修复后重启 → scripts/dev-all.sh"
  bash "$ROOT/scripts/stop-all.sh" || true
  bash "$ROOT/scripts/dev-all.sh"
  sleep 2
  bash "$ROOT/scripts/collect-logs.sh" || true
fi

if [[ "$FIXED" == "1" ]]; then
  echo "[auto-fix] 已应用可自动修复项；详见 $FIX_LOG 与 proposals/latest.md"
  exit 0
fi

echo "[auto-fix] 无可自动应用的规则修复；已更新 proposals/latest.md 供确认"
exit 0
