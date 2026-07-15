/* pa.js — PA Render web components
 * <script type="module" src="/lib/pa.js"></script>
 * Light-DOM custom elements styled by pa.css. No framework, no build step.
 *
 *   <pa-flow steps="İstek|Arama|Fiyat|Onay" tones="||ok"></pa-flow>
 *   <pa-compare label-before="Önce" label-after="Sonra">
 *     <div slot="before">...</div><div slot="after">...</div>
 *   </pa-compare>
 *   <pa-kpi label="Süre" value="1.2s" delta="-40%" tone="ok"></pa-kpi>
 *   <pa-timeline>
 *     <pa-event date="2026-07-01" title="Hata bildirildi" tone="err">açıklama</pa-event>
 *   </pa-timeline>
 *   <canvas data-chart='{"type":"bar","data":{...}}'></canvas>  (Chart.js lazy)
 */

const css = (strings, ...v) => strings.raw.join("");
const style = document.createElement("style");
style.textContent = css`
  pa-flow { display: flex; flex-wrap: wrap; gap: 6px; align-items: center; margin: 0 0 14px; }
  pa-flow .node {
    font-size: 12.5px; font-weight: 600;
    background: var(--panel); border: 1px solid var(--edge); border-radius: 8px;
    padding: 6px 12px; white-space: nowrap;
  }
  section.b pa-flow .node { background: var(--ground); }
  pa-flow .node.ok   { border-color: var(--ok);   color: var(--ok);   background: var(--ok-soft); }
  pa-flow .node.warn { border-color: var(--warn); color: var(--warn); background: var(--warn-soft); }
  pa-flow .node.err  { border-color: var(--err);  color: var(--err);  background: var(--err-soft); }
  pa-flow .node.accent { border-color: var(--accent); color: var(--accent); background: var(--accent-soft); }
  pa-flow .arrow { color: var(--faint); font-size: 13px; flex: none; }

  pa-compare { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin: 0 0 14px; }
  @media (max-width: 760px) { pa-compare { grid-template-columns: 1fr; } }
  pa-compare .pane { border: 1px solid var(--edge); border-radius: 8px; overflow: hidden; }
  pa-compare .pane .cap {
    font-size: 11px; font-weight: 600; letter-spacing: 0.8px; text-transform: uppercase;
    padding: 6px 12px; border-bottom: 1px solid var(--edge);
  }
  pa-compare .pane.before .cap { color: var(--err); background: var(--err-soft); }
  pa-compare .pane.after  .cap { color: var(--ok);  background: var(--ok-soft); }
  pa-compare .pane .body { padding: 12px 14px; font-size: 13.5px; }
  pa-compare .pane .body > :last-child { margin-bottom: 0; }

  pa-kpi {
    display: inline-flex; flex-direction: column; gap: 2px;
    background: var(--panel); border: 1px solid var(--edge); border-radius: var(--radius);
    padding: 12px 16px; min-width: 130px;
  }
  section.b pa-kpi { background: var(--ground); }
  pa-kpi .label { font-size: 11px; letter-spacing: 0.8px; text-transform: uppercase; color: var(--muted); font-weight: 600; }
  pa-kpi .value { font-size: 22px; font-weight: 700; font-variant-numeric: tabular-nums; letter-spacing: -0.3px; }
  pa-kpi .delta { font-size: 12px; font-weight: 600; font-variant-numeric: tabular-nums; }
  pa-kpi .delta.ok { color: var(--ok); } pa-kpi .delta.err { color: var(--err); }
  pa-kpi .delta.warn { color: var(--warn); } pa-kpi .delta.muted { color: var(--muted); }

  pa-timeline { display: block; margin: 0 0 14px; }
  pa-timeline pa-event { display: flex; gap: 14px; position: relative; padding: 0 0 18px 0; }
  pa-timeline pa-event::before {
    content: ""; position: absolute; left: 5px; top: 16px; bottom: 0;
    width: 2px; background: var(--edge);
  }
  pa-timeline pa-event:last-child::before { display: none; }
  pa-timeline .tdot {
    flex: none; width: 12px; height: 12px; border-radius: 50%;
    background: var(--accent); margin-top: 5px; position: relative; z-index: 1;
    box-shadow: 0 0 0 3px var(--accent-soft);
  }
  pa-timeline .tdot.ok { background: var(--ok); box-shadow: 0 0 0 3px var(--ok-soft); }
  pa-timeline .tdot.warn { background: var(--warn); box-shadow: 0 0 0 3px var(--warn-soft); }
  pa-timeline .tdot.err { background: var(--err); box-shadow: 0 0 0 3px var(--err-soft); }
  pa-timeline .tbody .tdate { font-family: var(--mono); font-size: 11.5px; color: var(--muted); }
  pa-timeline .tbody .ttitle { font-weight: 650; font-size: 14px; display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  pa-timeline .tbody .tdesc { font-size: 13px; color: var(--muted); }
  pa-timeline .tnum {
    flex: none; width: 24px; height: 24px; border-radius: 50%; margin-top: 1px;
    display: inline-flex; align-items: center; justify-content: center; position: relative; z-index: 1;
    font-family: var(--mono); font-size: 11.5px; font-weight: 700; color: #fff;
    background: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft);
  }
  pa-timeline .tnum.ok { background: var(--ok); box-shadow: 0 0 0 3px var(--ok-soft); }
  pa-timeline .tnum.warn { background: var(--warn); box-shadow: 0 0 0 3px var(--warn-soft); }
  pa-timeline .tnum.err { background: var(--err); box-shadow: 0 0 0 3px var(--err-soft); }
  pa-timeline pa-event.n::before { left: 11px; top: 26px; }

  /* rich flow: <pa-flow><pa-step k v tone tag>desc</pa-step>...</pa-flow> */
  pa-flow[rich], pa-flow:has(pa-step) { align-items: stretch; gap: 0; overflow-x: auto; padding-bottom: 6px; }
  pa-flow pa-step {
    flex: 1; min-width: 150px; max-width: 230px; position: relative; margin-right: 26px;
    background: var(--panel); border: 1px solid var(--edge); border-radius: 10px; padding: 11px 13px;
  }
  section.b pa-flow pa-step { background: var(--ground); }
  pa-flow pa-step:last-child { margin-right: 0; }
  pa-flow pa-step::after {
    content: "→"; position: absolute; right: -20px; top: 50%; transform: translateY(-50%);
    color: var(--faint); font-size: 15px; font-weight: 700;
  }
  pa-flow pa-step:last-child::after { display: none; }
  pa-flow pa-step .k { font-family: var(--mono); font-size: 10px; letter-spacing: .8px; text-transform: uppercase; color: var(--faint); }
  pa-flow pa-step .v { font-weight: 650; font-size: 13px; margin: 3px 0 5px; }
  pa-flow pa-step .d { font-size: 11.5px; color: var(--muted); line-height: 1.45; }
  pa-flow pa-step .d :first-child { margin-top: 0; }
  pa-flow pa-step .tag { margin-top: 8px; }
  pa-flow pa-step.ok { border-color: var(--ok); } pa-flow pa-step.warn { border-color: var(--warn); }
  pa-flow pa-step.err { border-color: var(--err); } pa-flow pa-step.accent { border-color: var(--accent); }

  /* flight leg strip: <pa-leg idx="Leg 0" from="IST" to="CDG" date="03 Eki" tone="mc|dashed"> */
  pa-leg {
    display: flex; align-items: center; font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    background: var(--panel); border: 1px solid var(--edge); border-radius: 10px;
    padding: 10px 15px; margin: 0 0 10px;
  }
  section.b pa-leg { background: var(--ground); }
  pa-leg.dashed { border-style: dashed; }
  pa-leg.mc { border-color: var(--accent); box-shadow: inset 3px 0 0 var(--accent); }
  pa-leg .idx { font-size: 10.5px; color: var(--faint); font-weight: 700; letter-spacing: .8px; text-transform: uppercase; margin-right: 14px; flex: none; }
  pa-leg .apt { font-size: 15.5px; font-weight: 700; letter-spacing: .5px; }
  pa-leg .larc { flex: 1; height: 1.5px; margin: 0 12px; position: relative; min-width: 36px; background: var(--edge); }
  pa-leg .larc::after { content: "✈"; position: absolute; right: -2px; top: 50%; transform: translateY(-50%);
    color: var(--accent); font-size: 12px; background: inherit; }
  pa-leg .ldate { margin-left: 14px; font-size: 11.5px; color: var(--muted); flex: none; }
`;
document.head.appendChild(style);

