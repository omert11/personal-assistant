// Gemini chat in the owner's signed-in Chrome through the omp browser relay: text answers and image generation.
// Usage in a JS eval cell (re-import after a kernel reset; cell aborts drop globals):
//   const G = (await import("<skill>/scripts/gemini.js?" + Date.now())).install(browser);
//   const answer = await G.ask("<question>", { log: display });            // text reply
//   const file = await G.generate("<prompt>", "/abs/out.png", { log: display }); // image
//   await G.close();                                                        // close the agent's Gemini tab
// ask(): send, wait for the NEWEST reply to finish, return its text (error reply -> "Yeniden yap", then resend).
// generate(): select the image tool ("+" -> "Görüntü oluştur"), send, wait on the NEWEST reply, recover
// (text reply -> "Yeniden yap"; freeze -> reload the same chat), then a verified download (full size if it
// matches the reply, else the canvas preview). The returned path may end in .jpg: Gemini serves JPEG.
// The image tool stays selected after sending: call newChat() before ask() in a chat that generated images.
// Lower level: newChat(), attach(files), lastResponse(), replyText(), ensureImageTool(), send(), redo(),
// waitNew(respBefore, s), reload(), download(out), shot().
// One ask()/generate() per eval cell with timeout >= 900 s; Gemini fails often, so expect retries.
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

// Always the owner's signed-in profile, never a fresh omp-managed browser:
// - remote container (has ~/.local/bin/gbrowser): the shared logged-in headless Chromium over CDP :9222,
//   started with `gbrowser` when it is down;
// - Mac: the owner's own Chrome through the omp browser relay (the relay extension must be connected).
const GBROWSER = path.join(os.homedir(), ".local/bin/gbrowser");
const GBROWSER_CDP = "http://127.0.0.1:9222";
const RELAY_CDP = "http://127.0.0.1:9224";
const RELAY_ANCHOR_URL = "about:blank#gemini-anchor";
const DOWNLOADS = path.join(os.homedir(), "Downloads");

// One browser-level CDP command on the relay. The relay lists only tabs it was handed, often none, and
// adopting one would drive an owner tab; the agent creates and closes its own background anchor tab instead.
async function relayCdp(method, params = {}) {
  const ws = new WebSocket(RELAY_CDP.replace(/^http/, "ws") + "/cdp");
  await new Promise((ok, bad) => { ws.onopen = ok; ws.onerror = () => bad(new Error("gemini: relay websocket failed")); });
  try {
    const m = await new Promise((ok, bad) => {
      const timer = setTimeout(() => bad(new Error(`gemini: relay ${method} timed out`)), 15000);
      ws.onmessage = (e) => { const r = JSON.parse(e.data); if (r.id === 1) { clearTimeout(timer); ok(r); } };
      ws.send(JSON.stringify({ id: 1, method, params }));
    });
    if (m.error) throw new Error(`gemini: relay ${method}: ${m.error.message}`);
    return m.result;
  } finally { ws.close(); }
}

const relayAnchors = async () =>
  (await relayCdp("Target.getTargets")).targetInfos.filter(t => t.type === "page" && t.url === RELAY_ANCHOR_URL);

async function backendApp() {
  if (fs.existsSync(GBROWSER)) {
    execFileSync(GBROWSER, { stdio: "ignore", timeout: 30000 });
    return { cdp_url: GBROWSER_CDP };
  }
  const v = await fetch(`${RELAY_CDP}/json/version`).then(r => r.json()).catch(() => null);
  if (!v || v.error) {
    throw new Error("gemini: the owner's Chrome is not reachable through the omp browser relay"
      + (v?.error ? ` (${v.error})` : "") + "; ask the owner to connect the relay extension in Chrome");
  }
  if (!(await relayAnchors()).length) await relayCdp("Target.createTarget", { url: RELAY_ANCHOR_URL, background: true });
  return { relay: true, target: RELAY_ANCHOR_URL };
}

