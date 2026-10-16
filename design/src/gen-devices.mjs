// Generates the linked-devices boards in design/canvas/devices/.
// Run: node design/src/gen-devices.mjs
import { writeFileSync, mkdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const OUT = join(dirname(fileURLToPath(import.meta.url)), "../canvas/devices");
mkdirSync(OUT, { recursive: true });

const r = (n) => Math.round(n * 100) / 100;
const rad = (d) => (d * Math.PI) / 180;
const polar = (cx, cy, rr, deg) => [r(cx + rr * Math.sin(rad(deg))), r(cy - rr * Math.cos(rad(deg)))];

const C = { paper: "#EFEDE7", face: "#F7F6F2", graphite: "#1B1B1A", orange: "#FF5A1F", stone: "#8C8A84", night: "#121211", nightFace: "#1E1E1D", line: "rgba(27,27,26,.1)" };

const FONTS =
  '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>' +
  '<link href="https://fonts.googleapis.com/css2?family=Inter+Tight:wght@400;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">';

const page = (file, title, size, body, bg = C.paper) =>
  writeFileSync(
    join(OUT, file),
    `<!doctype html>
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
`
  );

const statusBar = (color) => `<div class="status" style="color:${color}"><span>9:41</span><span class="status-icons">
<svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1" fill="currentColor"/><rect x="5" y="5" width="3" height="7" rx="1" fill="currentColor"/><rect x="10" y="2.5" width="3" height="9.5" rx="1" fill="currentColor"/><rect x="15" y="0" width="3" height="12" rx="1" fill="currentColor"/></svg>
<svg width="26" height="12" viewBox="0 0 26 12"><rect x=".5" y=".5" width="22" height="11" rx="3.5" fill="none" stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="16" height="8" rx="2" fill="currentColor"/><rect x="24" y="4" width="1.6" height="4" rx=".8" fill="currentColor" opacity=".4"/></svg>
</span></div>`;

const phone = (bg, fg, inner) =>
  `<div class="phone" style="background:${bg};color:${fg}">${statusBar(fg)}${inner}<div class="home" style="background:${fg}"></div></div>`;

// ---------- brand pieces ----------

let dialId = 0;
function dial(min, { size = 300, dark = false } = {}) {
  const id = `kn${dialId++}`;
  const c = 150, R = 132;
  const face = dark ? C.nightFace : C.face;
  const tick = dark ? C.paper : C.graphite;
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
    wedge = `<path d="M${c} ${c} L${c} ${c - (R - 24)} A${R - 24} ${R - 24} 0 ${a > 180 ? 1 : 0} 1 ${ex} ${ey} Z" fill="${C.orange}"/>`;
  }
  const [px, py] = polar(c, c, 40, min * 1.5);
  return `<svg width="${size}" height="${size}" viewBox="0 0 300 300" overflow="visible">
<defs><radialGradient id="${id}" cx="35%" cy="30%" r="75%"><stop offset="0" stop-color="#fff" stop-opacity=".18"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>
<circle cx="${c}" cy="${c + 6}" r="${R + 8}" fill="#000" opacity="${dark ? 0.5 : 0.08}"/>
<circle cx="${c}" cy="${c}" r="${R + 8}" fill="${face}"/>
${wedge}${ticks}${nums}
<circle cx="${c}" cy="${c + 3}" r="46" fill="#000" opacity=".18"/><circle cx="${c}" cy="${c}" r="46" fill="${dark ? "#2A2A28" : C.graphite}"/><circle cx="${c}" cy="${c}" r="46" fill="url(#${id})"/>
<line x1="${c}" y1="${c}" x2="${px}" y2="${py}" stroke="${C.orange}" stroke-width="5" stroke-linecap="round"/>
</svg>`;
}

const wordmark = (size = 28, color = C.graphite) =>
  `<div style="font-family:'Inter Tight';font-weight:700;font-size:${size}px;letter-spacing:-.045em;line-height:1;color:${color};display:flex;align-items:baseline">twist<span style="display:inline-block;width:${r(size * 0.2)}px;height:${r(size * 0.2)}px;border-radius:50%;background:conic-gradient(${C.orange} 0 33%, transparent 0);box-shadow:inset 0 0 0 ${r(size * 0.03)}px ${color};margin-left:${r(size * 0.06)}px"></span></div>`;

