---
name: api-dev
description: BugKiller API（apps/api）接口开发、调试与改动审查。在修改 Node HTTP 服务、路由、或给 Web/Android/iOS 提供接口时使用。
paths:
  - apps/api/**
---

# API Dev Skill

适用于 `apps/api`：Node HTTP 接口（默认端口 `8787`）。

## 何时使用

- 改 `src/server.js` 或新增路由 / 处理器
- 为 Web / Android / iOS 提供或调整 API
- 排查联调失败、日志报错、优化提案中的服务端问题

## 工作约定

1. 优先改动局限在 `apps/api/`；共享常量与工具放 `packages/shared`。
2. 本地启动：`npm run dev -w @bugkiller/api`（或根目录一键脚本）。
3. 移动端联调注意主机差异：
   - Android 模拟器 → `10.0.2.2:8787`
   - iOS 模拟器 → `127.0.0.1:8787`
   - 真机 → 电脑局域网 IP
4. 开发期若用 HTTP，确认客户端已允许 cleartext / ATS 例外。

## 检查清单

- [ ] 路由、方法、状态码、响应体是否一致且有文档/注释
- [ ] 错误响应是否可被客户端与 `collect-logs` 流程捕获
- [ ] 是否误伤其他端（改字段需同步 Web / 移动端）
- [ ] `node --watch` 下热更新行为是否符合预期

## 可扩展资源（可选）

- `scripts/` — 本 skill 专用脚本（相对本目录引用）
- `references/` — OpenAPI 草稿、错误码表、联调说明
- `assets/` — 请求/响应示例 JSON

## 待你补充

<!-- 在此写下鉴权、错误码、日志格式、禁止破坏性变更等约定 -->
