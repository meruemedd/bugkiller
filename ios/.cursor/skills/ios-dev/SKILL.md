---
name: ios-dev
description: BugKiller iOS（ios/）骨架开发、模拟器联调与 Xcode 工程约定。在修改 BugKillerConfig、ATS、或对接本地 API 时使用。
paths:
  - ios/**
---

# iOS Dev Skill

适用于 `ios/`：源码入口 `BugKiller/BugKillerConfig.swift`。

## 何时使用

- 改配置、ATS / 本地 HTTP 例外、联调基址
- 对接 `apps/api`（模拟器默认 `http://127.0.0.1:8787`）
- 按 `scripts/mobile-hint.sh` 做 Xcode 运行提示

## 工作约定

1. Xcode 新建 App 工程（Product Name `BugKiller`），再纳入 `BugKillerConfig.swift`。
2. 开发期在 Info 中允许本地 HTTP（App Transport Security 例外）。
3. 模拟器联调：`http://127.0.0.1:8787`；真机用电脑局域网 IP。
4. 与仓库端到端流程配合：改代码 → push → 电脑 pull → 一键启动 → 收日志 → 提案。

## 检查清单

- [ ] ATS / 网络配置是否允许当前开发环境
- [ ] API base URL 是否指向正确主机与端口
- [ ] 是否需要同步 API 或 `packages/shared`
- [ ] 失败信息是否便于电脑端收集与优化提案

## 可扩展资源（可选）

- `scripts/` — 本 skill 专用脚本（相对本目录引用）
- `references/` — 工程结构、签名/证书、发布清单
- `assets/` — 示例 plist、截图

## 待你补充

<!-- 在此写下 Swift 风格、架构（MVC/MVVM）、依赖管理、TestFlight 流程等 -->
