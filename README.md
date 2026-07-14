# BugKiller — 端到端研发工作流

手机端改代码 → 提交 GitHub → 电脑拉取 → 一键启动三个项目 + Android/iOS → 收集报错日志并自动给出优化提案。

## 仓库里的「三个项目」是什么？

| 项目 | 路径 | 端口 / 说明 |
|------|------|-------------|
| **1. Web** | `apps/web` | `5173` 前端静态页 + 简易开发服务器 |
| **2. API** | `apps/api` | `8787` Node HTTP 接口 |
| **3. Shared** | `packages/shared` | 三端共享常量与工具 |

另附：

- **Android** 骨架：`android/`
- **iOS** 骨架：`ios/`

> 原工作区 `未命名` 为空；正式脚手架落在本目录 `bugkiller/`。

---

## 总览流程

```text
[手机编辑] Working Copy / GitHub App / Cursor
        ↓ git push
    [GitHub]
        ↓ git pull（电脑）
[本机一键] make pull-dev  或  npm run pull:dev
        ↓
  Web + API + Shared 并行启动
  （可选）Android / iOS 构建安装提示
        ↓
  scripts/collect-logs.sh → logs/
        ↓
  scripts/optimize-from-logs.sh → proposals/（修复提案，人工确认后再改代码）

另：多本地独立仓库可用 make watch-dev
     → 监听各自改动 → 各自 commit / push
     → 定时从各自 remote 自动 pull（默认含本仓库 bugkiller）
     → 启动本仓库 Web/API/Shared，并根据日志自动修复
```

---

## 1. 手机端：发起编辑并提交到 GitHub

任选一种方式（推荐顺序）：

### 方式 A — Working Copy（iOS，最稳）

