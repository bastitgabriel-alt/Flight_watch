// Dessins vectoriels du jeu (icône + miniatures), rendus en PNG par Chromium.
const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright-core");

const OUT = process.argv[2];
const font = (name, file) =>
  `@font-face{font-family:'${name}';src:url(data:font/woff2;base64,${fs
    .readFileSync(path.join(__dirname, "node_modules/@fontsource", file))
    .toString("base64")}) format('woff2');}`;
const FONTS =
  font("Creepster", "creepster/files/creepster-latin-400-normal.woff2") +
  font("Fredoka", "fredoka-one/files/fredoka-one-latin-400-normal.woff2");

// Étoiles pseudo-aléatoires (reproductibles)
let seed = 11;
const rand = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
function stars(w, h, n, maxY) {
  let s = "";
  for (let i = 0; i < n; i++) {
    const r = rand() * 1.6 + 0.4;
    s += `<circle cx="${rand() * w}" cy="${rand() * maxY}" r="${r}" fill="#fff" opacity="${0.3 + rand() * 0.7}"/>`;
  }
  return s;
}

// Personnage « Roblox » en blocs. opts : x, y (centre du torse), s (échelle),
// skin, shirt, pants, eyes, grin, cap, crown, faceless, tvhead, bigeye, arms ("down"|"up"|"carry")
function blocky(o) {
  const s = o.s || 1;
  const skin = o.skin || "#f2c9a0";
  const shirt = o.shirt || "#5b2a86";
  const pants = o.pants || "#2a1a33";
  const eyes = o.eyes || "#ff2a2a";
  let g = `<g transform="translate(${o.x},${o.y}) scale(${s})" filter="url(#shade)">`;
  // jambes
  g += `<rect x="-40" y="70" width="38" height="110" rx="6" fill="${pants}"/>`;
  g += `<rect x="2" y="70" width="38" height="110" rx="6" fill="${pants}"/>`;
  // bras
  if (o.arms === "up") {
    g += `<rect x="-84" y="-150" width="40" height="120" rx="8" fill="${shirt}" transform="rotate(-15 -64 -30)"/>`;
    g += `<rect x="44" y="-150" width="40" height="120" rx="8" fill="${shirt}" transform="rotate(15 64 -30)"/>`;
    g += `<rect x="-90" y="-176" width="40" height="34" rx="8" fill="${skin}" transform="rotate(-15 -64 -30)"/>`;
    g += `<rect x="50" y="-176" width="40" height="34" rx="8" fill="${skin}" transform="rotate(15 64 -30)"/>`;
  } else {
    const long = o.longArms ? 90 : 0;
    g += `<rect x="-84" y="-70" width="40" height="${120 + long}" rx="8" fill="${shirt}"/>`;
    g += `<rect x="44" y="-70" width="40" height="${120 + long}" rx="8" fill="${shirt}"/>`;
    g += `<rect x="-84" y="${48 + long}" width="40" height="34" rx="8" fill="${skin}"/>`;
    g += `<rect x="44" y="${48 + long}" width="40" height="34" rx="8" fill="${skin}"/>`;
    if (o.longArms) {
      for (const cx of [-74, -64, -54, 54, 64, 74])
        g += `<rect x="${cx - 2}" y="${82 + long}" width="5" height="26" fill="${eyes}" filter="url(#glow)"/>`;
    }
  }
  // torse
  g += `<rect x="-44" y="-72" width="88" height="146" rx="10" fill="${shirt}"/>`;
  if (o.buttons) {
    for (const by of [-40, -10, 20, 50]) g += `<circle cx="0" cy="${by}" r="6" fill="#ffd24a"/>`;
    g += `<rect x="-44" y="-72" width="88" height="14" fill="#ffd24a" opacity="0.9"/>`;
  }
  // tête
  const hy = -122; // tête posée sur le torse
  if (o.tvhead) {
    g += `<rect x="-62" y="${hy - 52}" width="124" height="100" rx="10" fill="#4a3424"/>`;
    g += `<rect x="-50" y="${hy - 42}" width="96" height="78" rx="14" fill="#9fffd0" filter="url(#glow)"/>`;
    for (let i = 0; i < 9; i++) g += `<rect x="-48" y="${hy - 40 + i * 9}" width="92" height="3" fill="#fff" opacity="0.35"/>`;
    g += `<line x1="-20" y1="${hy - 52}" x2="-45" y2="${hy - 100}" stroke="#aaa" stroke-width="5"/>`;
    g += `<line x1="20" y1="${hy - 52}" x2="45" y2="${hy - 100}" stroke="#aaa" stroke-width="5"/>`;
  } else if (o.bigeye) {
    g += `<circle cx="0" cy="${hy - 10}" r="70" fill="#f5efe8"/>`;
    for (let i = 0; i < 6; i++) {
      const a = (i * 60 + 15) * Math.PI / 180;
      g += `<path d="M ${Math.cos(a) * 66} ${hy - 10 + Math.sin(a) * 66} Q ${Math.cos(a + 0.3) * 50} ${hy - 10 + Math.sin(a + 0.3) * 50} ${Math.cos(a) * 34} ${hy - 10 + Math.sin(a) * 34}" stroke="#c4001a" stroke-width="3" fill="none"/>`;
    }
    g += `<circle cx="0" cy="${hy - 10}" r="34" fill="${eyes}" filter="url(#glow)"/>`;
    g += `<circle cx="0" cy="${hy - 10}" r="15" fill="#050505"/>`;
    g += `<circle cx="-8" cy="${hy - 20}" r="5" fill="#fff"/>`;
  } else {
    g += `<rect x="-50" y="${hy - 50}" width="100" height="100" rx="22" fill="${skin}"/>`;
    if (o.wolf) {
      g += `<path d="M -48 ${hy - 40} L -36 ${hy - 95} L -14 ${hy - 48} Z" fill="${shirt}"/>`;
      g += `<path d="M 48 ${hy - 40} L 36 ${hy - 95} L 14 ${hy - 48} Z" fill="${shirt}"/>`;
      g += `<rect x="-26" y="${hy}" width="52" height="40" rx="10" fill="${shirt}"/>`;
      g += `<circle cx="0" cy="${hy + 8}" r="9" fill="#111"/>`;
      g += `<path d="M -18 ${hy + 38} l 6 14 l 6 -14 M 6 ${hy + 38} l 6 14 l 6 -14" fill="#fff"/>`;
    }
    if (o.calm) {
      // Visage normal (déguisement)
      g += `<circle cx="-20" cy="${hy - 10}" r="7" fill="#1a1a1a"/><circle cx="20" cy="${hy - 10}" r="7" fill="#1a1a1a"/>`;
      g += `<path d="M -18 ${hy + 18} Q 0 ${hy + 30} 18 ${hy + 18}" stroke="#1a1a1a" stroke-width="5" fill="none" stroke-linecap="round"/>`;
    } else if (!o.faceless) {
      g += `<circle cx="-20" cy="${hy - 10}" r="10" fill="${eyes}" filter="url(#glow)"/>`;
      g += `<circle cx="20" cy="${hy - 10}" r="10" fill="${eyes}" filter="url(#glow)"/>`;
      if (o.grin) {
        g += `<path d="M -38 ${hy + 12} Q 0 ${hy + 52} 38 ${hy + 12} Q 0 ${hy + 30} -38 ${hy + 12} Z" fill="#3a0008"/>`;
        for (let i = -3; i <= 3; i++) {
          const tx = i * 10;
          const ty = hy + 16 + Math.abs(i) * -1.5 + (3 - Math.abs(i)) * 3;
          g += `<rect x="${tx - 3.5}" y="${ty}" width="7" height="9" fill="#fffaf0"/>`;
        }
      }
    } else {
      // trois yeux sur un visage vide
      g += `<circle cx="-22" cy="${hy - 18}" r="8" fill="${eyes}" filter="url(#glow)"/><circle cx="22" cy="${hy - 18}" r="8" fill="${eyes}" filter="url(#glow)"/><circle cx="0" cy="${hy + 12}" r="8" fill="${eyes}" filter="url(#glow)"/>`;
    }
  }
  if (o.cap) {
    g += `<rect x="-46" y="${hy - 78}" width="92" height="34" rx="6" fill="#c41e3a"/>`;
    g += `<rect x="-54" y="${hy - 50}" width="108" height="10" rx="4" fill="#1a1a1a"/>`;
    g += `<rect x="-12" y="${hy - 72}" width="24" height="14" rx="3" fill="#ffd24a"/>`;
  }
  if (o.crown) {
    g += `<path d="M -48 ${hy - 48} L -48 ${hy - 92} L -24 ${hy - 66} L 0 ${hy - 102} L 24 ${hy - 66} L 48 ${hy - 92} L 48 ${hy - 48} Z" fill="#ffc828" stroke="#a87a00" stroke-width="3"/>`;
    for (const cx of [-24, 0, 24]) g += `<circle cx="${cx}" cy="${hy - 58}" r="6" fill="#ff1030" filter="url(#glow)"/>`;
  }
  if (o.halo) g += `<ellipse cx="0" cy="${hy - 125}" rx="56" ry="13" fill="none" stroke="${eyes}" stroke-width="7" filter="url(#glow)"/>`;
  g += `</g>`;
  return g;
}

