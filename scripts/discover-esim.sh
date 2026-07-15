#!/usr/bin/env bash
# 发现本机 ESIM_B / ESIM_A / ESIM_I 的绝对路径，并拼接到 projects.json
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

exec python3 - "$WRITE" <<'PY'
import json, os, subprocess, sys
from pathlib import Path

ROOT = Path(os.environ["BK_ROOT"]).resolve()
NAMES = ["ESIM_B", "ESIM_A", "ESIM_I"]
WRITE = os.environ.get("WRITE_FLAG") == "1" or (len(sys.argv) > 1 and sys.argv[1] == "1")
esim_root = os.environ.get("ESIM_ROOT", "").strip()

def is_git(p):
    if (p / ".git").exists():
        return True
    try:
        r = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=str(p), capture_output=True, text=True,
        )
        return r.returncode == 0 and r.stdout.strip() == "true"
    except Exception:
        return False

def detect_start(abs_path, name):
    pkg = abs_path / "package.json"
    if pkg.exists():
        try:
            scripts = json.loads(pkg.read_text(encoding="utf-8")).get("scripts") or {}
            if "dev" in scripts:
                return "npm run dev"
            if "start" in scripts:
                return "npm start"
            if "serve" in scripts:
                return "npm run serve"
        except Exception:
            pass
    if (abs_path / "docker-compose.yml").exists() or (abs_path / "compose.yaml").exists():
        return "docker compose up"
    if (abs_path / "gradlew").exists():
        return "bash ./gradlew installDebug"
    if (abs_path / "pom.xml").exists():
        return "mvn -q spring-boot:run"
    tips = {
        "ESIM_B": "echo '[ESIM_B] 请在 projects.json 配置 start（如 npm run dev）'",
        "ESIM_A": "echo '[ESIM_A] 请用 Android Studio 打开工程，或配置 start'",
        "ESIM_I": "echo '[ESIM_I] 请用 Xcode 打开工程并 Run'",
    }
    return tips.get(name, "")

def find_named_dirs():
    found = {}
    print("[discover-esim] 正在查找 %s …" % " / ".join(NAMES))

    # 1) 直接命中：候选父目录下的同名子目录
    parents = []
    if esim_root:
        parents.append(Path(esim_root).expanduser().resolve())
    parents.extend([
        ROOT.parent,
        ROOT,
        Path.home(),
        Path.home() / "Desktop",
        Path.home() / "Documents",
        Path.home() / "Downloads",
        Path.home() / "Projects",
        Path.home() / "projects",
        Path.home() / "code",
        Path.home() / "dev",
        Path.home() / "src",
        Path.home() / "work",
        Path.home() / "workspace",
        Path("/tmp/esim-parent"),
        Path("/tmp"),
        Path("/opt"),
        Path("/var/www"),
    ])
    for base in parents:
        try:
            if not base.is_dir():
                continue
        except Exception:
            continue
        for name in NAMES:
            cand = base / name
            try:
                if cand.is_dir():
                    # 优先保留 git 结果
                    if name in found and is_git(found[name]) and not is_git(cand):
                        continue
                    found[name] = cand.resolve()
            except Exception:
                continue

    # 2) find 深搜
    deep_bases = []
    if esim_root:
        deep_bases.append(str(Path(esim_root).expanduser().resolve()))
    deep_bases.extend([str(Path.home()), "/tmp", str(ROOT.parent), "/opt", "/home", "/Users"])
    seen = set()
    for base in deep_bases:
        if base in seen or not Path(base).is_dir():
            continue
        seen.add(base)
        try:
            r = subprocess.run(
                [
                    "find", base, "-maxdepth", "6", "-type", "d",
                    "(", "-name", "ESIM_B", "-o", "-name", "ESIM_A", "-o", "-name", "ESIM_I", ")",
                ],
                capture_output=True, text=True, timeout=45,
            )
        except Exception:
            continue
        for line in r.stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            p = Path(line)
            name = p.name
            if name not in NAMES or not p.is_dir():
                continue
            if name in found and is_git(found[name]) and not is_git(p):
                continue
            found[name] = p.resolve()

    return found

found = find_named_dirs()

for name in NAMES:
    if name in found:
        flag = "git" if is_git(found[name]) else "no-git"
        print("[discover-esim] OK %s -> %s (%s)" % (name, found[name], flag))
    else:
        print("[discover-esim] MISS %s" % name)

if len(found) < 3:
    print("")
    print("[discover-esim] 未找全。请指定父目录：")
    print("  ESIM_ROOT=/三个项目所在父目录 make discover-esim")

projects_root = ""
parents = set(p.parent for p in found.values())
if len(parents) == 1:
    projects_root = str(next(iter(parents)))

projects = []
for name in NAMES:
    if name in found:
        abs_p = found[name]
        path = str(abs_p)  # 绝对路径拼接
        enabled = True
        start = detect_start(abs_p, name)
    else:
        if projects_root:
            path = str(Path(projects_root) / name)
        elif esim_root:
            path = str((Path(esim_root).expanduser().resolve() / name))
        else:
            path = str((ROOT.parent / name).resolve())
        enabled = False
        start = detect_start(Path(path), name)

    projects.append({
        "name": name,
        "path": path,
        "remote": "origin",
        "branch": "main",
        "autoPull": True,
        "autoPush": True,
        "enabled": enabled,
        "start": start,
    })

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
    print("[discover-esim] 已拼接绝对路径并写入 %s" % out)
    print("")
    for p in projects:
        mark = "OK" if p["enabled"] else "MISS"
        print("  [%s] %s = %s" % (mark, p["name"], p["path"]))
else:
    print("")
    print("[discover-esim] 预览（加 --write 写入）：")
    print(text)
PY
