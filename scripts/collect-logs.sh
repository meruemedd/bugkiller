#!/usr/bin/env bash
# 聚合 Web/API + ESIM 联调日志，可选 adb logcat；输出 logs/combined-latest.log
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p logs

OUT="logs/combined-latest.log"
STAMP="$(date +%Y%m%d-%H%M%S)"
SNAP="logs/combined-${STAMP}.log"
BK_LOG_DIR="${BUGKILLER_LOG_DIR:-/tmp/bugkiller_logs}"

{
  echo "=== BugKiller log collect @ $(date -Iseconds) ==="
  echo

  for name in api-latest web-latest shared-latest; do
    f="logs/${name}.log"
    if [[ -f "$f" ]]; then
      echo "----- $f -----"
      (grep -E -i 'error|exception|fail|uncaught|boom|WARN|E/|sign_verify' "$f" || true)
      echo "... (tail) ..."
      tail -n 40 "$f" || true
      echo
    else
      echo "----- $f (missing) -----"
      echo
    fi
  done

  # ESIM 三端由 start-esim-projects.sh 写入 logs/esim-*.log
  echo "----- ESIM project logs (logs/esim-*.log) -----"
  shopt -s nullglob
  esim_logs=(logs/esim-*.log)
  if ((${#esim_logs[@]})); then
    for f in "${esim_logs[@]}"; do
      echo "----- $f -----"
      (grep -E -i 'error|exception|fail|uncaught|traceback|sign_verify|Invalid request signature' "$f" || true)
      echo "... (tail) ..."
      tail -n 60 "$f" || true
      echo
    done
  else
    echo "(无 esim-*.log；先 make start-esim 或用 ESIM_B bugkiller 启动)"
    echo
  fi
  shopt -u nullglob

  # Python BugKiller 扫到的后端 / Flutter 进程日志
  echo "----- $BK_LOG_DIR -----"
  if [[ -d "$BK_LOG_DIR" ]]; then
    shopt -s nullglob
    bk_logs=("$BK_LOG_DIR"/*.log)
    if ((${#bk_logs[@]})); then
      for f in "${bk_logs[@]}"; do
        echo "----- $f -----"
        (grep -E -i 'error|exception|fail|traceback|sign_verify|Invalid request signature|ModuleNotFound' "$f" || true)
        echo "... (tail) ..."
        tail -n 60 "$f" || true
        echo
      done
    else
      echo "(目录存在但无 .log)"
      echo
    fi
    shopt -u nullglob
  else
    echo "(不存在；启动: cd ESIM_B && ./bugkiller/bin/bugkiller -c ./bugkiller.yaml start)"
    echo
  fi

  if command -v adb >/dev/null 2>&1; then
    echo "----- adb logcat (last 200 error-ish) -----"
    adb logcat -d -t 200 '*:E' 'flutter:*' 'BugKiller:*' 2>/dev/null || echo "(adb logcat 失败或无设备)"
    echo
  else
    echo "----- adb: 未安装，跳过 Android logcat -----"
    echo
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "----- iOS / Xcode 提示 -----"
    echo "Flutter iOS 日志见 logs/esim-ESIM_I.log 或 $BK_LOG_DIR/flutter_ios.log"
    echo "也可: xcrun simctl spawn booted log stream --level error"
    echo
  fi
} >"$OUT"

cp "$OUT" "$SNAP"
echo "[collect-logs] 已写入 $OUT"
echo "[collect-logs] 快照 $SNAP"