const DEFS = `
<defs>
  <radialGradient id="sky" cx="70%" cy="20%" r="90%">
    <stop offset="0" stop-color="#4a2a7a"/><stop offset="0.5" stop-color="#1c0f33"/><stop offset="1" stop-color="#07040d"/>
  </radialGradient>
  <radialGradient id="bloodsky" cx="70%" cy="22%" r="90%">
    <stop offset="0" stop-color="#7a1a2a"/><stop offset="0.5" stop-color="#2a0a16"/><stop offset="1" stop-color="#0a0306"/>
  </radialGradient>
  <radialGradient id="moon" cx="40%" cy="40%" r="60%">
    <stop offset="0" stop-color="#fffbe6"/><stop offset="0.7" stop-color="#f3dfb0"/><stop offset="1" stop-color="#d9b97a"/>
  </radialGradient>
  <radialGradient id="redmoon" cx="40%" cy="40%" r="60%">
    <stop offset="0" stop-color="#ffb0a0"/><stop offset="0.6" stop-color="#e0303a"/><stop offset="1" stop-color="#8a0a18"/>
  </radialGradient>
  <radialGradient id="moonglow"><stop offset="0" stop-color="#fff2c0" stop-opacity="0.55"/><stop offset="1" stop-color="#fff2c0" stop-opacity="0"/></radialGradient>
  <radialGradient id="redglow"><stop offset="0" stop-color="#ff4040" stop-opacity="0.6"/><stop offset="1" stop-color="#ff4040" stop-opacity="0"/></radialGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff3a0"/><stop offset="0.45" stop-color="#ffc828"/><stop offset="1" stop-color="#ff7a1a"/>
  </linearGradient>
  <linearGradient id="purpletext" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#f0d0ff"/><stop offset="1" stop-color="#a050ff"/>
  </linearGradient>
  <linearGradient id="fog" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#9a7ad0" stop-opacity="0"/><stop offset="1" stop-color="#9a7ad0" stop-opacity="0.55"/>
  </linearGradient>
  <filter id="glow" x="-100%" y="-100%" width="300%" height="300%">
    <feGaussianBlur stdDeviation="5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="bigglow" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="14" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="shade" x="-20%" y="-20%" width="140%" height="140%">
    <feDropShadow dx="0" dy="8" stdDeviation="8" flood-color="#000" flood-opacity="0.6"/>
  </filter>
  <filter id="textfx" x="-10%" y="-30%" width="120%" height="160%">
    <feDropShadow dx="0" dy="0" stdDeviation="10" flood-color="#b04cff" flood-opacity="0.9"/>
    <feDropShadow dx="0" dy="8" stdDeviation="2" flood-color="#000" flood-opacity="0.9"/>
  </filter>
</defs>`;

