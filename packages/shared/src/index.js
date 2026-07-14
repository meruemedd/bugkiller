/** @bugkiller/shared — 三项目共享常量与工具（项目 3） */

export const APP_NAME = "BugKiller";
export const API_DEFAULT_PORT = 8787;
export const WEB_DEFAULT_PORT = 5173;

export function healthPayload(service) {
  return {
    ok: true,
    service,
    app: APP_NAME,
    ts: new Date().toISOString(),
  };
}

export function formatError(err) {
  return {
    message: err?.message || String(err),
    stack: err?.stack || null,
    ts: new Date().toISOString(),
  };
}