class PaFlow extends HTMLElement {
  connectedCallback() {
    // rich mode: <pa-step> children render themselves; skip attribute mode
    if (this.querySelector("pa-step")) return;
    const steps = (this.getAttribute("steps") || "").split("|");
    const tones = (this.getAttribute("tones") || "").split("|");
    this.innerHTML = steps
      .map((s, i) => `<span class="node ${tones[i] || ""}">${s}</span>`)
      .join(`<span class="arrow" aria-hidden="true">→</span>`);
  }
}

class PaStep extends HTMLElement {
  connectedCallback() {
    const k = this.getAttribute("k") || "";
    const v = this.getAttribute("v") || "";
    const tone = this.getAttribute("tone") || "";
    const tag = this.getAttribute("tag");       // e.g. "err:büyük" → badge
    if (tone) this.classList.add(tone);
    const desc = this.innerHTML.trim();
    let tagHtml = "";
    if (tag) {
      const [tt, txt] = tag.includes(":") ? tag.split(/:(.+)/) : ["info", tag];
      tagHtml = `<div class="tag"><span class="badge ${tt}">${txt}</span></div>`;
    }
    this.innerHTML =
      (k ? `<div class="k">${k}</div>` : "") +
      (v ? `<div class="v">${v}</div>` : "") +
      (desc ? `<div class="d">${desc}</div>` : "") + tagHtml;
  }
}