// Hôtel en silhouette avec fenêtres éclairées
function hotel(x, y, w, h, color) {
  let g = `<g transform="translate(${x},${y})">`;
  g += `<rect x="0" y="0" width="${w}" height="${h}" fill="${color}"/>`;
  g += `<path d="M -10 0 L ${w / 2} ${-h * 0.35} L ${w + 10} 0 Z" fill="${color}"/>`;
  g += `<rect x="${w * 0.72}" y="${-h * 0.32}" width="${w * 0.07}" height="${h * 0.25}" fill="${color}"/>`;
  const cols = 6, rows = 4;
  for (let r = 0; r < rows; r++)
    for (let c = 0; c < cols; c++) {
      const lit = (r * 7 + c * 3) % 4 !== 0;
      g += `<rect x="${w * (0.08 + c * 0.145)}" y="${h * (0.1 + r * 0.2)}" width="${w * 0.08}" height="${h * 0.12}" fill="${lit ? "#ffc070" : "#1a1424"}" ${lit ? 'filter="url(#glow)"' : ""}/>`;
    }
  g += `<rect x="${w * 0.42}" y="${h * 0.78}" width="${w * 0.16}" height="${h * 0.22}" fill="#ffb060" filter="url(#glow)"/>`;
  g += `</g>`;
  return g;
}

