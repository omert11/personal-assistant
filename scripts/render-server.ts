#!/usr/bin/env bun
/* PA Render server v2 — Bun.
 *
 * Topics live in folders: <ROOT>/active/<name>/index.html (+ evidence/, assets).
 * Finished topics are archived by moving the folder to <ROOT>/archive/<name>/
 * (agents do a plain `mv`; the UI offers archive/unarchive buttons too).
 *
 * The server also hosts a shared UI kit at /lib/* (pa.css, pa.js, vendored
 * Chart.js + preact/htm) so topic pages stay tiny — no inline CSS, no build
 * step. `.jsx` / `.tsx` files inside topics are transpiled on the fly.
 *
 * Env: PA_RENDER_ROOT (default ~/.pa-render), PA_RENDER_PORT (default 4787),
 *      PA_RENDER_HOST (default 127.0.0.1)
 */

import { readdirSync, statSync, existsSync, mkdirSync, renameSync } from "node:fs";
import { join, resolve, normalize, extname, dirname } from "node:path";
import { homedir } from "node:os";

const ROOT = resolve(process.env.PA_RENDER_ROOT || join(homedir(), ".pa-render"));
const PORT = Number(process.env.PA_RENDER_PORT || 4787);
const HOST = process.env.PA_RENDER_HOST || "127.0.0.1";
// UI kit lives next to this script in the repo; allow override for non-repo setups.
const LIB = resolve(process.env.PA_RENDER_LIB || resolve(dirname(Bun.main), "../render/lib"));
if (!existsSync(join(LIB, "pa.css"))) {
  console.error(`WARN: UI kit not found at ${LIB} — pages will render unstyled. Set PA_RENDER_LIB.`);
}
const SCOPES = ["active", "archive"] as const;
type Scope = (typeof SCOPES)[number];

const POLL_MS = 500;

for (const s of SCOPES) mkdirSync(join(ROOT, s), { recursive: true });

const MIME: Record<string, string> = {
  ".html": "text/html; charset=utf-8",
  ".htm": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".webp": "image/webp",
  ".txt": "text/plain; charset=utf-8",
  ".md": "text/plain; charset=utf-8",
  ".woff2": "font/woff2",
};

// JSX compiles to unique factory names so the shim can never collide with the
// user's own `h`/`Fragment` imports or declarations.
const transpiler = new Bun.Transpiler({
  loader: "tsx",
  tsconfig: {
    compilerOptions: { jsx: "react", jsxFactory: "__paH", jsxFragmentFactory: "__paFrag" },
  },
});
const JSX_SHIM =
  `import { h as __paH } from "/lib/vendor/preact.mjs";\n` +
  `const __paFrag = (p) => p.children;\n`;

/* ---------- helpers ---------- */

function safeName(name: string): boolean {
  return /^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(name) && !name.includes("..");
}

/** Resolve a relative path inside a base dir; null on traversal. */
function safeJoin(base: string, rel: string): string | null {
  const full = resolve(base, normalize(rel).replace(/^([/\\])+/, ""));
  if (full !== base && !full.startsWith(base + "/")) return null;
  return full;
}

interface TopicMeta { name: string; mtime: number; size: number; }

/** Max mtime + total size across a topic folder (shallow recursive). */
function topicMeta(scope: Scope, name: string): TopicMeta | null {
  const dir = join(ROOT, scope, name);
  try {
    const entries = readdirSync(dir, { recursive: true }) as string[];
    let mtime = statSync(dir).mtimeMs / 1000;
    let size = 0;
    for (const e of entries) {
      try {
        const st = statSync(join(dir, String(e)));
        if (st.isFile()) {
          size += st.size;
          if (st.mtimeMs / 1000 > mtime) mtime = st.mtimeMs / 1000;
        }
      } catch {}
    }
    return { name, mtime, size };
  } catch {
    return null;
  }
}

function listTopics(scope: Scope): TopicMeta[] {
  const dir = join(ROOT, scope);
  let names: string[] = [];
  try {
    names = readdirSync(dir).filter((n) => {
      if (n.startsWith(".")) return false;
      try { return statSync(join(dir, n)).isDirectory(); } catch { return false; }
    });
  } catch {}
  return names
    .map((n) => topicMeta(scope, n))
    .filter((m): m is TopicMeta => m !== null)
    .sort((a, b) => b.mtime - a.mtime);
}

