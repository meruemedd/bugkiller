#!/usr/bin/env node
/**
 * 多本地 Git 项目双向同步：
 *   1) 工作区有改动 → 各自 commit（可选 push）
 *   2) 定期从各自 remote 自动 pull 更新（含本仓库）
 *   3) 可选：启动本仓库 Web/API/Shared，并根据日志自动修复
 *
 * 用法:
 *   node scripts/watch-and-commit.mjs                # 常驻：监听改动 + 定时 pull
 *   node scripts/watch-and-commit.mjs --once         # 扫一轮：commit → pull → push
 *   node scripts/watch-and-commit.mjs --pull-only    # 只拉取，不 commit/push 本地改动
 *   node scripts/watch-and-commit.mjs --dry-run      # 只打印
 *   node scripts/watch-and-commit.mjs --with-dev     # 同步后启动项目并自动修复
 *   node scripts/watch-and-commit.mjs --config path
 */
import { spawnSync } from "node:child_process";
import {
  existsSync,
  readFileSync,
  mkdirSync,
  appendFileSync,
  realpathSync,
} from "node:fs";
import { dirname, isAbsolute, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const LOG_DIR = join(ROOT, "logs");

const argv = process.argv.slice(2);
const args = new Set(argv);
const once = args.has("--once");
const dryRun = args.has("--dry-run");
const pullOnly = args.has("--pull-only");
const withDev = args.has("--with-dev");
const configArgIdx = argv.indexOf("--config");
function defaultConfigPath() {
  const primary = resolve(ROOT, "projects.json");
  const esim = resolve(ROOT, "projects.esim.json");
  if (existsSync(primary)) return primary;
  if (existsSync(esim)) return esim;
  return primary;
}

const configPath =
  configArgIdx >= 0 && argv[configArgIdx + 1]
    ? resolve(process.cwd(), argv[configArgIdx + 1])
    : defaultConfigPath();

function fail(msg, code = 1) {
  console.error(`[watch-and-commit] ${msg}`);
  process.exit(code);
}

function loadConfig() {
  if (!existsSync(configPath)) {
    fail(
      `找不到配置 ${configPath}\n` +
        `请使用已填好本机路径的配置，或复制示例:\n` +
        `  cp projects.esim.json projects.json\n` +
        `  # 或: cp projects.example.json projects.json`
    );
  }

  let raw;
  try {
    raw = JSON.parse(readFileSync(configPath, "utf8"));
  } catch (err) {
    fail(`配置解析失败: ${err.message}`);
  }

  const projects = Array.isArray(raw.projects) ? raw.projects : [];
  if (projects.length === 0) {
    fail("projects.json 中 projects 为空");
  }

  const pullMode =
    raw.pullMode === "rebase" || raw.pullMode === "ff-only"
      ? raw.pullMode
      : "ff-only";

  const envRoot = process.env.ESIM_ROOT || process.env.PROJECTS_ROOT || "";
  const projectsRootRaw =
    typeof raw.projectsRoot === "string" && raw.projectsRoot.trim()
      ? raw.projectsRoot.trim()
      : envRoot;

  return {
    projectsRoot: projectsRootRaw,
    debounceMs: Number(raw.debounceMs) > 0 ? Number(raw.debounceMs) : 8000,
    pollIntervalMs:
      Number(raw.pollIntervalMs) > 0 ? Number(raw.pollIntervalMs) : 3000,
    pullIntervalMs:
      Number(raw.pullIntervalMs) > 0 ? Number(raw.pullIntervalMs) : 60000,
    autoPush: raw.autoPush !== false,
    autoPull: raw.autoPull !== false,
    autoStart: raw.autoStart === true || withDev,
    autoFix: raw.autoFix === true || withDev,
    fixIntervalMs:
      Number(raw.fixIntervalMs) > 0 ? Number(raw.fixIntervalMs) : 120000,
    pullMode,
    commitMessage:
      typeof raw.commitMessage === "string" && raw.commitMessage.trim()
        ? raw.commitMessage.trim()
        : "chore(auto): sync {name} @ {time}",
    projects,
  };
}

function resolveBase(projectsRoot) {
  if (!projectsRoot) return ROOT;
  return isAbsolute(projectsRoot)
    ? projectsRoot
    : resolve(ROOT, projectsRoot);
}

function resolveProjectPath(p, projectsRoot = "") {
  const base = resolveBase(projectsRoot);
  const abs = isAbsolute(p) ? p : resolve(base, p);
  if (!existsSync(abs)) return { abs, error: `路径不存在: ${abs}` };
  try {
    return { abs: realpathSync(abs) };
  } catch {
    return { abs };
  }
}

function git(cwd, gitArgs, opts = {}) {
  const result = spawnSync("git", gitArgs, {
    cwd,
    encoding: "utf8",
    env: process.env,
    ...opts,
  });
  return {
    ok: result.status === 0,
    status: result.status ?? 1,
    stdout: (result.stdout || "").trim(),
    stderr: (result.stderr || "").trim(),
  };
}

function ensureGitRepo(absPath) {
  const r = git(absPath, ["rev-parse", "--is-inside-work-tree"]);
  return r.ok && r.stdout === "true";
}

function formatMessage(template, name) {
  const time = new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
  return template.replaceAll("{name}", name).replaceAll("{time}", time);
}

function appendLog(line) {
  try {
    mkdirSync(LOG_DIR, { recursive: true });
    appendFileSync(join(LOG_DIR, "watch-commit.log"), `${line}\n`);
  } catch {
    // ignore log write errors
  }
}

function statusPorcelain(absPath) {
  const r = git(absPath, ["status", "--porcelain", "--untracked-files=normal"]);
  if (!r.ok) {
    return { dirty: false, error: r.stderr || "git status 失败" };
  }
  const lines = r.stdout ? r.stdout.split("\n").filter(Boolean) : [];
  return { dirty: lines.length > 0, lines };
}

function currentBranch(absPath) {
  const r = git(absPath, ["rev-parse", "--abbrev-ref", "HEAD"]);
  return r.ok ? r.stdout : "";
}

function remoteRef(remote, branch) {
  return `${remote}/${branch}`;
}

function aheadBehind(absPath, remote, branch) {
  const ref = remoteRef(remote, branch);
  // ensure remote-tracking ref exists locally after fetch
  const count = git(absPath, [
    "rev-list",
    "--left-right",
    "--count",
    `HEAD...${ref}`,
  ]);
  if (!count.ok) {
    return { error: count.stderr || `无法比较 HEAD 与 ${ref}` };
  }
  const [left, right] = count.stdout.split(/\s+/).map((n) => Number(n));
  return {
    ahead: Number.isFinite(left) ? left : 0,
    behind: Number.isFinite(right) ? right : 0,
  };
}

function shouldBool(projectValue, defaultValue) {
  if (projectValue === undefined) return defaultValue;
  return projectValue !== false;
}

function commitLocalChanges(name, abs, project, defaults) {
  const st = statusPorcelain(abs);
  if (st.error) {
    console.warn(`[${name}] 跳过提交: ${st.error}`);
    return { committed: false, error: st.error, dirty: false };
  }
  if (!st.dirty) {
    return { committed: false, dirty: false };
  }

  const message = formatMessage(
    project.commitMessage || defaults.commitMessage,
    name
  );

  console.log(
    `[${name}] 检测到 ${st.lines.length} 处本地变更 → ${
      dryRun ? "dry-run commit" : "commit"
    }`
  );
  for (const line of st.lines.slice(0, 12)) {
    console.log(`  ${line}`);
  }
  if (st.lines.length > 12) {
    console.log(`  ... 另有 ${st.lines.length - 12} 行`);
  }

  if (dryRun) {
    appendLog(`${new Date().toISOString()} DRY_COMMIT ${name} ${st.lines.length} files`);
    return { committed: false, dirty: true, dryRun: true, files: st.lines.length };
  }

  const add = git(abs, ["add", "-A"]);
  if (!add.ok) {
    console.error(`[${name}] git add 失败: ${add.stderr}`);
    return { committed: false, dirty: true, error: add.stderr };
  }

  const afterAdd = statusPorcelain(abs);
  if (!afterAdd.dirty) {
    console.log(`[${name}] 暂存后工作区已干净，跳过提交`);
    return { committed: false, dirty: false };
  }

  const commit = git(abs, ["commit", "-m", message], {
    env: {
      ...process.env,
      GIT_AUTHOR_NAME: process.env.GIT_AUTHOR_NAME || "BugKiller AutoSync",
      GIT_AUTHOR_EMAIL:
        process.env.GIT_AUTHOR_EMAIL || "autosync@bugkiller.local",
      GIT_COMMITTER_NAME:
        process.env.GIT_COMMITTER_NAME ||
        process.env.GIT_AUTHOR_NAME ||
        "BugKiller AutoSync",
      GIT_COMMITTER_EMAIL:
        process.env.GIT_COMMITTER_EMAIL ||
        process.env.GIT_AUTHOR_EMAIL ||
        "autosync@bugkiller.local",
    },
  });
  if (!commit.ok) {
    console.error(`[${name}] git commit 失败: ${commit.stderr || commit.stdout}`);
    return { committed: false, dirty: true, error: commit.stderr || commit.stdout };
  }

  console.log(`[${name}] committed: ${message}`);
  appendLog(`${new Date().toISOString()} COMMIT ${name} ${message}`);
  return { committed: true, dirty: false };
}

function pullRemote(name, abs, remote, branch, pullMode) {
  const st = statusPorcelain(abs);
  if (st.error) {
    return { pulled: false, error: st.error };
  }
  if (st.dirty) {
    const reason = "工作区有未提交改动，跳过 pull（先自动 commit 或手动处理）";
    console.warn(`[${name}] ${reason}`);
    return { pulled: false, skipped: true, reason };
  }

  if (dryRun) {
    console.log(`[${name}] dry-run pull ${remote}/${branch} (${pullMode})`);
    appendLog(`${new Date().toISOString()} DRY_PULL ${name} ${remote}/${branch}`);
    return { pulled: false, dryRun: true };
  }

  const fetch = git(abs, ["fetch", remote, branch]);
  if (!fetch.ok) {
    // fallback: fetch remote (all)
    const fetchAll = git(abs, ["fetch", remote]);
    if (!fetchAll.ok) {
      console.error(`[${name}] git fetch 失败: ${fetch.stderr || fetchAll.stderr}`);
      appendLog(
        `${new Date().toISOString()} FETCH_FAIL ${name} ${
          fetch.stderr || fetchAll.stderr
        }`
      );
      return { pulled: false, error: fetch.stderr || fetchAll.stderr };
    }
  }

  const ab = aheadBehind(abs, remote, branch);
  if (ab.error) {
    // remote-tracking branch may not exist yet
    console.warn(`[${name}] 跳过 pull: ${ab.error}`);
    return { pulled: false, skipped: true, reason: ab.error };
  }

  if (ab.behind === 0) {
    return { pulled: false, skipped: true, reason: "up-to-date", ahead: ab.ahead };
  }

  console.log(
    `[${name}] 落后远程 ${ab.behind} 个提交，开始 pull (${pullMode})…`
  );

  const pullArgs =
    pullMode === "rebase"
      ? ["pull", "--rebase", remote, branch]
      : ["pull", "--ff-only", remote, branch];
  const pull = git(abs, pullArgs);
  if (!pull.ok) {
    console.error(`[${name}] git pull 失败: ${pull.stderr || pull.stdout}`);
    appendLog(
      `${new Date().toISOString()} PULL_FAIL ${name} ${pull.stderr || pull.stdout}`
    );
    return { pulled: false, error: pull.stderr || pull.stdout, behind: ab.behind };
  }

  console.log(`[${name}] pulled ← ${remote}/${branch} (+${ab.behind})`);
  appendLog(
    `${new Date().toISOString()} PULL_OK ${name} ${remote}/${branch} behind=${ab.behind}`
  );
  return { pulled: true, behind: ab.behind };
}

function pushRemote(name, abs, remote, branch) {
  if (dryRun) {
    console.log(`[${name}] dry-run push ${remote}/${branch}`);
    appendLog(`${new Date().toISOString()} DRY_PUSH ${name} ${remote}/${branch}`);
    return { pushed: false, dryRun: true };
  }

  const ab = aheadBehind(abs, remote, branch);
  if (!ab.error && ab.ahead === 0) {
    return { pushed: false, skipped: true, reason: "nothing-to-push" };
  }

  const push = git(abs, ["push", "-u", remote, branch]);
  if (!push.ok) {
    console.error(`[${name}] git push 失败: ${push.stderr || push.stdout}`);
    appendLog(
      `${new Date().toISOString()} PUSH_FAIL ${name} ${push.stderr || push.stdout}`
    );
    return { pushed: false, error: push.stderr || push.stdout };
  }

  console.log(`[${name}] pushed → ${remote}/${branch}`);
  appendLog(`${new Date().toISOString()} PUSH_OK ${name} ${remote}/${branch}`);
  return { pushed: true };
}

function syncProject(project, defaults, { commit = true, pull = true, push = true } = {}) {
  const name = project.name || project.path;
  const { abs, error: pathError } = resolveProjectPath(
    project.path,
    defaults.projectsRoot
  );
  if (pathError) {
    console.warn(`[${name}] 跳过: ${pathError}`);
    return { name, skipped: true, reason: pathError };
  }

  if (project.enabled === false) {
    return { name, skipped: true, reason: "disabled" };
  }

  if (!ensureGitRepo(abs)) {
    const reason = `不是 Git 仓库: ${abs}`;
    console.warn(`[${name}] 跳过: ${reason}`);
    return { name, skipped: true, reason };
  }

  const remote = project.remote || "origin";
  const headBranch = currentBranch(abs);
  const branch =
    headBranch && headBranch !== "HEAD"
      ? headBranch
      : project.branch || "main";
  if (
    project.branch &&
    headBranch &&
    headBranch !== "HEAD" &&
    project.branch !== headBranch
  ) {
    console.log(
      `[${name}] 当前分支 ${headBranch}（配置 branch=${project.branch}，按当前分支同步）`
    );
  }
  const doPull = pull && shouldBool(project.autoPull, defaults.autoPull);
  const doPush = push && shouldBool(project.autoPush, defaults.autoPush);
  const pullMode = project.pullMode || defaults.pullMode;

  const result = { name, abs, remote, branch };

  if (commit && !pullOnly) {
    result.commit = commitLocalChanges(name, abs, project, defaults);
  }

  if (doPull) {
    result.pull = pullRemote(name, abs, remote, branch, pullMode);
  }

  if (doPush && !pullOnly) {
    // push after pull so rebased/ff'd history is published when we were ahead
    const stillDirty = statusPorcelain(abs).dirty;
    if (stillDirty) {
      console.warn(`[${name}] 工作区仍不干净，跳过 push`);
      result.push = { pushed: false, skipped: true, reason: "dirty" };
    } else {
      result.push = pushRemote(name, abs, remote, branch);
    }
  }

  return result;
}

function runDevFix(reason) {
  if (dryRun) {
    console.log(`[watch-and-commit] dry-run skip start-and-fix (${reason})`);
    return;
  }
  console.log(`[watch-and-commit] 启动项目并自动修复 (${reason}) …`);
  const r = spawnSync("bash", [join(ROOT, "scripts/start-and-fix.sh")], {
    cwd: ROOT,
    encoding: "utf8",
    env: process.env,
    stdio: "inherit",
  });
  if (r.status !== 0) {
    console.error(`[watch-and-commit] start-and-fix 退出码 ${r.status}`);
    appendLog(
      `${new Date().toISOString()} DEVFIX_FAIL status=${r.status} ${reason}`
    );
  } else {
    appendLog(`${new Date().toISOString()} DEVFIX_OK ${reason}`);
  }
}

function normalizeProjects(config) {
  return config.projects.map((p, i) => {
    if (!p || typeof p !== "object" || !p.path) {
      fail(`projects[${i}] 需要 path 字段`);
    }
    return {
      name: p.name || `project-${i + 1}`,
      path: p.path,
      remote: p.remote || "origin",
      branch: p.branch,
      autoPush: p.autoPush,
      autoPull: p.autoPull,
      autoStart: p.autoStart,
      autoFix: p.autoFix,
      enabled: p.enabled,
      commitMessage: p.commitMessage,
      pullMode: p.pullMode,
    };
  });
}

async function main() {
  const config = loadConfig();
  const projects = normalizeProjects(config);

  const mode = pullOnly ? "pull-only" : once ? "once" : "watch";
  console.log(
    `[watch-and-commit] 配置=${configPath}` +
      ` 项目=${projects.length}` +
      (config.projectsRoot ? ` root=${resolveBase(config.projectsRoot)}` : "") +
      ` debounce=${config.debounceMs}ms` +
      ` poll=${config.pollIntervalMs}ms` +
      ` pullEvery=${config.pullIntervalMs}ms` +
      ` autoPull=${config.autoPull}` +
      ` autoPush=${config.autoPush}` +
      ` pullMode=${config.pullMode}` +
      ` mode=${mode}` +
      (dryRun ? " dry-run" : "")
  );

  const runOnce = () => {
    for (const p of projects) {
      syncProject(p, config, {
        commit: !pullOnly,
        pull: true,
        push: !pullOnly,
      });
    }
  };

  const wantDev =
    config.autoStart ||
    config.autoFix ||
    projects.some((p) => p.autoStart || p.autoFix);

  if (once || pullOnly) {
    runOnce();
    if (wantDev) {
      runDevFix(pullOnly ? "pull-only" : "once");
    }
    return;
  }

  /** @type {Map<string, NodeJS.Timeout>} */
  const timers = new Map();

  const scheduleCommit = (project) => {
    const key = project.name;
    const prev = timers.get(key);
    if (prev) clearTimeout(prev);
    timers.set(
      key,
      setTimeout(() => {
        timers.delete(key);
        try {
          syncProject(project, config);
        } catch (err) {
          console.error(`[${key}] 未捕获错误:`, err);
        }
      }, config.debounceMs)
    );
  };

  // 启动立刻同步一轮（含 pull）
  runOnce();
  if (wantDev) {
    runDevFix("startup");
  }

  console.log(
    `[watch-and-commit] 正在监听 ${projects.length} 个本地项目` +
      `（改动自动提交；每 ${config.pullIntervalMs}ms 自动拉取` +
      (wantDev ? `；每 ${config.fixIntervalMs}ms 启动检查/自动修复` : "") +
      `；Ctrl+C 退出）…`
  );

  setInterval(() => {
    for (const p of projects) {
      if (p.enabled === false) continue;
      const { abs, error } = resolveProjectPath(p.path, config.projectsRoot);
      if (error) continue;
      if (!ensureGitRepo(abs)) continue;
      const st = statusPorcelain(abs);
      if (st.dirty) scheduleCommit(p);
    }
  }, config.pollIntervalMs);

  setInterval(() => {
    for (const p of projects) {
      if (p.enabled === false) continue;
      try {
        const result = syncProject(p, config, {
          commit: false,
          pull: true,
          push: false,
        });
        if (
          wantDev &&
          result?.pull?.pulled &&
          (p.autoStart ||
            p.autoFix ||
            config.autoStart ||
            config.autoFix)
        ) {
          runDevFix(`after-pull:${p.name}`);
        }
      } catch (err) {
        console.error(`[${p.name}] pull 轮询错误:`, err);
      }
    }
  }, config.pullIntervalMs);

  if (wantDev) {
    setInterval(() => {
      try {
        runDevFix("interval");
      } catch (err) {
        console.error("[watch-and-commit] fix 轮询错误:", err);
      }
    }, config.fixIntervalMs);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