function deadTree(x, y, s) {
  return `<g transform="translate(${x},${y}) scale(${s})" stroke="#0a0610" stroke-linecap="round" fill="none">
    <path d="M0 0 L0 -160" stroke-width="18"/><path d="M0 -90 L-60 -150 M-40 -130 L-70 -125" stroke-width="9"/>
    <path d="M0 -120 L55 -190 M35 -165 L70 -170" stroke-width="8"/><path d="M0 -160 L-20 -215" stroke-width="7"/></g>`;
}

function title(x, y, size, text, fill = "url(#gold)") {
  return `<text x="${x}" y="${y}" text-anchor="middle" font-family="Creepster" font-size="${size}" fill="${fill}" stroke="#1a0626" stroke-width="${size / 14}" paint-order="stroke" filter="url(#textfx)">${text}</text>`;
}

function page(w, h, body) {
  return `<!doctype html><html><head><style>${FONTS} html,body{margin:0;background:#000}</style></head>
  <body><svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${DEFS}${body}</svg></body></html>`;
}

// ---------------------------------------------------------------- icône 512
function icon() {
  const W = 512;
  let b = `<rect width="${W}" height="${W}" fill="url(#sky)"/>`;
  b += stars(W, W, 70, 260);
  b += `<circle cx="390" cy="110" r="150" fill="url(#moonglow)"/><circle cx="390" cy="110" r="72" fill="url(#moon)"/>`;
  b += `<circle cx="365" cy="95" r="12" fill="#d8c08a" opacity="0.5"/><circle cx="410" cy="130" r="8" fill="#d8c08a" opacity="0.5"/>`;
  b += hotel(20, 300, 150, 140, "#140a20") + hotel(350, 290, 150, 150, "#140a20");
  b += deadTree(470, 470, 0.7);
  b += blocky({ x: 256, y: 400, s: 1.25, skin: "#f2c9a0", shirt: "#6a1f8a", eyes: "#ff1a2a", grin: true, cap: true, buttons: true });
  b += `<rect y="380" width="${W}" height="132" fill="url(#fog)"/>`;
  b += `<rect y="400" width="${W}" height="112" fill="#07040d" opacity="0.55"/>`;
  b += title(256, 86, 64, "STEAL AN", "url(#purpletext)");
  b += title(256, 482, 104, "ANOMALY");
  return page(W, W, b);
}