1. App Store 安装 [Working Copy](https://workingcopy.app/)。
2. Clone 本仓库（HTTPS + Personal Access Token，或 SSH）。
3. 在 App 内编辑文件，或「在其他 App 中打开」用文本编辑器改完回写。
4. Commit → Push 到 `main`（或你的功能分支）。

### 方式 B — GitHub 官方移动端

1. 安装 GitHub App（iOS/Android）。
2. 打开仓库 → 进入文件 → Edit → 提交 Commit。
3. 适合小改；大改建议 Working Copy / 电脑。

### 方式 C — Cursor（若手机可远程/云端）

1. 在 Cursor 打开本仓库，按需改代码。
2. 本地或云端 Commit / Push（需已登录 GitHub）。

**首次需要：** 在 GitHub 新建空仓库，再在本机绑定远程（见文末「下一步」）。

---

## 2. 电脑端：拉取 + 一键启动

前置：Node.js ≥ 18；可选 Android Studio / Xcode（跑原生工程时）。

**纯本地联调可完全跳过 GitHub**：不必配置 remote / push / pull，直接 `make setup && make dev`（或 `./scripts/dev-all.sh`）即可。

```bash
cd /path/to/bugkiller
npm install            # 或 make setup
make dev               # 推荐：本地启动，不碰远程
./scripts/dev-all.sh
# 若已绑定远程且需要先拉代码：
# git pull && make pull-dev
# 或 npm run pull:dev
```

启动后：

- Web：http://127.0.0.1:5173
- API：http://127.0.0.1:8787/health
- Shared：被前两者依赖，开发时一并 watch/打印就绪日志

进程 PID 与输出写在 `logs/`。停止：

```bash
make stop
# 或
./scripts/stop-all.sh
```

---

## 3. 三项目 + Android / iOS 一起调

```bash
# 三项目（Web/API/Shared）
make dev

# 附带打印 Android/iOS 本地构建指引（不强制失败）
make mobile

# 仅 Android / 仅 iOS 提示
./scripts/mobile-hint.sh android
./scripts/mobile-hint.sh ios
```

Android（需本机 SDK）：

```bash
cd android
./gradlew assembleDebug   # 骨架阶段可能需用 Android Studio 打开生成完整工程
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb logcat -s BugKiller:* *:E
```

iOS（需 macOS + Xcode）：

```bash
cd ios
# 用 Xcode 打开 BugKiller.xcodeproj（或按 mobile-hint 生成步骤）
xcodebuild -scheme BugKiller -destination 'platform=iOS Simulator,name=iPhone 16' build
```

联调建议：

1. 先起 API + Web。
2. 模拟器/真机客户端里把 API Base 指到电脑局域网 IP（如 `http://192.168.x.x:8787`）。
3. Web 页点「触发演示报错」可立刻产生可收集日志。

---

## 4. 日志收集与「自动优化」

### 收集

```bash
make logs
# 或
npm run logs:collect
./scripts/collect-logs.sh
```

会汇总到 `logs/`：

- `web-*.log` / `api-*.log`（本机一键启动产生）
- `combined-latest.log`（拼接近期错误相关行）
- 若有 `adb`：尝试抓取 logcat 片段
- 若在 macOS：提示如何导出 Xcode / Console 日志

### 优化（提案闭环，默认不直接改代码）

```bash
make optimize
# 或
npm run optimize
./scripts/optimize-from-logs.sh
```

行为：

1. 读取 `logs/combined-latest.log`（没有则先 collect）。
2. 生成 `proposals/YYYYMMDD-HHMMSS-proposal.md`：错误摘要 + 建议修改点 + 可执行检查清单。
3. **不会自动把补丁写进业务代码**；需要你在 Cursor 里打开提案 `@proposals/...`，确认后再让 Agent 改。

可选：用 Cursor Automations（见 `automations/README.md`）在 push / CI 失败时触发同样逻辑；草稿需你在 Automations 编辑器里确认保存。

**边界说明：**

| 能自动做的 | 需人工确认的 |
|------------|--------------|
| 启停服务、聚合日志、规则引擎自动修复（缺依赖/端口/演示 boom/崩溃重启） | 复杂业务逻辑改动 |
| 生成修复提案到 `proposals/` | 采用提案中非常规方案并合并发布 |
| `make watch-dev` 同步 + 启动 + 修复闭环 | 应用商店发布 |

---

## 5. 多本地项目双向同步 + 启动 + 自动修复

本机若有多个独立 Git 项目（**默认包含本仓库 `bugkiller`，`path: "."`**），可用本工具：

1. **自动拉取**：定时 `fetch` + `pull`（默认 `--ff-only`）
2. **自动提交**：本地有改动则 debounce 后 `add` / `commit`，并可选 `push`
3. **自动启动**：拉取/启动后确保本仓库 Web + API + Shared 在跑（`scripts/dev-all.sh`）
4. **自动修复**：收集日志后应用可安全的规则修复，并生成 `proposals/latest.md`

```bash
cp projects.example.json projects.json
# 默认 autoStart/autoFix 已开；确认 bugkiller path 为 "."
make watch-dev               # 推荐：常驻同步 + 启动 + 自动修复
make start-fix              # 只启动本仓库并修复一轮（不常驻）
make auto-fix                # 仅根据当前 logs/ 修复
make pull-projects           # 只拉一轮各项目
npm run sync:projects:dry    # git 同步预览
```

**自动修复合规范围（规则引擎，非任意改业务）：**

| 日志信号 | 自动动作 |
|----------|----------|
| 缺依赖 / MODULE_NOT_FOUND | `npm install` 后重启 |
| 端口占用 EADDRINUSE | `make stop` 后重启 |
| 演示 `/api/boom` 错误 | 写入 `.env` `ALLOW_DEMO_BOOM=0` 并重启 |
| 进程 uncaught / crash | 重启开发服务 |
| 其他错误 | 只写入 `proposals/latest.md`，不擅自大改代码 |

`projects.json` 要点：

| 字段 | 说明 |
|------|------|
| `projects[].path` | 本仓库用 `"."` |
| `autoPull` / `autoPush` | 全局或按项目控制 pull/push |
| `autoStart` / `autoFix` | 开启启动与自动修复（示例默认 true） |
| `pullIntervalMs` | 自动 pull 间隔，默认 60000 |
| `fixIntervalMs` | 启动检查/自动修复间隔，默认 120000 |
| `pullMode` | `ff-only`（默认）或 `rebase` |

同步顺序：有本地改动先 commit → pull → push；随后对启用了 `autoStart`/`autoFix` 的本仓库跑 `start-and-fix`。

日志：`logs/watch-commit.log`、`logs/auto-fix-latest.log`。`projects.json` 已 gitignore。

---

## 6. GitHub Actions（基础 CI）

`.github/workflows/ci.yml`：在 push / PR 时 `npm install` + 对三个工作区做 build 脚本。

---

## 常用命令（Makefile）

| 命令 | 作用 |
|------|------|
| `make setup` | `npm install` |
| `make pull` | `git pull` |
| `make dev` | 启动三项目 |
| `make pull-dev` | pull + 启动 |
| `make stop` | 停止后台进程 |
| `make mobile` | Android/iOS 指引 |
| `make watch-projects` | 常驻：多项目 commit/push + 定时 pull |
| `make watch-dev` | 常驻：git 同步 + 启动本仓库并自动修复 |
| `make sync-projects` | 扫描一轮：commit → pull → push |
| `make pull-projects` | 扫描一轮：只 pull（含本仓库） |
| `make start-fix` | 启动本仓库 + 日志收集 + 自动修复 |
| `make auto-fix` | 仅根据日志自动修复 |
| `make push-three` | 分别提交 Web/API/Shared 并推到 GitHub |
| `make logs` | 收集日志 |
| `make optimize` | 生成优化提案 |

---

## 下一步（最小动作）

1. 在 GitHub 新建空仓库（不要勾选自动加 README，避免冲突）。
2. 在本目录执行：

```bash
git remote add origin https://github.com/<你的用户名>/<仓库名>.git
git add .
git commit -m "chore: bootstrap BugKiller end-to-end workflow"
git push -u origin main
```

3. 手机端用 Working Copy / GitHub App Clone 该仓库，试改一处文案再 Push。
4. 电脑 `make pull-dev`，浏览器打开 Web，点「触发演示报错」，再 `make logs && make optimize`，查看 `proposals/`。
