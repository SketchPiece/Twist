// Generates the brand-direction boards in design/canvas/brand/.
// Run: node design/src/gen-brand.mjs
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "../canvas/brand");
mkdirSync(OUT, { recursive: true });

const r = (n) => Math.round(n * 100) / 100;
const rad = (d) => (d * Math.PI) / 180;
const polar = (cx, cy, rr, deg) => [r(cx + rr * Math.sin(rad(deg))), r(cy - rr * Math.cos(rad(deg)))];

// ---------- shared page pieces ----------

const FONTS =
  '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
  '<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght,SOFT@9..144,300..800,100&family=Inter+Tight:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500;700&family=Space+Grotesk:wght@400;500;600;700&display=swap" rel="stylesheet">';

function page({ title, size, body, bg = "#fff" }) {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="board" content="${size}">
<title>${title}</title>
${FONTS}
<link rel="stylesheet" href="_shared.css">
</head>
<body style="background:${bg}">
${body}
</body>
</html>
`;
}

function statusBar(color) {
  return `<div class="status" style="color:${color}"><span>9:41</span><span class="status-icons">
<svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="currentColor"/><rect x="5" y="5" width="3" height="7" rx="1" fill="currentColor"/><rect x="10" y="2.5" width="3" height="9.5" rx="1" fill="currentColor"/><rect x="15" y="0" width="3" height="12" rx="1" fill="currentColor"/></svg>
<svg width="26" height="12" viewBox="0 0 26 12"><rect x=".5" y=".5" width="22" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="16" height="8" rx="2" fill="currentColor"/><rect x="24" y="4" width="1.6" height="4" rx=".8" fill="currentColor" opacity=".4"/></svg>
</span></div>`;
}

function phone({ bg, fg, inner }) {
  return `<div class="phone" style="background:${bg};color:${fg}">${statusBar(fg)}${inner}<div class="home" style="background:${fg}"></div></div>`;
}

const phonePage = (title, p) => page({ title, size: "390x844", bg: p.bg, body: phone(p) });

// iOS ShieldConfiguration only allows: icon, title, subtitle, background colour (+blur), primary and secondary button text/colours.
// Fonts are always the system font.
function shield({ bg, icon, title, subtitle, titleColor, subColor, primary, primaryBg, primaryFg, secondary, secondaryFg }) {
  return `<div class="shield" style="background:${bg}">
${statusBar(titleColor)}
<div class="shield-mid">
  <div class="shield-icon">${icon}</div>
  <div class="shield-title" style="color:${titleColor}">${title}</div>
  <div class="shield-sub" style="color:${subColor}">${subtitle}</div>
</div>
<div class="shield-btns">
  <div class="shield-primary" style="background:${primaryBg};color:${primaryFg}">${primary}</div>
  <div class="shield-secondary" style="color:${secondaryFg}">${secondary}</div>
</div>
<div class="home" style="background:${titleColor}"></div>
</div>`;
}

// Mini phone (scaled) for the onboarding board.
const mini = (p, scale = 0.78) =>
  `<div class="mini" style="width:${390 * scale}px;height:${844 * scale}px"><div style="transform:scale(${scale});transform-origin:0 0">${phone(p)}</div></div>`;

const squircle = (size, inner, ring = false) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 120 120"><defs><clipPath id="sq${size}"><rect width="120" height="120" rx="27"/></clipPath></defs><g clip-path="url(#sq${size})">${inner}</g>${ring ? `<rect x=".5" y=".5" width="119" height="119" rx="26.5" fill="none" stroke="#fff" stroke-opacity=".14"/>` : ""}</svg>`;

const holdButton = ({ ring, track, fill, fg, progress, label }) => {
  const C = 2 * Math.PI * 52;
  return `<div class="hold"><svg width="128" height="128" viewBox="0 0 128 128">
<circle cx="64" cy="64" r="52" fill="${fill}"/>
<circle cx="64" cy="64" r="52" fill="none" stroke="${track}" stroke-width="6"/>
<circle cx="64" cy="64" r="52" fill="none" stroke="${ring}" stroke-width="6" stroke-linecap="round" stroke-dasharray="${r(C * progress)} ${r(C)}" transform="rotate(-90 64 64)"/>
</svg><div class="hold-label" style="color:${fg}">${label}</div></div>`;
};


const netOff = (color, bg) => `<svg width="168" height="168" viewBox="0 0 168 168"><circle cx="84" cy="84" r="84" fill="${bg}"/>
<g fill="none" stroke="${color}" stroke-width="7" stroke-linecap="round"><path d="M40 72 a62 62 0 0 1 88 0"/><path d="M54 88 a42 42 0 0 1 60 0"/><path d="M68 104 a22 22 0 0 1 32 0"/></g>
<circle cx="84" cy="120" r="6" fill="${color}"/><path d="M44 44 L124 124" stroke="${color}" stroke-width="7" stroke-linecap="round"/></svg>`;

// Three onboarding steps on one board.
function onboarding({ boardBg, bg, fg, hero, net, head, body, small, ctaBg, ctaFg, ctaStyle = "", line, on, caps = false }) {
  const t = (x) => (caps ? x.toUpperCase() : x);
  const text = (h, p) =>
    `<div class="onb-text"><div style="${head}">${h}</div>${p ? `<div style="${body};margin-top:12px">${p}</div>` : ""}</div>`;
  const list = `<div class="list" style="--line:${line}">${["Phone", "Maps", "Messages", "Music"]
    .map((n, k) => `<div class="li"><span>${n}</span><span class="tog ${k < 2 ? "on" : ""}" style="--on:${on}"></span></div>`)
    .join("")}</div>`;
  const cta = (b) => `<div class="cta" style="background:${ctaBg};color:${ctaFg};${ctaStyle}">${t(b)}</div>`;
  const screens = [
    `<div class="top">${small("1 / 3")}</div><div class="obj">${hero}</div>${text("Let Twist lock your apps", "Screen Time access stays on this iPhone.")}${cta("Allow Screen Time")}`,
    `<div class="top">${small("2 / 3")}</div><div class="obj">${net}</div>${text("Let Twist cut the internet", "A local VPN that goes nowhere. Nothing leaves your phone.")}${cta("Allow VPN")}`,
    `<div class="top">${small("3 / 3")}</div><div style="height:28px"></div>${text("What stays open?", "Everything else locks.")}${list}${cta("Done")}`,
  ];
  return `<div class="onb">${screens.map((inner) => mini({ bg, fg, inner: `<div class="col onb-col">${inner}</div>` })).join("")}</div>`;
}

// =====================================================================
// A · YOLK — the egg timer
// =====================================================================

const A = {
  tomato: "#E8613C",
  cream: "#FBF3E2",
  yolk: "#F2B33D",
  ink: "#2A2420",
  night: "#1F1A17",
};

const EGG_PATH = "M130 14 C70 14 26 132 26 212 C26 286 74 330 130 330 C186 330 234 286 234 212 C234 132 190 14 130 14 Z";
const A_STOPS = [0, 15, 30, 45, 60, 90, 120, 180, 240];
const A_LABELS = ["0", "15", "30", "45", "1h", "1½", "2h", "3h", "4h"];
const aIndex = (min) => {
  for (let i = 0; i < A_STOPS.length - 1; i++)
    if (min <= A_STOPS[i + 1]) return i + (min - A_STOPS[i]) / (A_STOPS[i + 1] - A_STOPS[i]);
  return A_STOPS.length - 1;
};

// Front view of a kitchen egg timer: the top half turns, its numbers roll past a fixed pointer.
function egg(min, { w = 260, touch = false, yolkFill = 0, shadow = "rgba(0,0,0,.18)" } = {}) {
  const idx = aIndex(min);
  const STEP = 28; // degrees between labels on the cylinder
  const cx = 130, R = 112, bandY = 176;
  let labels = "";
  for (let i = 0; i < A_STOPS.length; i++) {
    const th = (i - idx) * STEP;
    if (Math.abs(th) > 82) continue;
    const c = Math.cos(rad(th));
    const x = r(cx + R * Math.sin(rad(th)));
    const sel = Math.abs(th) < STEP / 2;
    labels += `<text x="${x}" y="${bandY}" text-anchor="middle" font-family="Fraunces" font-weight="${sel ? 700 : 500}" font-size="22" fill="${A.ink}" opacity="${r(c * c)}" transform="translate(${x} ${bandY}) scale(${r(c)} 1) translate(${-x} ${-bandY})">${A_LABELS[i]}</text>`;
  }
  let ticks = "";
  for (let k = -12; k <= A_STOPS.length * 4; k++) {
    const th = (k / 4 - idx) * STEP;
    if (Math.abs(th) > 84 || k % 4 === 0) continue;
    const x = r(cx + R * Math.sin(rad(th)));
    ticks += `<line x1="${x}" y1="${bandY + 8}" x2="${x}" y2="${bandY + 14}" stroke="${A.ink}" stroke-width="1.6" opacity="${r(Math.cos(rad(th)) * 0.5)}"/>`;
  }
  const yolk =
    yolkFill > 0
      ? `<rect x="0" y="${r(330 - 140 * yolkFill)}" width="260" height="${r(140 * yolkFill)}" fill="${A.yolk}" opacity=".9"/>`
      : "";
  const finger = touch
    ? `<circle cx="196" cy="168" r="26" fill="${A.tomato}" opacity=".18"/><circle cx="196" cy="168" r="26" fill="none" stroke="${A.tomato}" stroke-width="2" opacity=".6"/>
       <path d="M168 128 Q130 118 92 128" fill="none" stroke="${A.ink}" stroke-width="3" stroke-linecap="round" opacity=".35"/><path d="M101 119 L91 128 L103 134" fill="none" stroke="${A.ink}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" opacity=".35"/>`
    : "";
  return `<svg width="${w}" height="${r((w * 344) / 260)}" viewBox="0 0 260 344" overflow="visible">
<defs>
<radialGradient id="eggShade" cx="38%" cy="30%" r="80%"><stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset=".55" stop-color="${A.cream}" stop-opacity="0"/><stop offset="1" stop-color="#C9A983" stop-opacity=".45"/></radialGradient>
<clipPath id="eggClip"><path d="${EGG_PATH}"/></clipPath>
</defs>
<ellipse cx="130" cy="334" rx="92" ry="9" fill="${shadow}"/>
<path d="${EGG_PATH}" fill="${A.cream}"/>
<g clip-path="url(#eggClip)">
  ${yolk}
  <rect x="0" y="198" width="260" height="2.5" fill="${A.ink}" opacity=".18"/>
  ${ticks}${labels}
  <rect width="260" height="344" fill="url(#eggShade)"/>
</g>
<path d="M130 206 L121 222 L139 222 Z" fill="${A.tomato}"/>
${finger}
</svg>`;
}

function eggMark(size, { bg = A.tomato } = {}) {
  // Icon: plain egg with a waist band and pointer. Reads at 16px.
  return squircle(
    size,
    `<rect width="120" height="120" fill="${bg}"/>
<path d="M60 16 C38 16 24 56 24 76 C24 96 40 108 60 108 C80 108 96 96 96 76 C96 56 82 16 60 16 Z" fill="${A.cream}"/>
<rect x="24" y="66" width="72" height="5" fill="${A.ink}" opacity=".85"/>
<rect x="57" y="50" width="6" height="16" rx="3" fill="${A.ink}"/>
<path d="M60 74 L54 84 L66 84 Z" fill="${A.yolk}"/>`
  );
}

const aWordmark = (size, color = A.cream) =>
  `<div style="font-family:Fraunces;font-variation-settings:'SOFT' 100,'opsz' 144;font-weight:600;font-size:${size}px;letter-spacing:-.03em;line-height:1;color:${color}">twist<span style="color:${A.yolk}">.</span></div>`;

const aBig = (t, color = A.cream, size = 64) =>
  `<div style="font-family:Fraunces;font-variation-settings:'SOFT' 100,'opsz' 144;font-weight:500;font-size:${size}px;letter-spacing:-.03em;line-height:1;color:${color};font-variant-numeric:tabular-nums">${t}</div>`;

const aSmall = (t, color = A.cream, op = 0.7) =>
  `<div style="font-family:'Inter Tight';font-weight:500;font-size:17px;color:${color};opacity:${op}">${t}</div>`;

const aBoards = {
  "a1-brand.html": page({
    title: "A · Yolk — brand",
    size: "1280x800",
    bg: A.tomato,
    body: `<div class="sheet" style="color:${A.cream}">
<div class="sheet-tag">A · Yolk</div>
<div class="sheet-grid">
  <div>
    ${aWordmark(168)}
    <div class="sheet-line" style="font-family:Fraunces;font-size:34px;font-weight:400;font-style:italic;margin-top:18px">Twist it. Put it down.</div>
    <p class="sheet-p">The kitchen egg timer. Warm, a little playful, unmistakable. The top half of the egg turns; numbers roll past a fixed pointer, exactly like the real thing.</p>
    <div class="swatches">
      ${[["Tomato", A.tomato, A.cream, true], ["Cream", A.cream, A.ink], ["Yolk", A.yolk, A.ink], ["Ink", A.ink, A.cream]]
        .map(([n, c, t, ring]) => `<div class="sw" style="background:${c};color:${t};${ring ? `box-shadow:inset 0 0 0 2px ${A.cream}` : ""}"><b>${n}</b><span>${c}</span></div>`)
        .join("")}
    </div>
    <div class="type">
      <div><span class="type-name">Fraunces Soft</span><span style="font-family:Fraunces;font-variation-settings:'SOFT' 100;font-size:44px;font-weight:600">1h 30m</span></div>
      <div><span class="type-name">Inter Tight</span><span style="font-family:'Inter Tight';font-size:24px;font-weight:500">Let go to lock</span></div>
    </div>
  </div>
  <div class="icons">
    ${eggMark(240)}
    <div class="icons-row">${eggMark(88)}${eggMark(60)}${eggMark(40)}${eggMark(29)}</div>
    <div class="icons-row" style="margin-top:6px">${eggMark(60, { bg: A.ink })}${eggMark(60, { bg: A.yolk })}</div>
  </div>
</div>
</div>`,
  }),

  "a2-idle.html": phonePage("A · Main, before twisting", {
    bg: A.tomato,
    fg: A.cream,
    inner: `<div class="col">
<div class="top">${aWordmark(30)}</div>
<div class="obj">${egg(0)}</div>
<div class="readout">${aBig("Twist")}${aSmall("15 min – 4 h")}</div>
</div>`,
  }),

  "a3-twisting.html": phonePage("A · Main, while twisting", {
    bg: A.tomato,
    fg: A.cream,
    inner: `<div class="col">
<div class="top">${aWordmark(30)}</div>
<div class="obj">${egg(90, { touch: true })}</div>
<div class="readout">${aBig("1h 30m")}${aSmall("until 11:11")}</div>
<div class="cta" style="background:${A.ink};color:${A.cream}">Lock the phone</div>
</div>`,
  }),

  "a4-locked.html": phonePage("A · Locked", {
    bg: A.night,
    fg: A.cream,
    inner: `<div class="col">
<div class="top" style="opacity:.5">${aWordmark(30)}</div>
<div class="obj">${egg(72, { yolkFill: 0.55, shadow: "rgba(0,0,0,.5)" })}</div>
<div class="readout">${aBig("1:12:08", A.cream, 60)}${aSmall("opens at 10:53")}</div>
<div class="quiet">I need access</div>
</div>`,
  }),

  "a5-shield.html": page({
    title: "A · Shield (system screen)",
    size: "390x844",
    bg: A.tomato,
    body: shield({
      bg: A.tomato,
      icon: eggMark(76, { bg: A.ink }),
      title: "Twisted shut",
      subtitle: "Opens in 1 h 12 min",
      titleColor: A.cream,
      subColor: "rgba(251,243,226,.75)",
      primary: "OK",
      primaryBg: A.cream,
      primaryFg: A.ink,
      secondary: "I need access",
      secondaryFg: A.cream,
    }),
  }),

  "a6-unwind.html": phonePage("A · Emergency unwind", {
    bg: A.night,
    fg: A.cream,
    inner: `<div class="col">
<div class="top">${aSmall("Keep holding to unwind", A.cream, 0.8)}</div>
<div class="obj" style="transform:scale(.86)">${egg(24, { yolkFill: 0.2, shadow: "rgba(0,0,0,.5)" })}</div>
<div class="readout">${aBig("0:38", A.yolk, 60)}${aSmall("Let go to stay locked")}</div>
${holdButton({ ring: A.yolk, track: "rgba(251,243,226,.15)", fill: A.tomato, fg: A.cream, progress: 0.37, label: "Hold" })}
</div>`,
  }),

  "a7-onboarding.html": page({
    title: "A · Onboarding",
    size: "1280x800",
    bg: "#F3E6D3",
    body: onboarding({
      bg: A.tomato, fg: A.cream, hero: egg(0, { w: 190 }), net: netOff(A.cream, "rgba(42,36,32,.22)"),
      head: "font-family:Fraunces;font-variation-settings:'SOFT' 100;font-size:36px;font-weight:600;line-height:1.05;letter-spacing:-.02em",
      body: "font-family:'Inter Tight';font-size:18px;opacity:.75", small: (x) => aSmall(x, A.cream, 0.6),
      ctaBg: A.cream, ctaFg: A.ink, line: "rgba(251,243,226,.18)", on: A.yolk,
    }),
  }),
};

// =====================================================================
// B · DIAL — Braun-style kitchen timer, the time wedge
// =====================================================================

const B = {
  paper: "#EFEDE7",
  graphite: "#1B1B1A",
  orange: "#FF5A1F",
  gray: "#8C8A84",
  dark: "#121211",
};

// One revolution = 4 hours. Orange wedge = time set / time left.
function dial(min, { size = 300, dark = false, touch = false, knob = true } = {}) {
  const c = 150, R = 132;
  const face = dark ? "#1E1E1D" : "#F7F6F2";
  const tick = dark ? "#EFEDE7" : B.graphite;
  let ticks = "";
  for (let m = 0; m < 240; m += 5) {
    const major = m % 60 === 0, mid = m % 15 === 0;
    const [x1, y1] = polar(c, c, R - 4, m * 1.5);
    const [x2, y2] = polar(c, c, R - (major ? 20 : mid ? 13 : 9), m * 1.5);
    ticks += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${tick}" stroke-width="${major ? 3 : mid ? 2 : 1.2}" stroke-linecap="round" opacity="${major ? 1 : mid ? 0.7 : 0.35}"/>`;
  }
  const nums = [0, 1, 2, 3]
    .map((h) => {
      const [x, y] = polar(c, c, R - 40, h * 90);
      return `<text x="${x}" y="${r(y + 8)}" text-anchor="middle" font-family="Inter Tight" font-weight="600" font-size="22" fill="${tick}">${h}</text>`;
    })
    .join("");
  let wedge = "";
  if (min > 0) {
    const a = Math.min(min, 239.9) * 1.5;
    const [ex, ey] = polar(c, c, R - 24, a);
    wedge = `<path d="M${c} ${c} L${c} ${c - (R - 24)} A${R - 24} ${R - 24} 0 ${a > 180 ? 1 : 0} 1 ${ex} ${ey} Z" fill="${B.orange}"/>`;
  }
  const a = min * 1.5;
  const [px, py] = polar(c, c, 40, a);
  const knobSvg = knob
    ? `<circle cx="${c}" cy="${c + 3}" r="46" fill="#000" opacity=".18"/><circle cx="${c}" cy="${c}" r="46" fill="${dark ? "#2A2A28" : B.graphite}"/><circle cx="${c}" cy="${c}" r="46" fill="url(#kn)"/>
       <line x1="${c}" y1="${c}" x2="${px}" y2="${py}" stroke="${B.orange}" stroke-width="5" stroke-linecap="round"/>`
    : "";
  const finger = touch
    ? (() => {
        const [fx, fy] = polar(c, c, 100, a);
        const [ax, ay] = polar(c, c, 156, a - 26);
        const [bx, by] = polar(c, c, 156, a + 4);
        return `<circle cx="${fx}" cy="${fy}" r="26" fill="#fff" opacity=".45"/><circle cx="${fx}" cy="${fy}" r="26" fill="none" stroke="${B.graphite}" stroke-width="1.5" opacity=".4"/>
          <path d="M${ax} ${ay} A156 156 0 0 1 ${bx} ${by}" fill="none" stroke="${B.graphite}" stroke-width="2.5" stroke-linecap="round" opacity=".5"/>`;
      })()
    : "";
  return `<svg width="${size}" height="${size}" viewBox="0 0 300 300" overflow="visible">
<defs><radialGradient id="kn" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="#fff" stop-opacity=".18"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>
<circle cx="${c}" cy="${c + 6}" r="${R + 8}" fill="#000" opacity="${dark ? 0.5 : 0.08}"/>
<circle cx="${c}" cy="${c}" r="${R + 8}" fill="${face}"/>
${wedge}${ticks}${nums}${knobSvg}${finger}
</svg>`;
}

function dialMark(size, { bg = B.graphite } = {}) {
  const [ex, ey] = polar(60, 60, 38, 120);
  return squircle(
    size,
    `<rect width="120" height="120" fill="${bg}"/>
<circle cx="60" cy="60" r="42" fill="${B.paper}"/>
<path d="M60 60 L60 22 A38 38 0 0 1 ${ex} ${ey} Z" fill="${B.orange}"/>
<circle cx="60" cy="60" r="13" fill="${B.graphite}"/>`
  );
}

const bWordmark = (size, color = B.graphite) =>
  `<div style="font-family:'Inter Tight';font-weight:700;font-size:${size}px;letter-spacing:-.045em;line-height:1;color:${color};display:flex;align-items:baseline">twist<span style="display:inline-block;width:${r(size * 0.2)}px;height:${r(size * 0.2)}px;border-radius:50%;background:conic-gradient(${B.orange} 0 33%, transparent 0);box-shadow:inset 0 0 0 ${r(size * 0.03)}px ${color};margin-left:${r(size * 0.06)}px"></span></div>`;

const bBig = (t, color = B.graphite, size = 72) =>
  `<div style="font-family:'Inter Tight';font-weight:600;font-size:${size}px;letter-spacing:-.04em;line-height:1;color:${color};font-variant-numeric:tabular-nums">${t}</div>`;

const bSmall = (t, color = B.graphite, op = 0.55) =>
  `<div style="font-family:'Inter Tight';font-weight:500;font-size:17px;color:${color};opacity:${op}">${t}</div>`;

const bBoards = {
  "b1-brand.html": page({
    title: "B · Dial — brand",
    size: "1280x800",
    bg: B.paper,
    body: `<div class="sheet" style="color:${B.graphite}">
<div class="sheet-tag">B · Dial</div>
<div class="sheet-grid">
  <div>
    ${bWordmark(168)}
    <div class="sheet-line" style="font-family:'Inter Tight';font-size:32px;font-weight:500;margin-top:18px;letter-spacing:-.02em">Twist. Then live.</div>
    <p class="sheet-p">A Braun-style kitchen timer. Quiet paper and graphite, one orange signal. The orange wedge is the time: twist to grow it, watch it shrink back to zero.</p>
    <div class="swatches">
      ${[["Paper", B.paper, B.graphite, true], ["Graphite", B.graphite, B.paper], ["Signal", B.orange, B.graphite], ["Stone", B.gray, B.paper]]
        .map(([n, c, t, ring]) => `<div class="sw" style="background:${c};color:${t};${ring ? `box-shadow:inset 0 0 0 2px ${B.graphite}22` : ""}"><b>${n}</b><span>${c}</span></div>`)
        .join("")}
    </div>
    <div class="type">
      <div><span class="type-name">Inter Tight</span><span style="font-family:'Inter Tight';font-size:44px;font-weight:600;letter-spacing:-.04em">1h 30m</span></div>
      <div><span class="type-name">Inter Tight 500</span><span style="font-family:'Inter Tight';font-size:24px;font-weight:500">Let go to lock</span></div>
    </div>
  </div>
  <div class="icons">
    ${dialMark(240)}
    <div class="icons-row">${dialMark(88)}${dialMark(60)}${dialMark(40)}${dialMark(29)}</div>
    <div class="icons-row" style="margin-top:6px">${dialMark(60, { bg: B.orange })}${dialMark(60, { bg: B.paper })}</div>
  </div>
</div>
</div>`,
  }),

  "b2-idle.html": phonePage("B · Main, before twisting", {
    bg: B.paper,
    fg: B.graphite,
    inner: `<div class="col">
<div class="top">${bWordmark(28)}</div>
<div class="obj">${dial(0)}</div>
<div class="readout">${bBig("0:00", B.graphite)}${bSmall("Twist to set")}</div>
</div>`,
  }),

  "b3-twisting.html": phonePage("B · Main, while twisting", {
    bg: B.paper,
    fg: B.graphite,
    inner: `<div class="col">
<div class="top">${bWordmark(28)}</div>
<div class="obj">${dial(90, { touch: true })}</div>
<div class="readout">${bBig("1:30", B.graphite)}${bSmall("until 11:11")}</div>
<div class="cta" style="background:${B.graphite};color:${B.paper}">Lock</div>
</div>`,
  }),

  "b4-locked.html": phonePage("B · Locked", {
    bg: B.dark,
    fg: B.paper,
    inner: `<div class="col">
<div class="top" style="opacity:.5">${bWordmark(28, B.paper)}</div>
<div class="obj">${dial(72, { dark: true })}</div>
<div class="readout">${bBig("1:12:08", B.paper)}${bSmall("opens at 10:53", B.paper)}</div>
<div class="quiet">I need access</div>
</div>`,
  }),

  "b5-shield.html": page({
    title: "B · Shield (system screen)",
    size: "390x844",
    bg: B.dark,
    body: shield({
      bg: B.dark,
      icon: dialMark(76, { bg: B.graphite }),
      title: "Locked by Twist",
      subtitle: "Opens in 1 h 12 min",
      titleColor: B.paper,
      subColor: "rgba(239,237,231,.6)",
      primary: "OK",
      primaryBg: B.orange,
      primaryFg: B.graphite,
      secondary: "I need access",
      secondaryFg: B.paper,
    }),
  }),

  "b6-unwind.html": phonePage("B · Emergency unwind", {
    bg: B.dark,
    fg: B.paper,
    inner: `<div class="col">
<div class="top">${bSmall("Keep holding to unwind", B.paper, 0.8)}</div>
<div class="obj" style="transform:scale(.86)">${dial(28, { dark: true })}</div>
<div class="readout">${bBig("0:38", B.orange)}${bSmall("Let go to stay locked", B.paper)}</div>
${holdButton({ ring: B.orange, track: "rgba(239,237,231,.14)", fill: "#2A2A28", fg: B.paper, progress: 0.37, label: "Hold" })}
</div>`,
  }),

  "b7-onboarding.html": page({
    title: "B · Onboarding",
    size: "1280x800",
    bg: "#E2DFD7",
    body: onboarding({
      bg: B.paper, fg: B.graphite, hero: dial(60, { size: 230 }), net: netOff(B.orange, "rgba(27,27,26,.06)"),
      head: "font-family:'Inter Tight';font-size:36px;font-weight:700;line-height:1.05;letter-spacing:-.035em",
      body: "font-family:'Inter Tight';font-size:18px;opacity:.6", small: (x) => bSmall(x),
      ctaBg: B.graphite, ctaFg: B.paper, line: "rgba(27,27,26,.12)", on: B.orange,
    }),
  }),
};

// =====================================================================
// C · VAULT — the timer safe
// =====================================================================

const C = {
  night: "#0E0F11",
  steel: "#24272B",
  brass: "#C9A35B",
  bone: "#ECE6DA",
  dim: "#6E6A62",
};

// Safe combination knob. Fixed brass notch at top; the knurled face turns.
function knob(min, { size = 300, touch = false, progress = 0, sealed = false } = {}) {
  const c = 150;
  let knurl = "";
  for (let i = 0; i < 96; i++) {
    const [x1, y1] = polar(c, c, 118, i * 3.75);
    const [x2, y2] = polar(c, c, 128, i * 3.75);
    knurl += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="#000" stroke-width="1.6" opacity=".55"/>`;
  }
  let face = "";
  const labels = ["0", "½", "1", "1½", "2", "2½", "3", "3½"];
  for (let m = 0; m < 240; m += 7.5) {
    const major = m % 30 === 0;
    const [x1, y1] = polar(c, c, 110, m * 1.5);
    const [x2, y2] = polar(c, c, major ? 98 : 104, m * 1.5);
    face += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${C.bone}" stroke-width="${major ? 2.2 : 1}" opacity="${major ? 0.9 : 0.35}"/>`;
  }
  labels.forEach((t, i) => {
    const [x, y] = polar(c, c, 82, i * 45);
    face += `<text x="${x}" y="${r(y + 6)}" text-anchor="middle" font-family="JetBrains Mono" font-weight="500" font-size="16" fill="${C.bone}" opacity=".85" transform="rotate(${i * 45} ${x} ${r(y)})">${t}</text>`;
  });
  const ring =
    progress > 0
      ? (() => {
          const Cc = 2 * Math.PI * 142;
          return `<circle cx="${c}" cy="${c}" r="142" fill="none" stroke="${C.brass}" stroke-width="4" stroke-linecap="round" stroke-dasharray="${r(Cc * progress)} ${r(Cc)}" transform="rotate(-90 ${c} ${c})"/>`;
        })()
      : "";
  const finger = touch
    ? `<circle cx="244" cy="118" r="26" fill="#fff" opacity=".22"/><circle cx="244" cy="118" r="26" fill="none" stroke="#fff" stroke-width="1.5" opacity=".6"/>
       <path d="M222 50 A140 140 0 0 1 270 96" fill="none" stroke="${C.bone}" stroke-width="2.5" stroke-linecap="round" opacity=".5"/>`
    : "";
  return `<svg width="${size}" height="${size}" viewBox="0 0 300 300" overflow="visible">
<defs>
<radialGradient id="steel" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#3A3E44"/><stop offset="1" stop-color="#16181B"/></radialGradient>
<radialGradient id="hub" cx="40%" cy="30%" r="80%"><stop offset="0" stop-color="#E2C27E"/><stop offset="1" stop-color="#8E6E34"/></radialGradient>
</defs>
<circle cx="${c}" cy="${c}" r="142" fill="none" stroke="#fff" stroke-opacity=".06" stroke-width="4"/>
${ring}
<circle cx="${c}" cy="${c + 6}" r="130" fill="#000" opacity=".6"/>
<g transform="rotate(${-min * 1.5} ${c} ${c})">
  <circle cx="${c}" cy="${c}" r="128" fill="url(#steel)"/>
  ${knurl}
  <circle cx="${c}" cy="${c}" r="116" fill="#1C1F23"/>
  ${face}
  <circle cx="${c}" cy="${c}" r="50" fill="url(#hub)"/>
  <rect x="${c - 5}" y="${c - 44}" width="10" height="40" rx="5" fill="#000" opacity=".35"/>
</g>
<path d="M${c} 26 L${c - 8} 12 L${c + 8} 12 Z" fill="${C.brass}"/>
${sealed ? `<g transform="translate(${c - 14} ${c - 16})"><rect x="0" y="12" width="28" height="22" rx="4" fill="#1C1F23"/><path d="M6 12 V8 a8 8 0 0 1 16 0 V12" fill="none" stroke="#1C1F23" stroke-width="4"/></g>` : ""}
${finger}
</svg>`;
}

function vaultMark(size, { bg = C.night } = {}) {
  let knurl = "";
  for (let i = 0; i < 24; i++) {
    const [x1, y1] = polar(60, 62, 34, i * 15);
    const [x2, y2] = polar(60, 62, 40, i * 15);
    knurl += `<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${bg}" stroke-width="3"/>`;
  }
  return squircle(
    size,
    `<rect width="120" height="120" fill="${bg}"/>
<circle cx="60" cy="62" r="40" fill="${C.brass}"/>${knurl}
<circle cx="60" cy="62" r="24" fill="${bg}"/>
<rect x="56" y="40" width="8" height="18" rx="4" fill="${C.brass}"/>
<path d="M60 18 L53 8 L67 8 Z" fill="${C.bone}"/>`,
    true
  );
}

const cWordmark = (size, color = C.bone) =>
  `<div style="font-family:'Space Grotesk';font-weight:600;font-size:${size}px;letter-spacing:.14em;line-height:1;color:${color}">TWIST<span style="color:${C.brass}">°</span></div>`;

const cBig = (t, color = C.bone, size = 60) =>
  `<div style="font-family:'JetBrains Mono';font-weight:500;font-size:${size}px;letter-spacing:-.02em;line-height:1;color:${color}">${t}</div>`;

const cSmall = (t, color = C.bone, op = 0.55) =>
  `<div style="font-family:'Space Grotesk';font-weight:500;font-size:16px;letter-spacing:.12em;text-transform:uppercase;color:${color};opacity:${op}">${t}</div>`;

const cBoards = {
  "c1-brand.html": page({
    title: "C · Vault — brand",
    size: "1280x800",
    bg: C.night,
    body: `<div class="sheet" style="color:${C.bone}">
<div class="sheet-tag">C · Vault</div>
<div class="sheet-grid">
  <div>
    ${cWordmark(132)}
    <div class="sheet-line" style="font-family:'Space Grotesk';font-size:30px;font-weight:500;margin-top:22px;letter-spacing:.02em">Lock it away.</div>
    <p class="sheet-p">The kitchen timer safe. Dark steel, a brass combination knob, mono numerals. Heavier and more serious: the phone goes into the safe until the time is up.</p>
    <div class="swatches">
      ${[["Night", C.night, C.bone, true], ["Steel", C.steel, C.bone], ["Brass", C.brass, C.night], ["Bone", C.bone, C.night]]
        .map(([n, c, t, ring]) => `<div class="sw" style="background:${c};color:${t};${ring ? "box-shadow:inset 0 0 0 2px #ffffff22" : ""}"><b>${n}</b><span>${c}</span></div>`)
        .join("")}
    </div>
    <div class="type">
      <div><span class="type-name">JetBrains Mono</span><span style="font-family:'JetBrains Mono';font-size:40px;font-weight:500">01:30:00</span></div>
      <div><span class="type-name">Space Grotesk</span><span style="font-family:'Space Grotesk';font-size:22px;font-weight:500;letter-spacing:.12em">LET GO TO SEAL</span></div>
    </div>
  </div>
  <div class="icons">
    ${vaultMark(240)}
    <div class="icons-row">${vaultMark(88)}${vaultMark(60)}${vaultMark(40)}${vaultMark(29)}</div>
    <div class="icons-row" style="margin-top:6px">${vaultMark(60, { bg: C.steel })}${vaultMark(60, { bg: "#3B2A1A" })}</div>
  </div>
</div>
</div>`,
  }),

  "c2-idle.html": phonePage("C · Main, before twisting", {
    bg: C.night,
    fg: C.bone,
    inner: `<div class="col">
<div class="top">${cWordmark(22)}</div>
<div class="obj">${knob(0)}</div>
<div class="readout">${cBig("00:00")}${cSmall("Twist to set")}</div>
</div>`,
  }),

  "c3-twisting.html": phonePage("C · Main, while twisting", {
    bg: C.night,
    fg: C.bone,
    inner: `<div class="col">
<div class="top">${cWordmark(22)}</div>
<div class="obj">${knob(90, { touch: true })}</div>
<div class="readout">${cBig("01:30")}${cSmall("Until 11:11")}</div>
<div class="cta" style="background:${C.brass};color:${C.night};font-family:'Space Grotesk';letter-spacing:.12em">SEAL</div>
</div>`,
  }),

  "c4-locked.html": phonePage("C · Locked", {
    bg: C.night,
    fg: C.bone,
    inner: `<div class="col">
<div class="top">${cSmall("Sealed", C.brass, 1)}</div>
<div class="obj">${knob(72, { sealed: true })}</div>
<div class="readout">${cBig("01:12:08")}${cSmall("Opens 10:53")}</div>
<div class="quiet" style="font-family:'Space Grotesk';letter-spacing:.1em;text-transform:uppercase;font-size:14px">I need access</div>
</div>`,
  }),

  "c5-shield.html": page({
    title: "C · Shield (system screen)",
    size: "390x844",
    bg: C.night,
    body: shield({
      bg: C.night,
      icon: vaultMark(76, { bg: C.steel }),
      title: "Sealed",
      subtitle: "Opens in 1 h 12 min",
      titleColor: C.bone,
      subColor: "rgba(236,230,218,.6)",
      primary: "OK",
      primaryBg: C.brass,
      primaryFg: C.night,
      secondary: "I need access",
      secondaryFg: C.bone,
    }),
  }),

  "c6-unwind.html": phonePage("C · Emergency unwind", {
    bg: C.night,
    fg: C.bone,
    inner: `<div class="col">
<div class="top">${cSmall("Keep holding to unseal", C.bone, 0.8)}</div>
<div class="obj" style="transform:scale(.86)">${knob(28, { progress: 0.37 })}</div>
<div class="readout">${cBig("00:38", C.brass)}${cSmall("Let go to stay sealed")}</div>
${holdButton({ ring: C.brass, track: "rgba(236,230,218,.12)", fill: C.steel, fg: C.bone, progress: 0.37, label: "Hold" })}
</div>`,
  }),

  "c7-onboarding.html": page({
    title: "C · Onboarding",
    size: "1280x800",
    bg: "#1A1C1F",
    body: onboarding({
      bg: C.night, fg: C.bone, hero: knob(0, { size: 230 }), net: netOff(C.brass, C.steel),
      head: "font-family:'Space Grotesk';font-size:34px;font-weight:600;line-height:1.08;letter-spacing:-.01em",
      body: "font-family:'Space Grotesk';font-size:18px;opacity:.6", small: (x) => cSmall(x),
      ctaBg: C.brass, ctaFg: C.night, ctaStyle: "font-family:'Space Grotesk';letter-spacing:.1em", line: "rgba(236,230,218,.12)", on: C.brass, caps: true,
    }),
  }),
};

for (const [file, html] of Object.entries({ ...aBoards, ...bBoards, ...cBoards })) writeFileSync(join(OUT, file), html);

// Exported icons (square, unrounded) for the project sidebar icon and later the Xcode asset catalog.
const iconSvg = (inner) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120">${inner}</svg>`;
const strip = (s) => s.replace(/^<svg[^>]*>/, "").replace(/<\/svg>$/, "").replace(/<defs>.*?<\/defs>/s, "").replace(/<g clip-path="[^"]*">/, "<g>");
mkdirSync(join(OUT, "_icons"), { recursive: true });
writeFileSync(join(OUT, "_icons/a-yolk.svg"), iconSvg(strip(eggMark(120))));
writeFileSync(join(OUT, "_icons/b-dial.svg"), iconSvg(strip(dialMark(120))));
writeFileSync(join(OUT, "_icons/c-vault.svg"), iconSvg(strip(vaultMark(120))));
console.log("boards written to", OUT);
