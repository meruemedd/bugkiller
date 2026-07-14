#!/usr/bin/env bash
# 聚合 Web/API 日志，可选 adb logcat；输出 logs/combined-latest.log
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

OUT="logs/combined-latest.log"
STAMP="$(date +%Y%m%d-%H%M%S)"
SNAP="logs/combined-${STAMP}.log"

{
  echo "=== BugKiller log collect @ $(date -Iseconds) ==="
  echo

  for name in api-latest web-latest shared-latest; do
    f="logs/${name}.log"
    if [[ -f "$f" ]]; then
      echo "----- $f -----"
      # 关注错误相关行，同时保留末尾上下文
      (grep -E -i 'error|exception|fail|uncaught|boom|WARN|E/' "$f" || true)
      echo "... (tail) ..."
      tail -n 40 "$f" || true
      echo
    else
      echo "----- $f (missing) -----"
      echo
    fi
  done

  if command -v adb >/dev/null 2>&1; then
    echo "----- adb logcat (last 200 error-ish) -----"
    adb logcat -d -t 200 '*:E' 'BugKiller:*' 2>/dev/null || echo "(adb logcat 失败或无设备)"
    echo
  else
    echo "----- adb: 未安装，跳过 Android logcat -----"
    echo
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "----- iOS / Xcode 提示 -----"
    echo "在 Xcode → Window → Devices and Simulators → Open Console，或："
    echo "  xcrun simctl spawn booted log stream --level error --predicate 'subsystem contains \"BugKiller\"'"
    echo "将导出内容保存为 logs/ios-manual-${STAMP}.log 后可再次运行本脚本。"
    echo
  fi
} >"$OUT"

cp "$OUT" "$SNAP"
echo "[collect-logs] 已写入 $OUT"
echo "[collect-logs] 快照 $SNAP"