// Signature computations walk the filesystem synchronously; with many SSE
// clients polling every 500ms that becomes O(clients × files). Cache results
// briefly so concurrent clients share one scan per interval.
const SIG_TTL_MS = 400;
const sigCache = new Map<string, { at: number; value: string }>();
function cachedSig(key: string, compute: () => string): string {
  const hit = sigCache.get(key);
  const now = Date.now();
  if (hit && now - hit.at < SIG_TTL_MS) return hit.value;
  const value = compute();
  sigCache.set(key, { at: now, value });
  return value;
}

function dirSignature(): string {
  return cachedSig("dir", () =>
    JSON.stringify(SCOPES.map((s) => listTopics(s).map((t) => [t.name, Math.round(t.mtime * 1000)]))),
  );
}

function topicSignature(scope: Scope, name: string): string {
  return cachedSig(`${scope}/${name}`, () => {
    const m = topicMeta(scope, name);
    return m ? String(Math.round(m.mtime * 1000)) : "gone";
  });
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

async function serveFile(path: string): Promise<Response> {
  const file = Bun.file(path);
  if (!(await file.exists())) return new Response("not found", { status: 404 });
  const ext = extname(path).toLowerCase();
  if (ext === ".jsx" || ext === ".tsx" || ext === ".ts") {
    const code = JSX_SHIM + transpiler.transformSync(await file.text());
    return new Response(code, {
      headers: { "Content-Type": "text/javascript; charset=utf-8", "Cache-Control": "no-store" },
    });
  }
  return new Response(file, {
    headers: { "Content-Type": MIME[ext] || "application/octet-stream", "Cache-Control": "no-store" },
  });
}

function sse(req: Request, signatureFn: () => string): Response {
  server.timeout(req, 0);
  let last = signatureFn();
  let timer: ReturnType<typeof setInterval>;
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(": connected\n\n");
      let beat = 0;
      timer = setInterval(() => {
        try {
          const cur = signatureFn();
          if (cur !== last) {
            last = cur;
            controller.enqueue("event: change\ndata: 1\n\n");
          }
          if (++beat >= 30) { beat = 0; controller.enqueue(": ping\n\n"); }
        } catch {
          clearInterval(timer);
          try { controller.close(); } catch {}
        }
      }, POLL_MS);
    },
    cancel() { clearInterval(timer); },
  });
  return new Response(stream, {
    headers: { "Content-Type": "text/event-stream", "Cache-Control": "no-store", "Connection": "keep-alive" },
  });
}

function moveTopic(name: string, from: Scope, to: Scope): Response {
  if (!safeName(name)) return json({ error: "bad name" }, 400);
  const src = join(ROOT, from, name);
  const dst = join(ROOT, to, name);
  if (!existsSync(src)) return json({ error: "not found" }, 404);
  if (existsSync(dst)) return json({ error: `already exists in ${to}` }, 409);
  renameSync(src, dst);
  return json({ ok: true, name, scope: to });
}

/** Reject cross-origin browser POSTs (DNS-rebinding guard). curl/CLI sends no Origin — allowed. */
function sameOrigin(req: Request): boolean {
  const origin = req.headers.get("origin");
  if (!origin) return true;
  try {
    const u = new URL(origin);
    return (u.hostname === "127.0.0.1" || u.hostname === "localhost") && Number(u.port || 80) === PORT;
  } catch {
    return false;
  }
}

async function mutateTopic(req: Request, from: Scope, to: Scope): Promise<Response> {
  if (!sameOrigin(req)) return json({ error: "forbidden origin" }, 403);
  let body: { name?: string };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid json body" }, 400);
  }
  return moveTopic(body?.name ?? "", from, to);
}

/* ---------- server ---------- */

