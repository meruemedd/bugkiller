#!/usr/bin/env bash
# 发现本机 ESIM_B / ESIM_A / ESIM_I，并生成带 start 命令的 projects.json
# 用法:
#   bash scripts/discover-esim.sh
#   ESIM_ROOT=/path/to/parent bash scripts/discover-esim.sh --write
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WRITE=0
for arg in "$@"; do
  case "$arg" in
    --write) WRITE=1 ;;
  esac
done

export BK_ROOT="$ROOT"
export ESIM_ROOT="${ESIM_ROOT:-}"
export WRITE_FLAG="$WRITE"

python3 <<'PY'
import json, os, subprocess
from pathlib import Path

ROOT = Path(os.environ["BK_ROOT"]).resolve()
NAMES = ["ESIM_B", "ESIM_A", "ESIM_I"]
WRITE = os.environ.get("WRITE_FLAG") == "1"
esim_root = os.environ.get("ESIM_ROOT", "").strip()

search_roots = []
if esim_root:
    search_roots.append(Path(esim_root).expanduser().resolve())
search_roots += [
    ROOT.parent,
    Path.home(),
    Path.home() / "Desktop",
    Path.home() / "Documents",
    Path.home() / "Projects",
    Path.home() / "projects",
    Path.home() / "code",
    Path.home() / "dev",
    Path.home() / "src",
    Path.home() / "work",
]

def is_git(p: Path) -> bool:
    if (p / ".git").exists():
        return True
    try:
        r = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=p, capture_output=True, text=True,
        )
        return r.returncode == 0 and r.stdout.strip() == "true"
    except Exception:
        return False

def detect_start(abs_path: Path, name: str) -> str:
    pkg = abs_path / "package.json"
    if pkg.exists():
        try:
            scripts = json.loads(pkg.read_text()).get("scripts") or {}
            for key in ("dev", "start", "serve"):
                if key in scripts:
                    return f"npm run {key}" if key != "start" else "npm start"
        except Exception:
            pass
    if (abs_path / "docker-compose.yml").exists() or (abs_path / "compose.yaml").exists():
        return "docker compose up"
    if (abs_path / "gradlew").exists():
        return "bash ./gradlew installDebug"
    if (abs_path / "pom.xml").exists():
        return "mvn -q spring-boot:run"
    if name == "ESIM_B":
        return "echo '[ESIM_B] 请在 projects.json 配置 start（如 npm run dev）'"
    if name == "ESIM_A":
        return "echo '[ESIM_A] 请用 Android Studio 打开工程，或配置 start'"
    if name == "ESIM_I":
        return "echo '[ESIM_I] 请用 Xcode 打开工程并 Run'"
    return ""

def detect_health(abs_path: Path, name: str) -> str:
    # 留给用户在 projects.json 填写；不写死端口以免误报
    return ""

found = {}
print(f"[discover-esim] 正在查找 {' '.join(NAMES)} …")
for name in NAMES:
    for base in search_roots:
        if not base.exists():
            continue
        cand = base / name
        if not cand.is_dir():
            continue
        if is_git(cand):
            found[name] = cand.resolve()
            break
        found.setdefault(name, cand.resolve())

for name in NAMES:
    if name in found:
        print(f"[discover-esim] ✓ {name} → {found[name]}")
    else:
        print(f"[discover-esim] ✗ {name} 未找到")

if len(found) < 3:
    print()
    print("[discover-esim] 请把父目录设到 ESIM_ROOT 后再跑，例如:")
    print("  ESIM_ROOT=/你的/父目录 bash scripts/discover-esim.sh --write")

# common parent
projects_root = ""
parents = {p.parent for p in found.values()}
if len(parents) == 1:
    projects_root = str(next(iter(parents)))

projects = []
for name in NAMES:
    if name in found:
        abs_p = found[name]
        path = name if projects_root and abs_p.parent == Path(projects_root) else str(abs_p)
        enabled = True
        start = detect_start(abs_p, name)
        health = detect_health(abs_p, name)
    else:
        path = name if projects_root else f"../{name}"
        enabled = False
        start = detect_start(Path("/nonexistent"), name)
        health = detect_health(Path("/nonexistent"), name)
        abs_p = None

    item = {
        "name": name,
        "path": path,
        "remote": "origin",
        "branch": "main",
        "autoPull": True,
        "autoPush": True,
        "enabled": enabled,
        "start": start,
    }
    if health:
        item["healthUrl"] = health
    projects.append(item)

cfg = {
    "projectsRoot": projects_root,
    "debounceMs": 8000,
    "pollIntervalMs": 3000,
    "pullIntervalMs": 60000,
    "autoPull": True,
    "autoPush": True,
    "autoStart": False,
    "autoFix": False,
    "pullMode": "ff-only",
    "commitMessage": "chore(auto): sync {name} @ {time}",
    "projects": projects,
}

text = json.dumps(cfg, ensure_ascii=False, indent=2) + "\n"
out = ROOT / "projects.json"
if WRITE:
    out.write_text(text, encoding="utf-8")
    print(f"[discover-esim] 已写入 {out}")
else:
    print()
    print("[discover-esim] 预览配置（加 --write 写入 projects.json）：")
    print(text)
PY
