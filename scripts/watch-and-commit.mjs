#!/usr/bin/env node
/**
 * 监听多个本地 Git 项目：有改动时分别 add/commit，并推送到各自的远程仓库。
 *
 * 用法:
 *   node scripts/watch-and-commit.mjs              # 持续监听
 *   node scripts/watch-and-commit.mjs --once        # 只扫一轮并提交
 *   node scripts/watch-and-commit.mjs --dry-run     # 只打印，不写 Git
 *   node scripts/watch-and-commit.mjs --config path # 指定配置文件
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

const args = new Set(process.argv.slice(2));
const once = args.has("--once");
const dryRun = args.has("--dry-run");
const configArgIdx = process.argv.indexOf("--config");
const configPath =
  configArgIdx >= 0 && process.argv[configArgIdx + 1]
    ? resolve(process.cwd(), process.argv[configArgIdx + 1])
    : resolve(ROOT, "projects.json");

function fail(msg, code = 1) {
  console.error(`[watch-and-commit] ${msg}`);
  process.exit(code);
}

function loadConfig() {
  if (!existsSync(configPath)) {
    const example = join(ROOT, "projects.example.json");
    fail(
      `找不到配置 ${configPath}\n` +
        `请复制示例后按本机路径填写:\n` +
        `  cp projects.example.json projects.json`
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

  return {
    debounceMs: Number(raw.debounceMs) > 0 ? Number(raw.debounceMs) : 8000,
    pollIntervalMs:
      Number(raw.pollIntervalMs) > 0 ? Number(raw.pollIntervalMs) : 3000,
    autoPush: raw.autoPush !== false,
    commitMessage:
      typeof raw.commitMessage === "string" && raw.commitMessage.trim()
        ? raw.commitMessage.trim()
        : "chore(auto): sync {name} @ {time}",
    projects,
  };
}

function resolveProjectPath(p) {
  const abs = isAbsolute(p) ? p : resolve(ROOT, p);
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

function syncProject(project, defaults) {
  const name = project.name || project.path;
  const { abs, error: pathError } = resolveProjectPath(project.path);
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

  const st = statusPorcelain(abs);
  if (st.error) {
    console.warn(`[${name}] 跳过: ${st.error}`);
    return { name, skipped: true, reason: st.error };
  }
  if (!st.dirty) {
    return { name, skipped: true, reason: "clean" };
  }

  const remote = project.remote || "origin";
  const wantBranch = project.branch || currentBranch(abs) || "main";
  const doPush =
    project.autoPush !== undefined ? project.autoPush !== false : defaults.autoPush;
  const message = formatMessage(
    project.commitMessage || defaults.commitMessage,
    name
  );

  console.log(
    `[${name}] 检测到 ${st.lines.length} 处变更 → ${dryRun ? "dry-run" : "commit"}${
      doPush ? " + push" : ""
    }`
  );
  for (const line of st.lines.slice(0, 12)) {
    console.log(`  ${line}`);
  }
  if (st.lines.length > 12) {
    console.log(`  ... 另有 ${st.lines.length - 12} 行`);
  }

  if (dryRun) {
    appendLog(`${new Date().toISOString()} DRY ${name} ${st.lines.length} files`);
    return { name, dryRun: true, files: st.lines.length };
  }

  const add = git(abs, ["add", "-A"]);
  if (!add.ok) {
    console.error(`[${name}] git add 失败: ${add.stderr}`);
    return { name, error: add.stderr };
  }

  // 避免空提交（竞态清理后）
  const afterAdd = statusPorcelain(abs);
  if (!afterAdd.dirty) {
    console.log(`[${name}] 暂存后工作区已干净，跳过`);
    return { name, skipped: true, reason: "clean-after-add" };
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
    return { name, error: commit.stderr || commit.stdout };
  }
  console.log(`[${name}] committed: ${message}`);

  if (!doPush) {
    appendLog(`${new Date().toISOString()} COMMIT ${name} ${message}`);
    return { name, committed: true, pushed: false };
  }

  const branch = currentBranch(abs) || wantBranch;
  const push = git(abs, ["push", "-u", remote, branch]);
  if (!push.ok) {
    console.error(`[${name}] git push 失败: ${push.stderr || push.stdout}`);
    appendLog(
      `${new Date().toISOString()} PUSH_FAIL ${name} ${push.stderr || push.stdout}`
    );
    return { name, committed: true, pushed: false, error: push.stderr || push.stdout };
  }

  console.log(`[${name}] pushed → ${remote}/${branch}`);
  appendLog(`${new Date().toISOString()} PUSH_OK ${name} ${remote}/${branch}`);
  return { name, committed: true, pushed: true };
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
      enabled: p.enabled,
      commitMessage: p.commitMessage,
    };
  });
}

async function main() {
  const config = loadConfig();
  const projects = normalizeProjects(config);

  console.log(
    `[watch-and-commit] 配置=${configPath}` +
      ` 项目=${projects.length}` +
      ` debounce=${config.debounceMs}ms` +
      ` poll=${config.pollIntervalMs}ms` +
      (once ? " mode=once" : " mode=watch") +
      (dryRun ? " dry-run" : "")
  );

  if (once) {
    for (const p of projects) {
      syncProject(p, config);
    }
    return;
  }

  /** @type {Map<string, NodeJS.Timeout>} */
  const timers = new Map();

  const schedule = (project) => {
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

  // 启动时先扫一轮
  for (const p of projects) {
    const result = syncProject(p, config);
    if (result && !result.skipped && !result.error) {
      // already synced
    }
  }

  console.log(
    `[watch-and-commit] 正在监听 ${projects.length} 个本地项目（Ctrl+C 退出）…`
  );

  setInterval(() => {
    for (const p of projects) {
      if (p.enabled === false) continue;
      const { abs, error } = resolveProjectPath(p.path);
      if (error) continue;
      if (!ensureGitRepo(abs)) continue;
      const st = statusPorcelain(abs);
      if (st.dirty) schedule(p);
    }
  }, config.pollIntervalMs);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
