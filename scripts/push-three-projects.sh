#!/usr/bin/env bash
# 将电脑端三个工程（Web / API / Shared）分别打包提交并推到 GitHub。
#
# 默认推到本仓库独立分支（无需新建仓库）：
#   project/web
#   project/api
#   project/shared
#
# 若已各自建好独立仓库，可覆盖远程：
#   WEB_REMOTE=https://github.com/<you>/bugkiller-web.git \
#   API_REMOTE=https://github.com/<you>/bugkiller-api.git \
#   SHARED_REMOTE=https://github.com/<you>/bugkiller-shared.git \
#   bash scripts/push-three-projects.sh
#
# 选项:
#   --dry-run   只打印，不 push
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DRY=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
  esac
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[push-three] 当前目录不是 git 仓库" >&2
  exit 1
fi

ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
if [[ -z "${ORIGIN_URL}" ]]; then
  echo "[push-three] 缺少 origin remote" >&2
  exit 1
fi

WEB_REMOTE="${WEB_REMOTE:-$ORIGIN_URL}"
API_REMOTE="${API_REMOTE:-$ORIGIN_URL}"
SHARED_REMOTE="${SHARED_REMOTE:-$ORIGIN_URL}"

WEB_BRANCH="${WEB_BRANCH:-project/web}"
API_BRANCH="${API_BRANCH:-project/api}"
SHARED_BRANCH="${SHARED_BRANCH:-project/shared}"

STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
SOURCE_SHA="$(git rev-parse --short HEAD)"
SOURCE_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo detached)"

publish_one() {
  local name="$1"
  local src_rel="$2"
  local remote="$3"
  local branch="$4"
  local src="$ROOT/$src_rel"
  local tmp errfile

  if [[ ! -d "$src" ]]; then
    echo "[push-three] 缺少目录: $src" >&2
    return 1
  fi

  tmp="$(mktemp -d "${TMPDIR:-/tmp}/bugkiller-${name}.XXXXXX")"
  errfile="$(mktemp "${TMPDIR:-/tmp}/bugkiller-push-${name}.XXXXXX.err")"

  echo "[push-three] === $name ==="
  echo "[push-three] 源: $src_rel  →  $remote ($branch)"

  if command -v rsync >/dev/null 2>&1; then
    rsync -a \
      --exclude node_modules \
      --exclude dist \
      --exclude build \
      --exclude .git \
      --exclude '*.log' \
      "$src/" "$tmp/"
  else
    cp -a "$src/." "$tmp/"
    rm -rf "$tmp/node_modules" "$tmp/dist" "$tmp/build" "$tmp/.git" 2>/dev/null || true
  fi

  cat >"$tmp/PUBLISH.md" <<EOF
# ${name}

从 monorepo \`bugkiller\` 分别发布的工程快照。

- 源路径：\`${src_rel}\`
- 源分支：\`${SOURCE_BRANCH}\`
- 源提交：\`${SOURCE_SHA}\`
- 发布时间：\`${STAMP}\`

本分支 / 仓库仅包含该工程文件，便于手机或独立仓库单独拉取。
EOF

  (
    cd "$tmp"
    git init -b main >/dev/null
    git config user.email "${GIT_AUTHOR_EMAIL:-autosync@bugkiller.local}"
    git config user.name "${GIT_AUTHOR_NAME:-BugKiller AutoSync}"
    git add -A
    if git diff --cached --quiet; then
      echo "[push-three] $name 无文件可提交，跳过"
      exit 0
    fi
    git commit -m "chore(${name}): publish from bugkiller@${SOURCE_SHA} (${STAMP})" >/dev/null
    git remote add origin "$remote"

    if [[ "$DRY" == "1" ]]; then
      echo "[push-three] dry-run: 将 push main → ${branch}"
      git log -1 --oneline
      git ls-files | head -n 30
      exit 0
    fi

    if git push -u origin "HEAD:refs/heads/${branch}" --force-with-lease 2>"$errfile"; then
      echo "[push-three] 已推送 $name → ${remote}#${branch}"
    else
      echo "[push-three] force-with-lease 失败，尝试 --force（快照分支）…"
      cat "$errfile" >&2 || true
      git push -u origin "HEAD:refs/heads/${branch}" --force
      echo "[push-three] 已推送 $name → ${remote}#${branch}"
    fi
  )

  rm -rf "$tmp" "$errfile"
}

publish_one "web" "apps/web" "$WEB_REMOTE" "$WEB_BRANCH"
publish_one "api" "apps/api" "$API_REMOTE" "$API_BRANCH"
publish_one "shared" "packages/shared" "$SHARED_REMOTE" "$SHARED_BRANCH"

echo
echo "[push-three] 完成。"
if [[ "$WEB_REMOTE" == "$ORIGIN_URL" ]]; then
  echo "[push-three] GitHub 分支:"
  echo "  https://github.com/meruemedd/bugkiller/tree/${WEB_BRANCH}"
  echo "  https://github.com/meruemedd/bugkiller/tree/${API_BRANCH}"
  echo "  https://github.com/meruemedd/bugkiller/tree/${SHARED_BRANCH}"
  echo
  echo "[push-three] 若要推到三个独立仓库，先在 GitHub 建好空仓库后执行:"
  echo "  WEB_REMOTE=... API_REMOTE=... SHARED_REMOTE=... make push-three"
fi
