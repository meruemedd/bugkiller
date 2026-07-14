# Android 骨架

最小包名与联网权限已放在 `app/src/main/`。

推荐：

1. Android Studio → Open → 选择本 `android/` 目录，或「New Project」后把 `com.bugkiller.app` 代码拷入。
2. 确保 `minSdk` ≥ 24，允许 cleartext（开发期）或改用 HTTPS。
3. 模拟器访问电脑 API 使用 `10.0.2.2:8787`；真机使用电脑局域网 IP。

详见仓库根目录 `README.md` 与 `scripts/mobile-hint.sh`。
