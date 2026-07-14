#!/usr/bin/env bash
# 从 logs/ 生成修复提案（不直接改业务代码）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p proposals logs

COMBINED="logs/combined-latest.log"
if [[ ! -f "$COMBINED" ]] || [[ ! -s "$COMBINED" ]]; then
  echo "[optimize] 无合并日志，先 collect ..."
  bash "$ROOT/scripts/collect-logs.sh"
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="proposals/${STAMP}-proposal.md"

# 抽取关键行
ERRORS="$(grep -E -i 'error|exception|fail|uncaught|boom' "$COMBINED" 2>/dev/null | head -n 80 || true)"
if [[ -z "${ERRORS}" ]]; then
  ERRORS="（未在合并日志中匹配到明显 error 行。可先打开 Web 点击「触发演示报错」，再 make logs。）"
fi

# 粗粒度定位可疑路径
SUSPECTS=""
if echo "$ERRORS" | grep -q 'api'; then
  SUSPECTS+="- \`apps/api/src/server.js\`"$'\n'
fi
if echo "$ERRORS" | grep -q 'web'; then
  SUSPECTS+="- \`apps/web/app.js\` / \`apps/web/src/dev-server.js\`"$'\n'
fi
if echo "$ERRORS" | grep -qi 'shared'; then
  SUSPECTS+="- \`packages/shared/src/index.js\`"$'\n'
fi
if [[ -z "$SUSPECTS" ]]; then
  SUSPECTS="- （未能自动锁定文件，请结合完整日志人工判断）"$'\n'
fi

cat >"$OUT" <<EOF
# BugKiller 自动优化提案

- 生成时间：$(date -Iseconds)
- 源日志：\`${COMBINED}\`
- **模式：仅提案，不会自动改代码 / 不会自动 commit**

## 摘要

根据近期启动与运行日志中的错误信号，建议优先排查下列文件，并在 Cursor 中人工确认后再应用修复。

## 匹配到的错误相关行

\`\`\`
${ERRORS}
\`\`\`

## 可疑文件

${SUSPECTS}

## 建议动作（检查清单）

1. [ ] 复现：Web 打开 http://127.0.0.1:5173 ，或请求 \`/api/boom\` / \`/api/ping\`
2. [ ] 确认 API 是否在 8787 监听、CORS/网络是否可达
3. [ ] 若为演示错误 \`Intentional demo error\`：这是骨架自带路径，确认优化流程即可；真实环境下应删除或加开关
4. [ ] 在 Cursor 对话中附上本文件：\`@${OUT}\`，要求「按提案修复，先给出 diff 再写入」
5. [ ] 修复后重新 \`make stop && make dev\`，再 \`make logs\` 确认错误消失
6. [ ] 确认无误后自行 \`git commit\`（本脚手架默认不自动提交）

## 对接 Cursor Automation（可选）

参见 \`automations/README.md\`：可在 push / CI 失败时让 Agent 读取 \`logs/\` 与本提案目录，输出 PR 评论或新的提案文件。  
**真正改代码仍建议保留人工确认。**

---
_由 \`scripts/optimize-from-logs.sh\` 生成_
EOF

# 供人工/agent 快速打开的指针
ln -sfn "$(basename "$OUT")" proposals/latest.md

echo "[optimize] 已生成 $OUT"
echo "[optimize] 快捷链接 proposals/latest.md"
echo "[optimize] 下一步：在 Cursor 中打开该提案并确认后再改代码"
