import http from "node:http";
import { URL } from "node:url";
import {
  API_DEFAULT_PORT,
  APP_NAME,
  formatError,
  healthPayload,
} from "@bugkiller/shared";

const port = Number(process.env.PORT || API_DEFAULT_PORT);

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

    // 故意保留一个可触发的错误路径，便于演练日志收集 → 优化闭环
    if (url.pathname === "/api/boom") {
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