// ---------------------------------------------------------------- miniatures 1920x1080
function thumbReception() {
  const W = 1920, H = 1080;
  let b = `<rect width="${W}" height="${H}" fill="url(#sky)"/>`;
  // intérieur : papier peint, lustre
  b += `<rect width="${W}" height="${H}" fill="#3a0f1c" opacity="0.85"/>`;
  for (let x = 0; x < W; x += 120) b += `<rect x="${x}" y="0" width="60" height="${H}" fill="#4a1426" opacity="0.6"/>`;
  b += `<rect y="640" width="${W}" height="20" fill="#c8a046"/><rect y="660" width="${W}" height="420" fill="#2a1610"/>`;
  b += `<circle cx="960" cy="80" r="260" fill="url(#moonglow)" opacity="0.6"/>`;
  b += `<g filter="url(#glow)">` + [...Array(8)].map((_, i) => `<circle cx="${840 + i * 34}" cy="${110 + (i % 2) * 10}" r="9" fill="#ffd27a"/>`).join("") + `</g>`;
  // cellules avec monstres au fond
  const cells = [
    { x: 1430, o: { crown: true, halo: true, skin: "#ffd700", shirt: "#111", eyes: "#ff0000" }, c: "#ff3c5a" },
    { x: 1690, o: { bigeye: true, shirt: "#5a0a14", eyes: "#ff0030" }, c: "#ffffff" },
  ];
  for (const cell of cells) {
    b += `<rect x="${cell.x - 120}" y="250" width="240" height="420" fill="#120a1a" stroke="${cell.c}" stroke-width="8" filter="url(#glow)"/>`;
    b += blocky({ ...cell.o, x: cell.x, y: 520, s: 0.85 });
    b += `<rect x="${cell.x - 120}" y="250" width="240" height="420" fill="#9fdcff" opacity="0.12"/>`;
  }
  // client suspect
  b += blocky({ x: 560, y: 700, s: 2.2, skin: "#e8b88a", shirt: "#1d5fa8", pants: "#222", eyes: "#ff1a1a", grin: true });
  // comptoir
  b += `<rect x="0" y="830" width="1250" height="250" fill="#4a2a18"/><rect x="0" y="810" width="1260" height="40" rx="8" fill="#e8e2ee"/>`;
  b += `<rect x="0" y="852" width="1250" height="10" fill="#c8a046"/>`;
  b += `<ellipse cx="1170" cy="805" rx="48" ry="16" fill="#8a6a10"/><path d="M 1130 805 Q 1170 735 1210 805 Z" fill="#ffc828"/><circle cx="1170" cy="742" r="9" fill="#ffc828"/>`;
  // carte d'identité qui ne correspond pas
  b += `<g transform="translate(840,600) rotate(-8)"><rect width="300" height="190" rx="14" fill="#fff4dc" stroke="#c8a046" stroke-width="5"/>
        <rect x="18" y="40" width="110" height="130" fill="#a8d8ff"/><rect x="45" y="70" width="56" height="56" rx="12" fill="#c98a5a"/>
        <text x="150" y="70" font-family="Fredoka" font-size="26" fill="#333">CARTE</text><text x="150" y="100" font-family="Fredoka" font-size="26" fill="#333">D'IDENTITÉ</text>
        <text x="80" y="32" font-family="Fredoka" font-size="22" fill="#c41e3a" text-anchor="middle">???</text></g>`;
  b += title(1350, 170, 150, "HUMAIN... OU PAS ?");
  b += `<text x="1350" y="250" text-anchor="middle" font-family="Fredoka" font-size="56" fill="#fff" stroke="#1a0626" stroke-width="8" paint-order="stroke">Repère les anomalies déguisées !</text>`;
  return page(W, H, b);
}

