const out = document.getElementById("out");
const cfg = window.__BUGKILLER__ || { apiBase: "http://127.0.0.1:8787" };

function show(data) {
  out.textContent = typeof data === "string" ? data : JSON.stringify(data, null, 2);
}

async function call(path) {
  show(`GET ${cfg.apiBase}${path} …`);
  try {
    const res = await fetch(`${cfg.apiBase}${path}`);
    const text = await res.text();
    let body;
    try {
      body = JSON.parse(text);
    } catch {
      body = text;
    }
    show({ status: res.status, body });
    if (!res.ok) {
      console.error("[web] API error", res.status, body);
    }
  } catch (err) {
    console.error("[web] fetch failed", err);
    show({ error: String(err) });
  }
}

document.getElementById("btn-ping").addEventListener("click", () => call("/api/ping"));
document.getElementById("btn-boom").addEventListener("click", () => call("/api/boom"));

show({ ready: true, apiBase: cfg.apiBase, app: cfg.app });