const big = (t, color = C.graphite, size = 72) =>
  `<div style="font-weight:600;font-size:${size}px;letter-spacing:-.04em;line-height:1;color:${color};font-variant-numeric:tabular-nums">${t}</div>`;
const small = (t, op = 0.55, size = 17) => `<div style="font-weight:500;font-size:${size}px;opacity:${op}">${t}</div>`;

// Device glyphs, drawn in currentColor.
const glyph = {
  phone: (s = 22) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="6.5" y="2" width="11" height="20" rx="2.8"/><line x1="10.5" y1="18.6" x2="13.5" y2="18.6" stroke-linecap="round"/></svg>`,
  laptop: (s = 22) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="5" width="16" height="11" rx="1.6"/><path d="M1.8 19.2h20.4" stroke-linecap="round"/></svg>`,
  tablet: (s = 22) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="4" y="2.5" width="16" height="19" rx="2.6"/><line x1="10.5" y1="18.4" x2="13.5" y2="18.4" stroke-linecap="round"/></svg>`,
  desktop: (s = 22) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><rect x="2.5" y="3.5" width="19" height="12.5" rx="1.6"/><path d="M9 20.5h6M12 16v4.5" stroke-linecap="round"/></svg>`,
  link: (s = 22) => `<svg width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><rect x="2.5" y="5" width="9" height="14" rx="2.2"/><rect x="12.5" y="8" width="9" height="11" rx="1.6"/></svg>`,
};

// State dot: on = reachable now, off = offline, lock = in this session.
const dot = (state, color = C.graphite) => {
  if (state === "on") return `<span class="dot" style="background:${color}"></span>`;
  if (state === "lock") return `<span class="dot" style="background:${C.orange}"></span>`;
  return `<span class="dot" style="box-shadow:inset 0 0 0 1.5px ${color};opacity:.45"></span>`;
};

const pill = (t, bg = C.graphite, fg = C.paper) => `<div class="cta" style="background:${bg};color:${fg}">${t}</div>`;

// ---------- iPhone home ----------

const sliders = `<div class="icon-btn" style="right:-14px"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M4 7h10M18 7h2M4 17h4M12 17h8"/><circle cx="16" cy="7" r="2"/><circle cx="10" cy="17" r="2"/></svg></div>`;

function home({ top = "", caption, button = "Lock", extra = "" }) {
  return phone(
    C.paper,
    C.graphite,
    `<div class="col">
<div class="top" style="position:relative;width:100%">${wordmark()}<div style="position:absolute;inset:0;opacity:.45">${sliders}${top}</div></div>
${extra}
<div class="obj">${dial(90)}</div>
<div class="readout">${big("1:30")}${small(caption)}</div>
${pill(button)}
</div>`
  );
}

page("1a-now-home.html", "Now · Home", "390x844", home({ caption: "until 15:40" }));

const strip = `<div class="strip">${dot("on")}<span>iPhone</span><span class="sep"></span>${dot("on")}<span>MacBook Pro</span><span class="sep"></span>${dot("off")}<span>iPad</span></div>`;
const stripMac = `<div class="strip">${dot("on")}<span>MacBook Pro</span><span class="sep"></span>${dot("on")}<span>iPhone</span><span class="sep"></span>${dot("off")}<span>iPad</span></div>`;
page(
  "1b-home-strip.html",
  "A. Home: the devices under the wordmark",
  "390x844",
  home({ extra: `<a class="strip-wrap">${strip}</a>`, caption: "until 15:40 · on 3 devices" })
);

const devBtn = `<div class="icon-btn" style="left:-14px">${glyph.link(21)}<span class="badge">3</span></div>`;
page(
  "1c-home-button.html",
  "B. Home: a devices button, top left",
  "390x844",
  home({ top: devBtn, caption: "iPhone, MacBook Pro and iPad · until 15:40" })
);

// ---------- devices list (iPhone sheet) ----------

const row = (g, name, status, state, right = "") =>
  `<div class="row"><div class="row-g">${g}</div><div class="row-t"><div class="row-n">${name}</div><div class="row-s">${dot(state)}${status}</div></div>${right}</div>`;

const sheet = (inner, { dim = 0.28, offset = 64 } = {}) => `
<div style="position:absolute;inset:0;background:rgba(0,0,0,${dim})"></div>
<div class="sheet" style="top:${offset}px">
<div class="grabber"></div>
${inner}
</div>`;

