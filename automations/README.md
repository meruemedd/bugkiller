# 日志驱动的 Cursor Automation 说明（本仓库侧草稿）

本文件是**可提交的说明**，不是已保存的 Cursor Automation。
完整创建请在 Cursor → Automations 中由你确认后落库。

## 建议自动化用途

当本地或 CI 产生错误日志后，自动让 Agent：

1. 读取 `logs/combined-latest.log`（或本轮附件）
2. 运行 / 参考 `scripts/optimize-from-logs.sh` 的提案结构
3. 输出修复提案到 `proposals/`，或在 PR 上评论摘要
4. **不**在未确认时直接推送业务代码修改

## 推荐触发器（任选）

| 触发 | 何时用 |
|------|--------|
| 定时（如每小时） | 本地常驻开发，定期扫 `logs/` |
| GitHub push / CI 失败 | 远程流水线挂了再分析 |
| 手动 / webhook | 电脑跑完 `make logs` 后主动踢一脚 |

## Agent 指令草案（粘贴到 Automations 编辑器）

```text
你是 BugKiller 仓库的日志优化助手。
1. 阅读 logs/combined-latest.log；若不存在，说明需要先运行 scripts/collect-logs.sh。
2. 归纳最高优先级的 1–3 个错误，指向具体文件路径。
3. 在 proposals/ 下新增一份 Markdown 提案（勿直接大面积改业务代码）。
4. 若仓库策略允许且用户已授权「可写补丁」，可提交最小修复到新分支并开 PR；否则只写提案。
5. 回复中明确区分：已自动完成的事项 vs 需人工确认的事项。
```

## 本地可运行入口（不依赖 Automation）

```bash
make logs
make optimize
# 然后在 Cursor 聊天里：@proposals/latest.md 按提案修复
```

这与 Automation 形成同一闭环：收集 → 提案 → 人工确认 → 改代码。
