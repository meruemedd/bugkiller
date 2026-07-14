import http from "node:http";
import { readFileSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { URL } from "node:url";
import {
  API_DEFAULT_PORT,
  APP_NAME,
  formatError,
  healthPayload,
} from "@bugkiller/shared";

// 轻量加载仓库根目录 .env（不依赖 dotenv）
const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "../../..");
const envFile = join(repoRoot, ".env");
if (existsSync(envFile)) {
  for (const line of readFileSync(envFile, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    const val = trimmed.slice(eq + 1).trim();
    if (process.env[key] === undefined) process.env[key] = val;
  }
}

const port = Number(process.env.PORT || API_DEFAULT_PORT);
const allowDemoBoom = process.env.ALLOW_DEMO_BOOM !== "0";

const server = http.createServer((req, res) => {
  const url = new URL(req.url || "/", `http://127.0.0.1:${port}`);
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Content-Type", "application/json; charset=utf-8");

  try {
    if (url.pathname === "/health") {
      res.writeHead(200);
      res.end(JSON.stringify(healthPayload("api")));
      return;
    }

    if (url.pathname === "/api/ping") {
      res.writeHead(200);
      res.end(JSON.stringify({ pong: true, app: APP_NAME }));
      return;
    }

    // 故意保留可触发错误路径，便于演练日志 → 修复闭环
    // ALLOW_DEMO_BOOM=0 可关闭（auto-fix 命中后会自动写入）
    if (url.pathname === "/api/boom") {
      if (!allowDemoBoom) {
        res.writeHead(404);
        res.end(
          JSON.stringify({
            error: "demo_boom_disabled",
            hint: "Set ALLOW_DEMO_BOOM=1 to re-enable",
          }),
        );
        return;
      }
      throw new Error("Intentional demo error from /api/boom");
    }

    res.writeHead(404);
    res.end(JSON.stringify({ error: "not_found", path: url.pathname }));
  } catch (err) {
    const payload = formatError(err);
    console.error("[api:error]", JSON.stringify(payload));
    res.writeHead(500);
    res.end(JSON.stringify({ error: "internal", ...payload }));
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`[api] ${APP_NAME} listening on http://127.0.0.1:${port}`);
  console.log(`[api] ALLOW_DEMO_BOOM=${allowDemoBoom ? "1" : "0"}`);
});

process.on("uncaughtException", (err) => {
  console.error("[api:uncaught]", JSON.stringify(formatError(err)));
});

process.on("unhandledRejection", (reason) => {
  console.error(
    "[api:unhandledRejection]",
    JSON.stringify(formatError(reason instanceof Error ? reason : new Error(String(reason)))),
  );
});