const homeBehind = `<div style="position:absolute;inset:0;transform:scale(.93) translateY(10px);border-radius:38px;overflow:hidden;filter:brightness(.92)"><div class="col">
<div class="top">${wordmark()}</div><div class="obj">${dial(90)}</div><div class="readout">${big("1:30")}</div></div></div>`;

const devicesList = `
<div class="sheet-head"><div class="sheet-title">Devices</div><div class="sheet-x">Done</div></div>
<div class="sheet-lede">Lock one and they all lock. Unwind one and they all open.</div>
<div class="group">
${row(glyph.phone(), "iPhone 16 Pro", "This iPhone", "on")}
${row(glyph.laptop(), "MacBook Pro", "Nearby · ready", "on")}
${row(glyph.tablet(), "iPad mini", "Offline · seen yesterday", "off")}
</div>
<div class="group" style="margin-top:14px">
<div class="row"><div class="row-g" style="background:#1B1B1A;color:#EFEDE7"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><path d="M12 5v14M5 12h14"/></svg></div><div class="row-t"><div class="row-n">Add a device</div><div class="row-s">Finds Macs and iPads with Twist open nearby</div></div></div>
</div>
<div class="foot">Only devices on your Apple ID. Locks go straight over Wi-Fi when the devices are close, and through iCloud when they are not.</div>`;

page("1d-devices.html", "Devices sheet", "390x844", phone("#000", C.graphite, homeBehind + sheet(devicesList)), "#000");

// Swipe to remove.
const removeList = `
<div class="sheet-head"><div class="sheet-title">Devices</div><div class="sheet-x">Done</div></div>
<div class="sheet-lede">Lock one and they all lock. Unwind one and they all open.</div>
<div class="group">
${row(glyph.phone(), "iPhone 16 Pro", "This iPhone", "on")}
<div class="row swiped"><div class="row-slide">${`<div class="row-g">${glyph.laptop()}</div><div class="row-t"><div class="row-n">MacBook Pro</div><div class="row-s">${dot("on")}Nearby · ready</div></div>`}</div><div class="remove">Remove</div></div>
${row(glyph.tablet(), "iPad mini", "Offline · seen yesterday", "off")}
</div>
<div class="note-card">Removing is refused while a lock is running, the same way ⌘Q is on the Mac. Otherwise it would be a second way out that skips the unwind.</div>`;
page("1e-remove.html", "Swipe to remove a device", "390x844", phone("#000", C.graphite, homeBehind + sheet(removeList)), "#000");

// ---------- pairing ----------

function radar(center) {
  const rings = [70, 112, 154].map((rr, i) => `<circle cx="160" cy="160" r="${rr}" fill="none" stroke="${C.graphite}" stroke-width="1.4" opacity="${0.22 - i * 0.06}"/>`).join("");
  const [mx, my] = polar(160, 160, 112, 58);
  return `<div style="position:relative;width:320px;height:320px">
<svg width="320" height="320" viewBox="0 0 320 320">${rings}
<path d="M160 160 L160 6 A154 154 0 0 1 ${polar(160, 160, 154, 50).join(" ")} Z" fill="${C.orange}" opacity=".14"/>
<circle cx="160" cy="160" r="40" fill="${C.graphite}"/></svg>
<div style="position:absolute;left:144px;top:144px;color:${C.paper}">${glyph.phone(32)}</div>
${center ? `<div class="found" style="left:${mx - 30}px;top:${my - 30}px">${glyph.laptop(28)}</div>` : ""}
</div>`;
}

page(
  "2a-pair-find.html",
  "1 · iPhone: looking nearby",
  "390x844",
  phone(
    C.paper,
    C.graphite,
    `<div class="col">
<div class="top" style="position:relative;width:100%"><div class="back-l">${`<svg width="12" height="20" viewBox="0 0 12 20"><path d="M10 2 2 10l8 8" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>`}</div><div style="font-weight:600;font-size:17px">Add a device</div></div>
<div class="obj">${radar(true)}</div>
<div class="found-card"><div class="row-g">${glyph.laptop()}</div><div class="row-t"><div class="row-n">MacBook Pro</div><div class="row-s">Twist is open on it</div></div><div class="add solid">Add</div></div>
<div style="margin-top:14px;text-align:center;font-size:15px;line-height:1.4;opacity:.5">Open Twist on the Mac or iPad you want to add. Keep it on the same Wi-Fi.</div>
</div>`
  )
);

