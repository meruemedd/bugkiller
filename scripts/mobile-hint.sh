#!/usr/bin/env bash
# 打印 Android / iOS 本地构建与安装指引（骨架阶段不强依赖完整原生工程）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET="${1:-all}"

android_hint() {
  cat <<'EOF'
=== Android ===
1. 用 Android Studio 打开目录：android/
2. 若尚无完整 Gradle Wrapper，可在 Android Studio 中 Sync / 生成。
3. 构建 Debug：
     cd android && ./gradlew assembleDebug
4. 安装到设备/模拟器：
     adb install -r app/build/outputs/apk/debug/app-debug.apk
5. 抓日志：
     adb logcat -s BugKiller:* *:E
6. 联调 API：将客户端 Base URL 设为电脑局域网 IP，例如
     http://192.168.1.10:8787
EOF
}

ios_hint() {
  cat <<'EOF'
=== iOS ===
1. 用 Xcode 打开：ios/BugKiller.xcodeproj（若仅有源码骨架，可用 Xcode 新建 App 并把 ios/BugKiller 下源文件拖入）
2. 选择模拟器（如 iPhone 16）后 Run (⌘R)
3. 或命令行（工程就绪后）：
     xcodebuild -scheme BugKiller -destination 'platform=iOS Simulator,name=iPhone 16' build
4. 日志：
     xcrun simctl spawn booted log stream --level error
5. 联调 API：Info.plist 允许本地 HTTP，或使用 https 隧道；Base URL 指向 Mac 局域网 IP
EOF
}

case "$TARGET" in
  android) android_hint ;;
  ios) ios_hint ;;
  all|*)
    android_hint
    echo
    ios_hint
    ;;
esac

echo
echo "[mobile-hint] 原生工程为最小骨架；完整 Gradle/Xcode 工程可用 Android Studio / Xcode 补全后，再与 make dev 联调。"
