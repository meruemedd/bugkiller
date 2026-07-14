#!/usr/bin/env bash
# 发现本机 ESIM_B / ESIM_A / ESIM_I 目录，并生成 projects.json
# 用法:
#   bash scripts/discover-esim.sh
#   ESIM_ROOT=/path/to/parent bash scripts/discover-esim.sh
#   bash scripts/discover-esim.sh --write   # 写入 projects.json
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRITE=0
for arg in "$@"; do
  case "$arg" in
    --write) WRITE=1 ;;
  esac
done

NAMES=(ESIM_B ESIM_A ESIM_I)
declare -A FOUND=()

search_roots=()
if [[ -n "${ESIM_ROOT:-}" ]]; then
  search_roots+=("$ESIM_ROOT")
fi
search_roots+=(
  "$ROOT/.."
  "$HOME"
  "$HOME/Desktop"
  "$HOME/Documents"
  "$HOME/Projects"
  "$HOME/projects"
  "$HOME/code"
  "$HOME/dev"
  "$HOME/src"
  "$HOME/work"
)

echo "[discover-esim] 正在查找 ${NAMES[*]} …"

for name in "${NAMES[@]}"; do
  for base in "${search_roots[@]}"; do
    [[ -d "$base" ]] || continue
    cand="$base/$name"
    if [[ -d "$cand" ]]; then
      # prefer git repos
      if [[ -d "$cand/.git" ]] || git -C "$cand" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        FOUND["$name"]="$(cd "$cand" && pwd)"
        break
      fi
      # keep non-git as fallback if nothing else
      if [[ -z "${FOUND[$name]:-}" ]]; then
        FOUND["$name"]="$(cd "$cand" && pwd)"
      fi
    fi
  done
done

missing=()
for name in "${NAMES[@]}"; do
  if [[ -n "${FOUND[$name]:-}" ]]; then
    echo "[discover-esim] ✓ $name → ${FOUND[$name]}"
  else
    echo "[discover-esim] ✗ $name 未找到"
    missing+=("$name")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  echo
  echo "[discover-esim] 请把父目录设到 ESIM_ROOT 后再跑，例如:"
  echo "  ESIM_ROOT=/你的/父目录 bash scripts/discover-esim.sh --write"
  echo "或手动编辑 projects.json 里三个 path。"
fi

# 选择共同父目录（若找到的路径同父）
projects_root=""
if [[ ${#FOUND[@]} -gt 0 ]]; then
  first="${FOUND[ESIM_B]:-${FOUND[ESIM_A]:-${FOUND[ESIM_I]}}}"
  parent="$(dirname "$first")"
  same_parent=1
  for name in "${NAMES[@]}"; do
    [[ -n "${FOUND[$name]:-}" ]] || continue
    if [[ "$(dirname "${FOUND[$name]}")" != "$parent" ]]; then
      same_parent=0
      break
    fi
  done
  if [[ "$same_parent" == "1" ]]; then
    projects_root="$parent"
  fi
fi

OUT_JSON="$ROOT/projects.json"
tmp="$(mktemp)"
{
  echo '{'
  if [[ -n "$projects_root" ]]; then
    echo "  \"projectsRoot\": $(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$projects_root"),"
  else
    echo '  "projectsRoot": "",'
  fi
  cat <<'EOF'
  "debounceMs": 8000,
  "pollIntervalMs": 3000,
  "pullIntervalMs": 60000,
  "autoPull": true,
  "autoPush": true,
  "autoStart": false,
  "autoFix": false,
  "pullMode": "ff-only",
  "commitMessage": "chore(auto): sync {name} @ {time}",
  "projects": [
EOF
  first_item=1
  for name in "${NAMES[@]}"; do
    path_val="${FOUND[$name]:-}"
    if [[ -z "$path_val" ]]; then
      # placeholder relative name
      if [[ -n "$projects_root" ]]; then
        path_val="$name"
      else
        path_val="../$name"
      fi
      enabled=false
    else
      if [[ -n "$projects_root" && "$path_val" == "$projects_root"* ]]; then
        path_val="$name"
      fi
      enabled=true
    fi
    [[ "$first_item" == "1" ]] || echo ","
    first_item=0
    printf '    {\n      "name": "%s",\n      "path": %s,\n      "remote": "origin",\n      "branch": "main",\n      "autoPull": true,\n      "autoPush": true,\n      "enabled": %s\n    }' \
      "$name" "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$path_val")" "$enabled"
  done
  echo
  echo '  ]'
  echo '}'
} >"$tmp"

if [[ "$WRITE" == "1" ]]; then
  mv "$tmp" "$OUT_JSON"
  echo "[discover-esim] 已写入 $OUT_JSON"
else
  echo
  echo "[discover-esim] 预览配置（加 --write 写入 projects.json）："
  cat "$tmp"
  rm -f "$tmp"
fi