const code = (digits, size = 68, color = C.graphite) =>
  `<div class="code" style="color:${color}">${digits
    .split("")
    .map((d) => `<span style="font-size:${size}px;width:${r(size * 0.82)}px;height:${r(size * 1.25)}px">${d}</span>`)
    .join("")}</div>`;

page(
  "2b-pair-code.html",
  "2 · iPhone: same code on both",
  "390x844",
  phone(
    C.paper,
    C.graphite,
    `<div class="col">
<div class="top"><div style="font-weight:600;font-size:17px">Add a device</div></div>
<div class="obj" style="flex-direction:column;gap:28px">
  <div class="pair-pair"><span>${glyph.phone(34)}</span><span class="pair-line"></span><span>${glyph.laptop(38)}</span></div>
  ${code("4719")}
  <div style="text-align:center;font-size:20px;line-height:1.35;font-weight:500;max-width:290px">Check that MacBook Pro shows the same code, then press <b>Join</b> on the Mac.</div>
</div>
<div class="quiet">Cancel</div>
</div>`
  )
);

// Mac desktop scaffold.
const menubar = (right = "") => `<div class="menubar"><span style="font-size:15px">&#63743;</span><b>Twist</b><span>File</span><span>Edit</span><span>Window</span><span style="flex:1"></span>${right}<span>Thu 15 Oct&nbsp;&nbsp;14:10</span></div>`;
const mbIcon = (active = false) =>
  `<span class="mb-icon${active ? " on" : ""}"><span style="display:inline-block;width:14px;height:14px;border-radius:50%;background:conic-gradient(${C.orange} 0 33%, transparent 0);box-shadow:inset 0 0 0 1.6px currentColor"></span></span>`;
const desktop = (inner, right = "") => `<div class="desk">${menubar(right)}${inner}</div>`;

page(
  "2c-pair-mac.html",
  "2 · Mac: the code to confirm",
  "1280x800",
  desktop(`
<div class="mac-alert">
  <div class="pair-pair" style="color:${C.graphite}"><span>${glyph.laptop(40)}</span><span class="pair-line"></span><span>${glyph.phone(34)}</span></div>
  <div style="font-weight:700;font-size:22px;letter-spacing:-.01em;margin-top:22px">iPhone 16 Pro wants to lock together with this Mac</div>
  <div style="margin:22px 0 6px">${code("4719", 52)}</div>
  <div style="font-size:15px;opacity:.55;line-height:1.4;max-width:380px">Join only if your iPhone shows the same code. After that, a lock on either one locks both, and unwinding on either opens both.</div>
  <div class="mac-btns"><div class="mac-btn">Not now</div><div class="mac-btn primary">Join</div></div>
</div>`, mbIcon(true))
);

page(
  "2d-pair-done.html",
  "3 · iPhone: joined",
  "390x844",
  phone(
    C.paper,
    C.graphite,
    `<div class="col">
<div class="top"></div>
<div class="obj" style="flex-direction:column;gap:30px">
  <div class="pair-pair done"><span>${glyph.phone(34)}</span><span class="pair-line"></span><span>${glyph.laptop(38)}</span></div>
  <div style="text-align:center"><div style="font-weight:700;font-size:34px;letter-spacing:-.03em">MacBook Pro is in</div>
  <div style="font-size:18px;line-height:1.4;opacity:.6;margin-top:14px;max-width:300px">Next time you twist the dial on either one, both lock. Unwinding on either opens both.</div></div>
</div>
${pill("Done")}
</div>`
  )
);

// ---------- Mac ----------

const menu = `
<div class="mb-menu">
  <div class="mb-head">${wordmark(20)}<span style="opacity:.5;font-size:13px">Not locked</span></div>
  <div class="mb-sep"></div>
  <div class="mb-label">Devices</div>
  <div class="mb-row">${glyph.laptop(18)}<span>This MacBook Pro</span>${dot("on")}</div>
  <div class="mb-row">${glyph.phone(18)}<span>iPhone 16 Pro</span>${dot("on")}</div>
  <div class="mb-row">${glyph.tablet(18)}<span>iPad mini</span>${dot("off")}</div>
  <div class="mb-sep"></div>
  <div class="mb-item"><b>Lock…</b><span>⌘L</span></div>
  <div class="mb-item">Devices…</div>
  <div class="mb-sep"></div>
  <div class="mb-item muted">Twist keeps running here so your iPhone can lock this Mac.</div>
</div>`;
page("3a-mac-menubar.html", "Mac: menu bar, always running", "1280x800", desktop(menu, mbIcon(true)));

