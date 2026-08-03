---
name: web-dev
description: BugKiller Web（apps/web）前端开发、联调与改动审查。在修改 Web 静态页、样式、dev-server 或与 API 联调时使用。
paths:
  - apps/web/**
---

# Web Dev Skill

适用于 `apps/web`：静态前端 + 简易开发服务器（默认端口 `5173`）。

## 何时使用

- 改 `index.html` / `styles.css` / `app.js` / `src/dev-server.js`
- Web ↔ API 联调（API 默认 `8787`）
- 审查 Web 相关 PR / 日志修复提案

## 工作约定

1. 优先改动局限在 `apps/web/`；共享逻辑放 `packages/shared`。
2. 本地启动：`npm run dev -w @bugkiller/web`（或仓库根目录的 `make` / `npm` 一键脚本）。
3. 联调 API 时确认 base URL / 端口，避免写死错误主机。
4. 保持页面轻量：先满足联调与日志闭环，再加复杂度。

## 检查清单

- [ ] 改动是否只影响 Web（或已同步 shared）
- [ ] 开发服务器能否正常起在 `5173`
- [ ] 与 `apps/api` 的请求路径、CORS/跨域是否可用
- [ ] 相关日志是否写入 `logs/`，提案是否落到 `proposals/`

## 可扩展资源（可选）

- `scripts/` — 本 skill 专用脚本（相对本目录引用）
- `references/` — 接口约定、页面结构说明等长文
- `assets/` — 模板、截图、示例 HTML

## 待你补充

<!-- 在此写下团队专属约定：目录结构、命名、UI 规范、禁止事项等 -->