function thumbSteal() {
  const W = 1920, H = 1080;
  let b = `<rect width="${W}" height="${H}" fill="url(#bloodsky)"/>`;
  b += stars(W, H, 160, 600);
  b += `<circle cx="1450" cy="300" r="420" fill="url(#redglow)"/><circle cx="1450" cy="300" r="210" fill="url(#redmoon)"/>`;
  b += hotel(80, 470, 420, 380, "#12060c") + hotel(1350, 500, 460, 350, "#12060c");
  b += deadTree(620, 860, 1.4) + deadTree(1830, 880, 1.1);
  b += `<rect y="820" width="${W}" height="260" fill="#1a0a12"/>`;
  for (let x = 0; x < W; x += 70) b += `<rect x="${x}" y="830" width="64" height="30" rx="6" fill="#2a1420"/>`;
  // propriétaire furieux
  b += blocky({ x: 380, y: 770, s: 1.6, skin: "#f0c090", shirt: "#2a6a3a", eyes: "#ffffff", arms: "up" });
  b += `<text x="380" y="470" text-anchor="middle" font-family="Fredoka" font-size="90" fill="#ff4040" stroke="#000" stroke-width="10" paint-order="stroke">!!</text>`;
  // voleur avec anomalie légendaire au-dessus de la tête
  b += blocky({ x: 1050, y: 820, s: 1.4, skin: "#e0a878", shirt: "#222222", pants: "#111", eyes: "#ffffff", arms: "up" });
  b += `<circle cx="1050" cy="380" r="190" fill="url(#moonglow)"/>`;
  b += blocky({ x: 1050, y: 420, s: 0.8, crown: true, halo: true, skin: "#ffd700", shirt: "#111", eyes: "#ff0000", grin: true });
  for (let i = 0; i < 26; i++) b += `<circle cx="${850 + rand() * 400}" cy="${220 + rand() * 330}" r="${2 + rand() * 5}" fill="#ffe680" filter="url(#glow)"/>`;
  b += `<rect y="900" width="${W}" height="180" fill="url(#fog)"/>`;
  b += title(960, 150, 160, "VOLE LES ANOMALIES RARES !");
  return page(W, H, b);
}

function thumbCollection() {
  const W = 1920, H = 1080;
  let b = `<rect width="${W}" height="${H}" fill="url(#sky)"/>`;
  b += stars(W, H, 140, H);
  const monsters = [
    { o: { grin: true, skin: "#ffe6e6", shirt: "#ff78aa", eyes: "#ff50a0" }, c: "#bebebe", n: "COMMUNE" },
    { o: { tvhead: true, shirt: "#3c3c46" }, c: "#468cff", n: "RARE" },
    { o: { faceless: true, longArms: true, skin: "#0a0a0a", shirt: "#320050", eyes: "#b400ff" }, c: "#aa50ff", n: "ÉPIQUE" },
    { o: { wolf: true, skin: "#b48c6e", shirt: "#5a4637", eyes: "#ff2800" }, c: "#ffbe28", n: "LÉGENDAIRE" },
    { o: { crown: true, halo: true, skin: "#ffd700", shirt: "#111", eyes: "#ff0000", grin: true }, c: "#ff3c5a", n: "MYTHIQUE" },
    { o: { bigeye: true, shirt: "#5a0a14", eyes: "#ff0030" }, c: "#ffffff", n: "SECRÈTE" },
  ];
  monsters.forEach((m, i) => {
    const x = 190 + i * 308;
    b += `<rect x="${x - 135}" y="300" width="270" height="560" rx="18" fill="#130b1c" stroke="${m.c}" stroke-width="10" filter="url(#glow)"/>`;
    b += `<ellipse cx="${x}" cy="800" rx="110" ry="22" fill="${m.c}" opacity="0.35" filter="url(#bigglow)"/>`;
    b += blocky({ ...m.o, x, y: 640, s: 0.95 });
    b += `<text x="${x}" y="920" text-anchor="middle" font-family="Fredoka" font-size="40" fill="${m.c}" stroke="#000" stroke-width="7" paint-order="stroke">${m.n}</text>`;
  });
  b += title(960, 180, 150, "31 ANOMALIES À CAPTURER");
  b += `<text x="960" y="1030" text-anchor="middle" font-family="Fredoka" font-size="52" fill="#fff" stroke="#1a0626" stroke-width="8" paint-order="stroke">Mutations • Événements • Renaissances</text>`;
  return page(W, H, b);
}