const macWin = (inner, title = "") => `<div class="mac-win"><div class="traffic"><i></i><i></i><i></i><span>${title}</span></div>${inner}</div>`;

page(
  "3b-mac-home.html",
  "Mac: Home with the devices",
  "1280x800",
  desktop(
    macWin(`<div class="mac-home">
  <div class="top" style="position:relative;width:100%">${wordmark()}<div style="position:absolute;inset:0;opacity:.45">${devBtn}</div></div>
  <div style="flex:1;display:flex;align-items:center">${dial(90, { size: 300 })}</div>
  ${big("1:30")}
  <div style="margin-top:12px">${small("MacBook Pro, iPhone and iPad · until 15:40")}</div>
  <div class="cta" style="background:${C.graphite};color:${C.paper};width:300px;margin-top:22px">Lock</div>
</div>`),
    mbIcon()
  )
);

const macDevices = `
<div class="mac-pane">
  <div style="font-weight:700;font-size:24px;letter-spacing:-.02em">Devices</div>
  <div style="font-size:15px;opacity:.55;margin-top:6px">Lock one and they all lock. Unwind one and they all open.</div>
  <div class="group" style="margin-top:22px">
  ${row(glyph.laptop(), "MacBook Pro", "This Mac", "on")}
  ${row(glyph.phone(), "iPhone 16 Pro", "Nearby · ready", "on")}
  ${row(glyph.tablet(), "iPad mini", "Offline · seen yesterday", "off", `<div class="add ghost">Remove</div>`)}
  </div>
  <div class="waiting">${glyph.phone(22)}<div><b>Add an iPhone or iPad</b><br><span>Open Twist on it and tap Add a device. This Mac shows up there by itself.</span></div></div>
</div>`;
page("3c-mac-devices.html", "Mac: Devices window", "1280x800", desktop(macWin(macDevices, "Devices"), mbIcon()));

// ---------- locking together ----------

const lockedPhone = (remaining, end, also) =>
  phone(
    C.night,
    C.paper,
    `<div class="col">
<div class="top" style="opacity:.5">${wordmark(28, C.paper)}</div>
<div class="obj">${dial(remaining, { dark: true })}</div>
<div class="readout">${big("1:12:08", C.paper)}${small(`opens at ${end}`)}</div>
${also}
<div class="quiet" style="margin-top:6px">I need access</div>
</div>`
  );

const alsoRow = `<div class="also">${dot("lock")}<span>MacBook Pro</span><span class="sep" style="background:${C.paper}"></span>${dot("off", C.paper)}<span style="opacity:.6">iPad · when online</span></div>`;
page("4a-phone-locked.html", "iPhone locked: who else is", "390x844", lockedPhone(72, "15:40", alsoRow), C.night);

page(
  "4b-mac-locked.html",
  "Mac locked from the iPhone",
  "1280x800",
  `<div class="mac-lock">
  <div style="opacity:.5">${wordmark(26, C.paper)}</div>
  <div style="flex:1;display:flex;align-items:center">${dial(72, { dark: true, size: 380 })}</div>
  ${big("1:12:08", C.paper, 96)}
  <div style="font-size:20px;opacity:.55;margin-top:12px">opens at 15:40</div>
  <div class="also" style="margin-top:22px">${glyph.phone(16)}<span>Locked from iPhone 16 Pro</span></div>
  <div style="font-size:17px;opacity:.45;margin-top:22px;margin-bottom:36px">I need access</div>
</div>`,
  C.night
);