// `pageTag`: the agent works in its own Gemini tab marked with window.name = pageTag (created on first use with
// a fresh chat at /app), so the owner's Gemini tabs are never touched. "" uses the first Gemini tab found.
export function install(browser, { anchorTab = "gemini-anchor", pageTag = "agent-gemini" } = {}) {
  // Attach to the backend without navigating any owner tab, then find or create the Gemini page through
  // raw Puppeteer. `browser.open({app:{relay:true,target:"gemini"}})` on a page we just created can time out.
  const mode = fs.existsSync(GBROWSER) ? "cdp" : "relay";
  const anchor = async () => {
    try { const t = browser.tab(anchorTab); await t.url(); return t; } catch {}
    return browser.open({ name: anchorTab, app: await backendApp() });
  };
  const run = async (fn, args = [], timeout = 120000) => (await anchor()).run(async ({ browser }, src, a, tag, mode, dl) => {
    const pages = await browser.pages();
    let p;
    if (tag) {
      for (const x of pages) {
        if (!x.url().includes("gemini.google.com")) continue;
        if (await x.evaluate(() => window.name).catch(() => "") === tag) { p = x; break; }
      }
      if (!p) {
        p = await browser.newPage();
        await p.goto("https://gemini.google.com/app", { waitUntil: "domcontentloaded" });
        await p.evaluate((t) => { window.name = t; }, tag);
      }
    } else {
      p = pages.find(x => x.url().includes("gemini.google.com"));
      if (!p) { p = await browser.newPage(); await p.goto("https://gemini.google.com/app", { waitUntil: "domcontentloaded" }); }
    }
    // Never bringToFront(): it raises the owner's Chrome window and steals focus on every call. Instead make
    // the background tab behave as focused and active so it keeps rendering, decoding images and taking input.
    const cdp = await p.createCDPSession();
    await cdp.send("Emulation.setFocusEmulationEnabled", { enabled: true }).catch(() => {});
    await cdp.send("Page.setWebLifecycleState", { state: "active" }).catch(() => {});
    // Headless gbrowser has no download folder of its own; the owner's Chrome keeps its own setting.
    if (mode === "cdp") await cdp.send("Page.setDownloadBehavior", { behavior: "allow", downloadPath: dl }).catch(() => {});
    const f = eval("(" + src + ")");
    return await f(p, a);
  }, { args: [fn.toString(), args, pageTag, mode, DOWNLOADS], timeout });

  // Pick the image tool: "+" ("Yükleme ve araçlar") -> "Görüntü oluştur". Without it Gemini often answers
  // with text ("I cannot directly render or generate image files…", a Midjourney prompt, an error line).
  // Active state = a "Resimler"/"Images" chip in the composer. Re-checked before every send.
  const ensureImageTool = () => run(async (p) => {
    // Active = the composer shows the aspect-ratio picker ("En-boy oranı") or the image placeholder
    // ("Resminizi tarif edin"). Walking up from the editor broke once reference images were attached.
    const active = () => p.evaluate(() => {
      const ed = document.querySelector('div[contenteditable="true"]');
      const ph = ed ? (ed.getAttribute("data-placeholder") || ed.getAttribute("aria-label") || "") : "";
      // Sidebar chat titles can contain "aspect ratio" too, so ignore buttons in navigation and history.
      return /resminizi tarif|describe your image/i.test(ph) ||
        [...document.querySelectorAll("button")].some(b => !b.closest("nav, side-navigation, bard-sidenav, [role='navigation'], conversations-list") &&
          /en-boy oranı|aspect ratio/i.test((b.getAttribute("aria-label") || "") + " " + b.innerText));
    });
    // Up to 3 rounds: open the "+" menu only if the item is not already showing (a second click closes it),
    // then click "Görüntü oluştur". The menu sometimes renders late or the click toggles it shut.
    for (let round = 0; round < 3; round++) {
      if (await active()) return round ? "selected" : "already";
      const findItem = () => p.evaluate(() => {
        const it = [...document.querySelectorAll('[role="menuitem"], [role="menuitemcheckbox"], .mat-mdc-menu-item')]
          .find(e => /görüntü oluştur|create image/i.test(e.innerText));
        if (it) it.click();
        return !!it;
      });
      if (!(await findItem())) {
        await p.evaluate(() => {
          const b = [...document.querySelectorAll("button")]
            .find(x => /yükleme ve araçlar|upload.*tools|tools/i.test(x.getAttribute("aria-label") || ""));
          if (b) b.click();
        });
        for (let i = 0; i < 6 && !(await findItem()); i++) await new Promise(r => setTimeout(r, 500));
      }
      await new Promise(r => setTimeout(r, 1200));
    }
    return (await active()) ? "selected" : "failed";
  });

  // Attach reference images to the composer. The `input[type=file][accept="image/*"]` exists only while the
  // "+" menu is open, so open it, upload, close it with Escape and wait until a preview chip shows.
  const attach = (files) => run(async (p, a) => {
    const findInput = () => p.$('input[type="file"][accept*="image"]');
    let input = await findInput();
    if (!input) {
      await p.evaluate(() => {
        const b = [...document.querySelectorAll("button")]
          .find(x => /yükleme ve araçlar|upload.*tools|tools/i.test(x.getAttribute("aria-label") || ""));
        if (b) b.click();
      });
      for (let i = 0; i < 10 && !(input = await findInput()); i++) await new Promise(r => setTimeout(r, 400));
    }
    if (!input) return "no-input";
    await input.uploadFile(...a[0]);
    await p.keyboard.press("Escape").catch(() => {});
    for (let i = 0; i < 40; i++) {
      const n = await p.evaluate(() => document.querySelectorAll('[class*="preview"] img, uploader-file-preview, [data-test-id*="file-preview"]').length);
      if (n >= a[0].length) return "attached " + n;
      await new Promise(r => setTimeout(r, 500));
    }
    return "uploaded (no preview chip detected)";
  }, [files]);

  // State of the newest model reply: `finished` = its action bar shows the localised Redo button
  // ("Yeniden yap"), which appears only once the reply stopped streaming; `loaded` = generated images in it
  // that finished decoding. Everything is scoped to this reply: a page-wide "download full size" count mixes
  // in older replies and once downloaded the previous sheet instead of the new one.
  const lastResponse = () => run(async (p) => p.evaluate(() => {
    const all = [...document.querySelectorAll("model-response")];
    const last = all.at(-1);
    if (!last) return { n: 0, imgs: 0, loaded: 0, finished: false, text: "" };
    const finished = [...last.querySelectorAll("button")].some(b =>
      /yeniden yap|redo|regenerate/i.test(b.getAttribute("aria-label") || b.innerText));
    const imgs = [...last.querySelectorAll('img[alt*="üretilmiş"], img[alt*="generated" i]')];
    const loaded = imgs.filter(i => i.complete && i.naturalWidth > 0).length;
    return { n: all.length, imgs: imgs.length, loaded, finished, text: last.innerText.slice(0, 200) };
  }));

  const send = (text) => run(async (p, a) => {
    // A freshly opened chat renders the composer after domcontentloaded.
    await p.waitForSelector('div[contenteditable="true"]', { visible: true, timeout: 30000 });
    await p.click('div[contenteditable="true"]');
    const s = await p.createCDPSession();
    await s.send("Input.insertText", { text: a[0] });
    await new Promise(r => setTimeout(r, 600));
    await p.keyboard.press("Enter");
    return "sent";
  }, [text]);

  // Click Redo ("Yeniden yap") on the newest reply: regenerates the same prompt in place.
  const redo = () => run(async (p) => {
    return p.evaluate(() => {
      const last = [...document.querySelectorAll("model-response")].at(-1);
      const b = last && [...last.querySelectorAll("button")].find(x =>
        /yeniden yap|redo|regenerate/i.test(x.getAttribute("aria-label") || x.innerText));
      if (!b) return false;
      b.click();
      return true;
    });
  });

  // Backup wording match; the structural check (finished reply without an image) catches any wording, e.g.
  // "I encountered an error doing what you asked. Could you try again?".
  const ERROR_RE = /went wrong|try (your request )?again|encounter(ed|ing) an error|try something else|bir sorun|bir hata/i;

  // -> "IMAGE" | "TEXT" (reply finished without an image) | "TIMEOUT". `respBefore` = model-response count
  // before this attempt; only a newer reply counts. The "Creating your image" text lingers after completion,
  // so it is never read.
  const waitNew = async (respBefore, maxS = 200) => {
    const t0 = Date.now();
    while (Date.now() - t0 < maxS * 1000) {
      await new Promise(r => setTimeout(r, 6000));
      try {
        const lr = await lastResponse();
        if (lr.n <= respBefore) continue;
        if (lr.loaded > 0) return "IMAGE";
        if (lr.imgs === 0 && (lr.finished || ERROR_RE.test(lr.text))) return "TEXT";
      } catch { /* transient relay error: keep polling */ }
    }
    return "TIMEOUT";
  };

  // Reload the same chat (keeps the style-anchor history). Frozen pages often show a finished image after it.
  const reload = () => run(async (p) => {
    await p.reload({ waitUntil: "domcontentloaded" });
    await new Promise(r => setTimeout(r, 5000));
    return p.url();
  });

  // Send, wait, recover, download. Every send first selects the image tool (ensureImageTool). Recovery:
  // - text reply instead of an image -> click Redo on that reply once (no duplicate prompt in the chat);
  //   a second text reply in a row -> resend the prompt with the image tool re-selected;
  // - timeout -> reload the chat and recount (the image often finished behind a frozen view); a reply that
  //   ended without an image counts as a text reply, anything else gets the prompt resent.
  const generate = async (prompt, outPath, { tries = 4, waitS = 180, log = () => {} } = {}) => {
    let action = "send";
    for (let t = 1; t <= tries; t++) {
      let respBefore;
      if (action === "redo" && await redo()) {
        await new Promise(r => setTimeout(r, 12000));  // let the old action bar disappear
        respBefore = (await lastResponse()).n - 1;
      } else {
        action = "send";
        log(`image tool: ${await ensureImageTool()}`);
        respBefore = (await lastResponse()).n;
        await send(prompt);
      }
      let r = await waitNew(respBefore, waitS);
      log(`try ${t} (${action}): ${r}`);
      if (r === "TIMEOUT") {
        await reload();
        const lr = await lastResponse();
        r = lr.n > respBefore && lr.loaded > 0 ? "IMAGE"
          : lr.n > respBefore && lr.finished && lr.imgs === 0 ? "TEXT"
          : await waitNew(respBefore, 60);
        log(`after reload: ${r}`);
      }
      if (r === "IMAGE") return download(outPath, { log });
      action = r === "TEXT" && action === "send" ? "redo" : "send";
    }
    throw new Error(`gemini: no image after ${tries} tries for ${outPath}`);
  };

  // Saves the NEWEST reply's image. Two copies are taken:
  // - preview: the reply's <img> drawn to a canvas (PNG, about 1024 px). Always the right picture.
  // - full size: that reply's "Tam boyutlu resmi indir" (shown on hover). Larger, but in image-tool chats it
  //   sometimes delivers an OLDER image (Tradewick's UI-kit reply downloaded the previous character sheet).
  // Both are scaled to 32x32 in the page and compared. When they match, the full-size file is kept with its real
  // extension (Gemini serves JPEG); otherwise the preview PNG is kept. Returns the written path.
  const download = async (outPath, { log = () => {} } = {}) => {
    const dl = DOWNLOADS;
    fs.mkdirSync(dl, { recursive: true });
    const base = outPath.replace(/\.(png|jpe?g)$/i, "");
    fs.mkdirSync(path.dirname(outPath), { recursive: true });
    // The canvas evaluate sometimes times out on a busy background tab; retry it a few times.
    let preview = null;
    for (let attempt = 0; attempt < 4 && !preview; attempt++) {
      try {
        preview = await run(async (p) => p.evaluate(() => {
          const last = [...document.querySelectorAll("model-response")].at(-1);
          const im = last && last.querySelector('img[alt*="üretilmiş"], img[alt*="generated" i]');
          if (!im) return "";
          const c = document.createElement("canvas");
          c.width = im.naturalWidth; c.height = im.naturalHeight;
          c.getContext("2d").drawImage(im, 0, 0);
          // JPEG q0.95: a 2752 px PNG data URL (~10 MB) times out across the relay; JPEG is ~1-2 MB.
          return c.toDataURL("image/jpeg", 0.95);
        }), [], 120000);
      } catch (e) { log(`preview capture failed (${String(e).slice(0, 60)}); retrying`); await new Promise(r => setTimeout(r, 3000)); }
    }
    if (!preview) throw new Error("gemini: newest reply has no image");
    const previewPath = base + ".jpg";
    fs.writeFileSync(previewPath, Buffer.from(preview.split(",")[1], "base64"));

    const before = new Set(fs.readdirSync(dl));
    // The full-size click is best effort: on a busy background tab hover/evaluate can time out.
    const clicked = await run(async (p) => {
      const img = await p.evaluateHandle(() => {
        const last = [...document.querySelectorAll("model-response")].at(-1);
        const im = last.querySelector('img[alt*="üretilmiş"], img[alt*="generated" i]');
        im.scrollIntoView({ block: "center" });
        return im;
      });
      await img.asElement().hover();
      await new Promise(r => setTimeout(r, 800));
      return p.evaluate(() => {
        const last = [...document.querySelectorAll("model-response")].at(-1);
        const b = [...last.querySelectorAll("button")].find(x =>
          /tam boyutlu resmi indir|download full size/i.test(x.getAttribute("aria-label") || x.innerText));
        if (!b) return false;
        b.click();
        return true;
      });
    }).catch((e) => { log(`full-size click failed (${String(e).slice(0, 60)})`); return false; });
    // Only Gemini's own file name counts: the owner's Chrome may finish unrelated downloads meanwhile. A
    // Chrome whose download folder is not ~/Downloads never shows the file; 30 s then falls back to the preview.
    const GEMINI_FILE = /^Gemini_Generated_Image_.*\.(jpe?g|png|webp)$/i;
    let full = null;
    for (let i = 0; clicked && i < 30 && !full; i++) {
      await new Promise(r => setTimeout(r, 1000));
      const nf = fs.readdirSync(dl).filter(f => !before.has(f) && GEMINI_FILE.test(f));
      if (nf.length) full = path.join(dl, nf[0]);
    }
    if (!full) { log("full-size download missing; kept preview"); return previewPath; }

    const fullData = fs.readFileSync(full);
    const mime = fullData[0] === 0xff && fullData[1] === 0xd8 ? "image/jpeg" : "image/png";
    const diff = await run(async (p, a) => p.evaluate(async (pv, fu) => {
      const load = (src) => new Promise((ok, bad) => { const i = new Image(); i.onload = () => ok(i); i.onerror = bad; i.src = src; });
      const px = (i) => { const c = document.createElement("canvas"); c.width = c.height = 32;
        const g = c.getContext("2d"); g.drawImage(i, 0, 0, 32, 32); return g.getImageData(0, 0, 32, 32).data; };
      const [x, y] = [px(await load(pv)), px(await load(fu))];
      let s = 0; for (let k = 0; k < x.length; k++) s += Math.abs(x[k] - y[k]);
      return s / x.length;
    }, a[0], a[1]), [preview, `data:${mime};base64,${fullData.toString("base64")}`], 120000);
    if (diff > 12) {
      fs.unlinkSync(full);
      log(`full-size image differs from the reply (diff ${diff.toFixed(1)}); kept preview`);
      return previewPath;
    }
    const fullPath = base + (mime === "image/jpeg" ? ".jpg" : ".png");
    fs.copyFileSync(full, fullPath);
    fs.unlinkSync(full);
    if (fullPath !== previewPath) fs.unlinkSync(previewPath);
    return fullPath;
  };

  const shot = (p_ = "/tmp/gemini.png") => run(async (p, a) => { await p.screenshot({ path: a[0] }); return a[0]; }, [p_]);

  // Open a fresh chat in the agent's tab (drops the image tool and the previous context).
  const newChat = () => run(async (p, a) => {
    await p.goto("https://gemini.google.com/app", { waitUntil: "domcontentloaded" });
    if (a[0]) await p.evaluate((t) => { window.name = t; }, a[0]);
    await new Promise(r => setTimeout(r, 3000));
    return p.url();
  }, [pageTag]);

  // Full text of the newest reply (the message body, without the action bar).
  const replyText = () => run(async (p) => p.evaluate(() => {
    const last = [...document.querySelectorAll("model-response")].at(-1);
    if (!last) return "";
    return (last.querySelector("message-content") || last).innerText.trim();
  }));

  // Send a text prompt and return the reply text. Recovery: a short error reply -> Redo once, then resend;
  // timeout -> reload the same chat and re-check the newest reply.
  const ask = async (prompt, { tries = 3, waitS = 300, log = () => {} } = {}) => {
    let action = "send";
    for (let t = 1; t <= tries; t++) {
      let respBefore;
      if (action === "redo" && await redo()) {
        await new Promise(r => setTimeout(r, 12000));  // let the old action bar disappear
        respBefore = (await lastResponse()).n - 1;
      } else {
        action = "send";
        respBefore = (await lastResponse()).n;
        await send(prompt);
      }
      let done = false;
      for (const t0 = Date.now(); !done && Date.now() - t0 < waitS * 1000;) {
        await new Promise(r => setTimeout(r, 3000));
        try { const lr = await lastResponse(); done = lr.n > respBefore && lr.finished; } catch { /* transient relay error */ }
      }
      if (!done) {
        await reload();
        const lr = await lastResponse();
        done = lr.n > respBefore && lr.finished;
      }
      const text = done ? await replyText() : "";
      const failed = !text || (text.length < 300 && ERROR_RE.test(text));
      log(`try ${t} (${action}): ${!done ? "TIMEOUT" : failed ? "ERROR" : "DONE"}`);
      if (!failed) return text;
      action = done && action === "send" ? "redo" : "send";
    }
    throw new Error(`gemini: no answer after ${tries} tries`);
  };

  // Close the agent's own Gemini tab (only with a pageTag: never an owner's tab) and release the anchor handle
  // (releasing never closes attached pages). On the relay the anchor tab is the agent's own, so close it too.
  const close = async () => {
    const r = pageTag ? await run(async (p) => { await p.close(); return "closed"; }) : "skipped (no pageTag)";
    await browser.close({ name: anchorTab }).catch(() => {});
    if (mode === "relay") for (const t of await relayAnchors()) await relayCdp("Target.closeTarget", { targetId: t.targetId });
    return r;
  };

  return { run, newChat, attach, lastResponse, replyText, ensureImageTool, send, redo, waitNew, reload, ask, generate, download, shot, close, ERROR_RE };
}