const server = Bun.serve({
  hostname: HOST,
  port: PORT,
  routes: {
    "/": () => new Response(SHELL, { headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" } }),
    "/favicon.ico": () => new Response(null, { status: 204 }),
    "/api/list": () => json({ active: listTopics("active"), archive: listTopics("archive") }),
    "/api/archive": { POST: (req) => mutateTopic(req, "active", "archive") },
    "/api/unarchive": { POST: (req) => mutateTopic(req, "archive", "active") },
    "/events": (req) => {
      const u = new URL(req.url);
      const topic = u.searchParams.get("topic");
      const scope = (u.searchParams.get("scope") || "active") as Scope;
      if (topic && safeName(topic) && SCOPES.includes(scope)) {
        return sse(req, () => topicSignature(scope, topic));
      }
      return sse(req, dirSignature);
    },
    "/lib/*": (req) => {
      const rel = decodeURIComponent(new URL(req.url).pathname.slice("/lib/".length));
      const full = safeJoin(LIB, rel);
      if (!full) return new Response("forbidden", { status: 403 });
      return serveFile(full);
    },
    "/topic/:scope/:name/*": (req) => {
      const { scope, name } = req.params as { scope: string; name: string };
      if (!SCOPES.includes(scope as Scope) || !safeName(name)) return new Response("forbidden", { status: 403 });
      const base = join(ROOT, scope, name);
      let rel = decodeURIComponent(new URL(req.url).pathname.slice(`/topic/${scope}/${name}/`.length));
      if (rel === "" || rel.endsWith("/")) rel += "index.html";
      const full = safeJoin(base, rel);
      if (!full) return new Response("forbidden", { status: 403 });
      return serveFile(full);
    },
    "/topic/:scope/:name": (req) =>
      Response.redirect(new URL(req.url).pathname + "/", 302),
  },
  fetch() {
    return new Response("not found", { status: 404 });
  },
});

console.log(`PA Render v2: http://${HOST}:${PORT}`);
console.log(`Root: ${ROOT}`);
console.log(`Lib:  ${LIB}`);

/* ---------- shell UI ---------- */

const SHELL = /* html */ `<!doctype html>
<html lang="tr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PA Render — canli analiz</title>
<style>
  :root {
    --ground: #f7f8fa; --panel: #ffffff; --edge: #e7e9ef; --ink: #1a1d26;
    --muted: #6c7180; --faint: #9aa0b0; --accent: #3f6fd8;
    --accent-soft: rgba(63,111,216,0.10); --live: #2f9e6f;
    --shadow: 0 1px 2px rgba(18,20,26,0.06), 0 8px 24px rgba(18,20,26,0.05);
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --ground: #101219; --panel: #171a22; --edge: #262a35; --ink: #e6e8ee;
      --muted: #8b90a0; --faint: #5c6170; --accent: #5b8def;
      --accent-soft: rgba(91,141,239,0.14); --live: #3fb984;
      --shadow: 0 1px 2px rgba(0,0,0,0.4), 0 12px 32px rgba(0,0,0,0.35);
    }
  }
  :root[data-theme="light"] {
    --ground: #f7f8fa; --panel: #ffffff; --edge: #e7e9ef; --ink: #1a1d26;
    --muted: #6c7180; --faint: #9aa0b0; --accent: #3f6fd8;
    --accent-soft: rgba(63,111,216,0.10); --live: #2f9e6f;
  }
  :root[data-theme="dark"] {
    --ground: #101219; --panel: #171a22; --edge: #262a35; --ink: #e6e8ee;
    --muted: #8b90a0; --faint: #5c6170; --accent: #5b8def;
    --accent-soft: rgba(91,141,239,0.14); --live: #3fb984;
  }
  * { box-sizing: border-box; }
  html, body { height: 100%; margin: 0; }
  body {
    display: grid; grid-template-columns: 272px 1fr; height: 100vh;
    background: var(--ground); color: var(--ink);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    font-size: 14px; -webkit-font-smoothing: antialiased;
  }
  .mono { font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace; }

  aside { display: flex; flex-direction: column; min-height: 0; background: var(--panel); border-right: 1px solid var(--edge); }
  .brand { display: flex; align-items: center; gap: 9px; padding: 16px 16px 14px; border-bottom: 1px solid var(--edge); }
  .brand .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--faint); flex: none; transition: background .3s; }
  .brand.online .dot { background: var(--live); animation: pulse 2.4s ease-out infinite; }
  @keyframes pulse {
    0% { box-shadow: 0 0 0 0 rgba(47,158,111,0.45); }
    70% { box-shadow: 0 0 0 7px rgba(47,158,111,0); }
    100% { box-shadow: 0 0 0 0 rgba(47,158,111,0); }
  }
  .brand .title { font-weight: 650; letter-spacing: .2px; }
  .brand .state { margin-left: auto; font-size: 10px; letter-spacing: .8px; text-transform: uppercase; color: var(--muted); }

  .lists { flex: 1 1 auto; min-height: 0; overflow-y: auto; padding: 0 8px 12px; }
  .eyebrow {
    padding: 14px 8px 6px; font-size: 10.5px; letter-spacing: 1px;
    text-transform: uppercase; color: var(--faint);
    display: flex; align-items: center; gap: 6px;
  }
  .eyebrow .count { margin-left: auto; font-size: 10px; color: var(--faint); }
  details.arch-group > summary { list-style: none; cursor: pointer; }
  details.arch-group > summary::-webkit-details-marker { display: none; }
  details.arch-group > summary .chev { transition: transform .15s; display: inline-block; }
  details.arch-group[open] > summary .chev { transform: rotate(90deg); }

  .file { position: relative; display: block; width: 100%; text-align: left; border: 1px solid transparent;
    border-radius: 8px; background: transparent; color: inherit; padding: 9px 10px; margin: 2px 0;
    cursor: pointer; font: inherit; }
  .file:hover { background: var(--accent-soft); }
  .file:focus-visible { outline: 2px solid var(--accent); outline-offset: 1px; }
  .file.active { background: var(--accent-soft); border-color: var(--accent); }
  .file .fname { display: flex; align-items: center; gap: 7px; font-size: 12.5px; font-weight: 550; min-width: 0; }
  .file .fname .txt { min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .file.active .fname .txt { color: var(--accent); }
  .file .udot { flex: none; width: 7px; height: 7px; border-radius: 50%; background: var(--accent);
    margin-left: auto; opacity: 0; transform: scale(.4); transition: opacity .2s, transform .2s; }
  .file.unseen .udot { opacity: 1; transform: scale(1); box-shadow: 0 0 0 3px var(--accent-soft); }
  .file.unseen .fname .txt { font-weight: 680; }
  .file .fmeta { display: block; margin-top: 3px; font-size: 11px; color: var(--muted); font-variant-numeric: tabular-nums; }
  .file .act {
    position: absolute; right: 8px; bottom: 7px;
    font-size: 10px; font-weight: 600; letter-spacing: .3px;
    color: var(--muted); background: var(--panel); border: 1px solid var(--edge);
    border-radius: 5px; padding: 1px 7px; cursor: pointer;
    opacity: 0; transition: opacity .15s;
  }
  .file:hover .act, .file:focus-within .act { opacity: 1; }
  .file .act:hover { color: var(--accent); border-color: var(--accent); }
  .file.archived .fname .txt { color: var(--muted); }
  .empty { padding: 14px 10px; color: var(--muted); font-size: 12px; line-height: 1.6; }

  main { display: flex; flex-direction: column; min-width: 0; min-height: 0; }
  .topbar { display: flex; align-items: center; gap: 12px; padding: 0 18px; height: 46px; flex: none;
    background: var(--panel); border-bottom: 1px solid var(--edge); }
  .topbar .cur { font-weight: 600; font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .topbar .scopechip { font-size: 10px; letter-spacing: .6px; text-transform: uppercase; font-weight: 650;
    color: var(--muted); border: 1px solid var(--edge); border-radius: 999px; padding: 2px 8px; }
  .topbar .scopechip.archive { color: var(--faint); }
  .topbar .badge { margin-left: auto; display: inline-flex; align-items: center; gap: 6px; font-size: 11px;
    color: var(--muted); padding: 4px 9px; border: 1px solid var(--edge); border-radius: 999px; }
  .topbar .badge .b { width: 7px; height: 7px; border-radius: 50%; background: var(--faint); transition: background .3s; }
  .topbar .badge.live .b { background: var(--live); }
  .stage { position: relative; flex: 1 1 auto; min-height: 0; background: var(--ground); }
  iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 0; background: var(--ground); }
  .stage.flash::after { content: ""; position: absolute; inset: 0; pointer-events: none;
    box-shadow: inset 0 0 0 2px var(--accent); opacity: 0; animation: flash .5s ease-out; }
  @keyframes flash { 0% { opacity: .8; } 100% { opacity: 0; } }
  @media (prefers-reduced-motion: reduce) { .brand.online .dot, .stage.flash::after { animation: none; } }
  .placeholder { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center;
    color: var(--muted); font-size: 13px; text-align: center; padding: 24px; line-height: 1.7; }
</style>
</head>
<body>
  <aside>
    <div class="brand" id="brand">
      <span class="dot"></span>
      <span class="title">PA Render</span>
      <span class="state" id="conn">baglaniyor</span>
    </div>
    <div class="lists">
      <div class="eyebrow">Aktif <span class="count" id="cntA"></span></div>
      <div id="listA"></div>
      <details class="arch-group" id="archGroup">
        <summary><div class="eyebrow"><span class="chev">›</span> Arsiv <span class="count" id="cntR"></span></div></summary>
        <div id="listR"></div>
      </details>
    </div>
  </aside>
  <main>
    <div class="topbar">
      <span class="scopechip" id="scopechip" hidden></span>
      <span class="cur" id="cur">Konu secilmedi</span>
      <span class="badge" id="autobadge"><span class="b"></span><span id="autotext">auto-reload</span></span>
    </div>
    <div class="stage" id="stage">
      <div class="placeholder" id="ph">Soldan bir konu sec.<br>Yeni konular otomatik listelenir.</div>
      <iframe id="frame" title="analiz" style="display:none"></iframe>
    </div>
  </main>
<script>
  var current = null;   // {scope, name}
  var topicEvt = null;
  var data = { active: [], archive: [] };
  var seen = {};        // "scope/name" -> seen mtime

  function relTime(mtime) {
    var d = Date.now() / 1000 - mtime;
    if (d < 60) return Math.max(0, Math.floor(d)) + " sn once";
    if (d < 3600) return Math.floor(d / 60) + " dk once";
    if (d < 86400) return Math.floor(d / 3600) + " sa once";
    return Math.floor(d / 86400) + " gun once";
  }
  function kb(size) { return (size >= 1048576 ? (size/1048576).toFixed(1) + " MB" : Math.max(1, Math.round(size/1024)) + " KB"); }
  function key(scope, name) { return scope + "/" + name; }

  function makeRow(t, scope) {
    var isActive = current && current.scope === scope && current.name === t.name;
    var unseen = scope === "active" && !isActive &&
      (seen[key(scope, t.name)] === undefined || t.mtime > seen[key(scope, t.name)] + 1e-6);
    var b = document.createElement("div");
    b.className = "file" + (isActive ? " active" : "") + (unseen ? " unseen" : "") + (scope === "archive" ? " archived" : "");
    b.tabIndex = 0;
    b.setAttribute("role", "button");
    var nm = document.createElement("span");
    nm.className = "fname mono";
    var txt = document.createElement("span"); txt.className = "txt"; txt.textContent = t.name;
    var ud = document.createElement("span"); ud.className = "udot"; ud.title = "guncellendi — henuz gorulmedi";
    nm.appendChild(txt); nm.appendChild(ud);
    var mt = document.createElement("span");
    mt.className = "fmeta";
    mt.textContent = relTime(t.mtime) + "  ·  " + kb(t.size);
    var act = document.createElement("button");
    act.className = "act"; act.type = "button";
    act.textContent = scope === "active" ? "arsivle" : "geri al";
    act.onclick = function (e) {
      e.stopPropagation();
      fetch(scope === "active" ? "/api/archive" : "/api/unarchive", {
        method: "POST", headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: t.name })
      }).then(function () { return loadList(false); });
    };
    b.appendChild(nm); b.appendChild(mt); b.appendChild(act);
    function go() { select(scope, t.name); }
    b.onclick = go;
    b.onkeydown = function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); go(); } };
    return b;
  }

  function renderLists() {
    var la = document.getElementById("listA"), lr = document.getElementById("listR");
    la.innerHTML = ""; lr.innerHTML = "";
    if (!data.active.length) la.innerHTML = '<div class="empty">Henuz aktif konu yok.</div>';
    data.active.forEach(function (t) { la.appendChild(makeRow(t, "active")); });
    if (!data.archive.length) lr.innerHTML = '<div class="empty">Arsiv bos.</div>';
    data.archive.forEach(function (t) { lr.appendChild(makeRow(t, "archive")); });
    document.getElementById("cntA").textContent = data.active.length || "";
    document.getElementById("cntR").textContent = data.archive.length || "";
  }

  function metaOf(scope, name) {
    var arr = data[scope] || [];
    for (var i = 0; i < arr.length; i++) if (arr[i].name === name) return arr[i];
    return undefined;
  }

  function flash() {
    var s = document.getElementById("stage");
    s.classList.remove("flash"); void s.offsetWidth; s.classList.add("flash");
  }

  function frameUrl(scope, name) {
    return "/topic/" + encodeURIComponent(scope) + "/" + encodeURIComponent(name) + "/?t=" + Date.now();
  }

  function reloadFrame() {
    if (!current) return;
    document.getElementById("frame").src = frameUrl(current.scope, current.name);
    var m = metaOf(current.scope, current.name);
    if (m) seen[key(current.scope, current.name)] = m.mtime;
    flash();
  }

  function watchTopic(scope, name) {
    if (topicEvt) { topicEvt.close(); topicEvt = null; }
    topicEvt = new EventSource("/events?scope=" + encodeURIComponent(scope) + "&topic=" + encodeURIComponent(name));
    topicEvt.addEventListener("change", function () { loadList(false).then(reloadFrame); });
    var badge = document.getElementById("autobadge");
    topicEvt.onopen = function () { badge.classList.add("live"); document.getElementById("autotext").textContent = "auto-reload acik"; };
    topicEvt.onerror = function () { badge.classList.remove("live"); document.getElementById("autotext").textContent = "auto-reload kesildi"; };
  }

  function select(scope, name) {
    current = { scope: scope, name: name };
    var m = metaOf(scope, name);
    if (m) seen[key(scope, name)] = m.mtime;
    document.getElementById("ph").style.display = "none";
    var frame = document.getElementById("frame");
    frame.style.display = "block";
    frame.src = frameUrl(scope, name);
    document.getElementById("cur").textContent = name;
    var chip = document.getElementById("scopechip");
    chip.hidden = false;
    chip.textContent = scope === "active" ? "aktif" : "arsiv";
    chip.className = "scopechip" + (scope === "archive" ? " archive" : "");
    if (scope === "archive") document.getElementById("archGroup").open = true;
    renderLists();
    watchTopic(scope, name);
    history.replaceState(null, "", "/?topic=" + encodeURIComponent(name) + "&scope=" + scope);
  }

  function loadList(initial) {
    return fetch("/api/list").then(function (r) { return r.json(); }).then(function (d) {
      data = d;
      if (current) {
        // topic may have been moved between scopes (archive/unarchive)
        if (!metaOf(current.scope, current.name)) {
          var other = current.scope === "active" ? "archive" : "active";
          if (metaOf(other, current.name)) { select(other, current.name); return; }
          current = null;
          document.getElementById("frame").style.display = "none";
          document.getElementById("ph").style.display = "flex";
          document.getElementById("cur").textContent = "Konu secilmedi";
          document.getElementById("scopechip").hidden = true;
          if (topicEvt) { topicEvt.close(); topicEvt = null; }
        }
      }
      renderLists();
      if (initial) {
        var p = new URLSearchParams(location.search);
        var want = p.get("topic"), ws = p.get("scope") || "active";
        if (want && metaOf(ws, want)) select(ws, want);
        else if (data.active.length) select("active", data.active[0].name);
      }
    });
  }

  function watchDir() {
    var evt = new EventSource("/events");
    var brand = document.getElementById("brand");
    var conn = document.getElementById("conn");
    evt.onopen = function () { brand.classList.add("online"); conn.textContent = "canli"; };
    evt.onerror = function () { brand.classList.remove("online"); conn.textContent = "kesildi"; };
    evt.addEventListener("change", function () { loadList(false); });
  }

  loadList(true).then(watchDir);
</script>
</body>
</html>`;