// iOS lock screen notification (fallback when the iPhone cannot lock itself in the background).
page(
  "4c-phone-notification.html",
  "iPhone asleep: a nudge from the Mac",
  "390x844",
  `<div class="phone lockscreen">${statusBar("#fff")}
<div style="text-align:center;color:#fff;margin-top:70px"><div style="font-size:20px;font-weight:600;opacity:.85;font-family:-apple-system,system-ui">Thursday 15 October</div><div style="font-size:96px;font-weight:700;letter-spacing:-.02em;line-height:1.05;font-family:-apple-system,system-ui">14:10</div></div>
<div class="notif">
  <div class="notif-icon"><span style="display:block;width:22px;height:22px;border-radius:50%;background:conic-gradient(${C.orange} 0 33%, ${C.paper} 0)"></span></div>
  <div style="flex:1"><div style="display:flex;justify-content:space-between"><b>Twist</b><span style="opacity:.55">now</span></div>
  <div style="margin-top:2px"><b>MacBook Pro locked until 15:40</b></div>
  <div>Tap to lock this iPhone too.</div></div>
</div>
<div class="home" style="background:#fff"></div></div>`,
  "#000"
);

// ---------- unwinding everywhere ----------

page(
  "5a-phone-unwind.html",
  "Unwind on iPhone: opens everything",
  "390x844",
  `<div class="uw" style="background:${C.night};color:${C.paper}">${statusBar(C.paper)}
<div class="back"><svg width="12" height="20" viewBox="0 0 12 20"><path d="M10 2 2 10l8 8" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
<div style="position:absolute;left:0;right:0;bottom:0;height:38%;background:${C.orange}"></div>
<div style="position:absolute;left:0;right:0;bottom:38%;height:2px;background:${C.orange};box-shadow:0 0 24px 6px rgba(255,90,31,.45)"></div>
<div style="position:absolute;top:128px;left:32px;right:32px">
  <div style="font-size:17px;font-weight:500;opacity:.5">Session ends on its own in 37 min</div>
  <div style="font-size:150px;font-weight:700;letter-spacing:-.06em;line-height:.9;margin-top:18px;font-variant-numeric:tabular-nums">28<span style="font-size:64px;letter-spacing:-.02em;margin-left:10px">s</span></div>
  <div style="font-size:20px;font-weight:500;line-height:1.35;margin-top:22px;opacity:.7;max-width:300px"><span style="opacity:1;font-weight:600;color:${C.paper}">left to hold.</span> When the screen is full, this iPhone, MacBook Pro and iPad open.</div>
</div>
<div style="position:absolute;left:0;right:0;bottom:120px;display:flex;flex-direction:column;align-items:center;color:${C.graphite}">
  <div style="width:84px;height:84px;border-radius:50%;border:3px solid ${C.graphite};display:flex;align-items:center;justify-content:center"><div style="width:58px;height:58px;border-radius:50%;background:rgba(27,27,26,.18)"></div></div>
  <div style="margin-top:16px;font-size:17px;font-weight:600">Holding</div>
</div>
<div class="home" style="background:${C.graphite}"></div></div>`,
  C.night
);

page(
  "5b-mac-opened.html",
  "Mac: opened from the iPhone",
  "1280x800",
  `<div class="mac-lock" style="background:${C.orange};color:${C.graphite};justify-content:center">
  <div style="font-size:20px;font-weight:600;opacity:.6">${"Unwound on iPhone 16 Pro"}</div>
  <div style="font-size:150px;font-weight:700;letter-spacing:-.05em;line-height:1;margin-top:10px">Open</div>
  <div style="font-size:20px;opacity:.6;margin-top:36px">This Mac is yours again. The lock had 37 min left.</div>
</div>`,
  C.orange
);

page(
  "5c-phone-opened.html",
  "iPhone: opened, one device still catching up",
  "390x844",
  phone(
    C.paper,
    C.graphite,
    `<div class="col">
<div class="top">${wordmark()}</div>
<div class="obj" style="flex-direction:column;gap:24px">
  <div style="font-weight:700;font-size:44px;letter-spacing:-.04em">Open</div>
  <div class="group" style="width:100%">
  ${row(glyph.phone(), "iPhone 16 Pro", "Open", "on")}
  ${row(glyph.laptop(), "MacBook Pro", "Open", "on")}
  ${row(glyph.tablet(), "iPad mini", "Offline · opens as soon as it is back", "off")}
  </div>
  <div style="font-size:15px;line-height:1.4;opacity:.5;text-align:center;max-width:300px">If the iPad stays offline, its lock still ends at 15:40 on its own.</div>
</div>
${pill("Done")}
</div>`
  )
);

console.log("boards written to", OUT);