class PaLeg extends HTMLElement {
  connectedCallback() {
    const idx = this.getAttribute("idx");
    const from = this.getAttribute("from") || "";
    const to = this.getAttribute("to") || "";
    const date = this.getAttribute("date");
    const tone = this.getAttribute("tone") || "";
    if (tone) this.classList.add(...tone.split(" "));
    this.innerHTML =
      (idx ? `<span class="idx">${idx}</span>` : "") +
      `<span class="apt">${from}</span><span class="larc"></span><span class="apt">${to}</span>` +
      (date ? `<span class="ldate">${date}</span>` : "");
  }
}

class PaCompare extends HTMLElement {
  connectedCallback() {
    const before = this.querySelector('[slot="before"]');
    const after = this.querySelector('[slot="after"]');
    const lb = this.getAttribute("label-before") || "Önce";
    const la = this.getAttribute("label-after") || "Sonra";
    const pane = (cls, cap, el) => {
      const p = document.createElement("div");
      p.className = `pane ${cls}`;
      p.innerHTML = `<div class="cap">${cap}</div>`;
      const b = document.createElement("div");
      b.className = "body";
      if (el) b.append(...el.childNodes);
      p.appendChild(b);
      return p;
    };
    const pb = pane("before", lb, before);
    const pa = pane("after", la, after);
    this.innerHTML = "";
    this.append(pb, pa);
  }
}

class PaKpi extends HTMLElement {
  connectedCallback() {
    const label = this.getAttribute("label") || "";
    const value = this.getAttribute("value") || this.textContent.trim();
    const delta = this.getAttribute("delta");
    const tone = this.getAttribute("tone") || "muted";
    this.innerHTML =
      `<span class="label">${label}</span><span class="value">${value}</span>` +
      (delta ? `<span class="delta ${tone}">${delta}</span>` : "");
  }
}

class PaEvent extends HTMLElement {
  connectedCallback() {
    const date = this.getAttribute("date") || "";
    const title = this.getAttribute("title") || "";
    const tone = this.getAttribute("tone") || "";
    const n = this.getAttribute("n");           // numbered node instead of dot
    const desc = this.innerHTML.trim();
    if (n !== null) this.classList.add("n");
    const marker = n !== null
      ? `<span class="tnum ${tone}">${n}</span>`
      : `<span class="tdot ${tone}"></span>`;
    this.innerHTML =
      marker +
      `<div class="tbody">` + (date ? `<div class="tdate">${date}</div>` : "") +
      `<div class="ttitle">${title}</div>` +
      (desc ? `<div class="tdesc">${desc}</div>` : "") + `</div>`;
  }
}

customElements.define("pa-flow", PaFlow);
customElements.define("pa-step", PaStep);
customElements.define("pa-leg", PaLeg);
customElements.define("pa-compare", PaCompare);
customElements.define("pa-kpi", PaKpi);
customElements.define("pa-event", PaEvent);

/* copy section data-n onto its heading so CSS attr() can render the chip */
function tagSectionNumbers() {
  document.querySelectorAll("section.b[data-n]").forEach((s) => {
    const h = s.querySelector(":scope > h2");
    if (h && !h.dataset.n) h.dataset.n = s.dataset.n;
  });
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", tagSectionNumbers);
} else {
  tagSectionNumbers();
}

/* ---- Chart.js lazy auto-init for <canvas data-chart='{...}'> ---- */
async function initCharts() {
  const canvases = document.querySelectorAll("canvas[data-chart]");
  if (!canvases.length) return;
  if (!window.Chart) {
    await new Promise((res, rej) => {
      const s = document.createElement("script");
      s.src = "/lib/vendor/chart.umd.js";
      s.onload = res; s.onerror = rej;
      document.head.appendChild(s);
    });
  }
  const styles = getComputedStyle(document.documentElement);
  const ink = styles.getPropertyValue("--ink").trim();
  const muted = styles.getPropertyValue("--muted").trim();
  const edge = styles.getPropertyValue("--edge").trim();
  const palette = ["--accent", "--ok", "--warn", "--err", "--info", "--faint"]
    .map((v) => styles.getPropertyValue(v).trim());
  Chart.defaults.color = muted;
  Chart.defaults.borderColor = edge;
  Chart.defaults.font.family = styles.getPropertyValue("--sans").trim() || undefined;
  canvases.forEach((c, idx) => {
    if (c._paChart) return;
    let cfg;
    try { cfg = JSON.parse(c.dataset.chart); } catch (e) { return; }
    // colorless datasets get palette colors automatically
    (cfg.data?.datasets || []).forEach((d, i) => {
      const col = palette[i % palette.length];
      if (!d.backgroundColor) d.backgroundColor = cfg.type === "line" ? col + "33" : col;
      if (!d.borderColor) d.borderColor = col;
    });
    cfg.options = Object.assign({ responsive: true, maintainAspectRatio: true }, cfg.options);
    c._paChart = new Chart(c, cfg);
  });
}
if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", initCharts);
} else {
  initCharts();
}