// ---------------------------------------------------------------- vidéo verticale 1080x1920
const VW = 1080, VH = 1920;
function lobbyBg(tint) {
  let b = `<rect width="${VW}" height="${VH}" fill="#2a0c16"/>`;
  for (let x = 0; x < VW; x += 120) b += `<rect x="${x}" y="0" width="60" height="${VH}" fill="#3a1222" opacity="0.7"/>`;
  b += `<rect y="1350" width="${VW}" height="22" fill="#c8a046"/><rect y="1372" width="${VW}" height="548" fill="#2a1610"/>`;
  b += `<g filter="url(#glow)">` + [...Array(8)].map((_, i) => `<circle cx="${400 + i * 40}" cy="${120 + (i % 2) * 12}" r="11" fill="#ffd27a"/>`).join("") + `</g>`;
  if (tint) b += `<rect width="${VW}" height="${VH}" fill="${tint}" opacity="0.35"/>`;
  return b;
}
function sceneQuestion() {
  let b = lobbyBg();
  b += blocky({ x: 540, y: 1250, s: 3, skin: "#e8b88a", shirt: "#1d5fa8", pants: "#222", calm: true });
  b += `<rect x="0" y="1500" width="${VW}" height="420" fill="#4a2a18"/><rect x="0" y="1480" width="${VW}" height="40" fill="#e8e2ee"/>`;
  b += title(540, 300, 120, "CE CLIENT...");
  b += title(540, 450, 130, "EST-IL HUMAIN ?", "url(#purpletext)");
  return page(VW, VH, b);
}
function sceneReveal() {
  let b = lobbyBg("#ff0020");
  b += blocky({ x: 540, y: 1250, s: 3, skin: "#e8b88a", shirt: "#1d5fa8", pants: "#222", eyes: "#ff1a1a", grin: true });
  b += `<rect x="0" y="1500" width="${VW}" height="420" fill="#4a2a18"/><rect x="0" y="1480" width="${VW}" height="40" fill="#e8e2ee"/>`;
  b += title(540, 380, 260, "NON !!", "url(#gold)");
  return page(VW, VH, b);
}
function sceneCapture() {
  let b = `<rect width="${VW}" height="${VH}" fill="url(#sky)"/>` + stars(VW, VH, 120, VH);
  b += `<rect x="190" y="560" width="700" height="1000" rx="24" fill="#130b1c" stroke="#ff3c5a" stroke-width="14" filter="url(#glow)"/>`;
  b += `<ellipse cx="540" cy="1460" rx="260" ry="40" fill="#ff3c5a" opacity="0.4" filter="url(#bigglow)"/>`;
  b += blocky({ x: 540, y: 1200, s: 2, crown: true, halo: true, skin: "#ffd700", shirt: "#111", eyes: "#ff0000", grin: true });
  for (let i = 0; i < 40; i++) b += `<circle cx="${200 + rand() * 680}" cy="${560 + rand() * 1000}" r="${3 + rand() * 7}" fill="#ffe680" filter="url(#glow)"/>`;
  b += title(540, 300, 150, "CAPTURE-LES !");
  b += `<text x="540" y="1700" text-anchor="middle" font-family="Fredoka" font-size="90" fill="#7dff8a" stroke="#000" stroke-width="10" paint-order="stroke">+$800 / seconde</text>`;
  return page(VW, VH, b);
}
function sceneSteal() {
  let b = `<rect width="${VW}" height="${VH}" fill="url(#bloodsky)"/>` + stars(VW, VH, 120, 900);
  b += `<circle cx="760" cy="620" r="420" fill="url(#redglow)"/><circle cx="760" cy="620" r="230" fill="url(#redmoon)"/>`;
  b += hotel(40, 900, 420, 420, "#12060c") + hotel(620, 940, 420, 380, "#12060c");
  b += `<rect y="1320" width="${VW}" height="600" fill="#1a0a12"/>`;
  b += blocky({ x: 540, y: 1560, s: 1.8, skin: "#e0a878", shirt: "#222222", pants: "#111", eyes: "#ffffff", arms: "up" });
  b += `<circle cx="540" cy="1040" r="230" fill="url(#moonglow)"/>`;
  b += blocky({ x: 540, y: 1080, s: 1.0, crown: true, halo: true, skin: "#ffd700", shirt: "#111", eyes: "#ff0000", grin: true });
  b += title(540, 260, 140, "VOLE CELLES");
  b += title(540, 410, 140, "DES AUTRES !");
  return page(VW, VH, b);
}
function sceneOutro() {
  let b = `<rect width="${VW}" height="${VH}" fill="url(#sky)"/>` + stars(VW, VH, 160, VH);
  b += `<circle cx="780" cy="420" r="320" fill="url(#moonglow)"/><circle cx="780" cy="420" r="150" fill="url(#moon)"/>`;
  b += hotel(60, 1300, 440, 420, "#140a20") + hotel(580, 1280, 440, 440, "#140a20");
  b += blocky({ x: 540, y: 1380, s: 1.8, shirt: "#6a1f8a", eyes: "#ff1a2a", grin: true, cap: true, buttons: true });
  b += `<rect y="1500" width="${VW}" height="420" fill="url(#fog)"/>`;
  b += title(540, 700, 130, "STEAL AN", "url(#purpletext)");
  b += title(540, 880, 190, "ANOMALY");
  b += `<text x="540" y="1640" text-anchor="middle" font-family="Fredoka" font-size="72" fill="#fff" stroke="#1a0626" stroke-width="10" paint-order="stroke">Gratuit sur Roblox</text>`.replace('y="1640"', 'y="1790"');
  b += `<text x="540" y="1870" text-anchor="middle" font-family="Fredoka" font-size="50" fill="#e0c8ff" stroke="#1a0626" stroke-width="8" paint-order="stroke">31 anomalies • Événements • Renaissances</text>`;
  return page(VW, VH, b);
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome" });
  const jobs = process.argv[3] === "video" ? [
    ["v1.png", VW, VH, sceneQuestion()],
    ["v2.png", VW, VH, sceneReveal()],
    ["v3.png", VW, VH, sceneCapture()],
    ["v4.png", VW, VH, sceneSteal()],
    ["v5.png", VW, VH, sceneOutro()],
  ] : [
    ["Icon.png", 512, 512, icon()],
    ["Thumbnail1_Reception.png", 1920, 1080, thumbReception()],
    ["Thumbnail2_Vol.png", 1920, 1080, thumbSteal()],
    ["Thumbnail3_Collection.png", 1920, 1080, thumbCollection()],
  ];
  for (const [name, w, h, html] of jobs) {
    const pageObj = await browser.newPage({ viewport: { width: w, height: h } });
    await pageObj.setContent(html);
    await pageObj.evaluate(() => document.fonts.ready);
    await pageObj.waitForTimeout(200);
    await pageObj.screenshot({ path: path.join(OUT, name) });
    await pageObj.close();
    console.log(name);
  }
  await browser.close();
})();
