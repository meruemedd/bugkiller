---
name: android-dev
description: BugKiller Android（android/）骨架开发、模拟器联调与构建提示。在修改 Android 包名、权限、联网配置或对接 API 时使用。
paths:
  - android/**
---

# Android Dev Skill

适用于 `android/`：最小 Android 骨架（包名与联网权限在 `app/src/main/`）。

## 何时使用

- 改 Manifest、权限、cleartext、网络基址
- 对接 `apps/api`（模拟器 / 真机）
- 按 `scripts/mobile-hint.sh` 做构建安装提示

## 工作约定

1. 用 Android Studio 打开本 `android/` 目录；`minSdk` ≥ 24。
2. 开发期可用 cleartext；正式环境改 HTTPS。
3. API 地址：
   - 模拟器：`10.0.2.2:8787`
   - 真机：电脑局域网 IP + `8787`
4. 大改动前先看根目录 `README.md` 与 `scripts/mobile-hint.sh`。

## 检查清单

- [ ] 包名 / 权限 / 网络配置是否与当前联调环境一致
- [ ] 模拟器或真机能否访问 API
- [ ] 是否需要同步改 `packages/shared` 或 API 契约
- [ ] 日志与失败信息是否便于电脑端 `collect-logs` / 提案流程

## 可扩展资源（可选）

- `scripts/` — 本 skill 专用脚本（相对本目录引用）
- `references/` — Gradle 约定、模块结构、发布清单
- `assets/` — 示例配置、截图

## 待你补充

<!-- 在此写下模块划分、Kotlin/Java 约定、UI 库、CI 构建命令等 -->
