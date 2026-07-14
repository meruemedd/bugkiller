import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WEB_DEFAULT_PORT, APP_NAME } from "@bugkiller/shared";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.join(__dirname, "..");
const port = Number(process.env.WEB_PORT || WEB_DEFAULT_PORT);
const apiBase = process.env.API_BASE || "http://127.0.0.1:8787";

const mime = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
};

function isInsideRoot(filePath) {
  const resolvedRoot = path.resolve(root);
  const resolved = path.resolve(filePath);
  return resolved === resolvedRoot || resolved.startsWith(resolvedRoot + path.sep);
}

const server = http.createServer((req, res) => {
  try {
    const reqPath = decodeURIComponent((req.url || "/").split("?")[0]);
    if (reqPath === "/config.js") {
      res.writeHead(200, { "Content-Type": "text/javascript; charset=utf-8" });
      res.end(`window.__BUGKILLER__ = ${JSON.stringify({ apiBase, app: APP_NAME })};`);
      return;
    }

    // 只映射站内相对路径；带扩展名的资源缺失时返回 404（避免把 JS/CSS 误成 HTML）
    const relative = reqPath === "/" ? "index.html" : reqPath.replace(/^\/+/, "");
    let filePath = path.resolve(root, relative);
    if (!isInsideRoot(filePath)) {
      res.writeHead(403);
      res.end("forbidden");
      return;
    }
    if (!fs.existsSync(filePath) || fs.statSync(filePath).isDirectory()) {
      const hasExt = path.extname(relative) !== "";
      if (hasExt) {
        res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("not found");
        return;
      }
      filePath = path.join(root, "index.html");
    }
    const ext = path.extname(filePath);
    res.writeHead(200, { "Content-Type": mime[ext] || "application/octet-stream" });
    fs.createReadStream(filePath).pipe(res);
  } catch (err) {
    console.error("[web:error]", err);
    res.writeHead(500);
    res.end("internal error");
  }
});

server.listen(port, "0.0.0.0", () => {
  console.log(`[web] ${APP_NAME} at http://127.0.0.1:${port}`);
});
