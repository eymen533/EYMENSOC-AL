const STORAGE_KEY = "longcatSoloBest";

const MAPS = [
  {
    id: "bahce",
    name: "Pembe Bahçe",
    tips: ["Kaydır, Longcat gibi uzar!", "Tüm boşluğu doldur"],
    rows: [
      "#######",
      "#S....#",
      "#.....#",
      "#.....#",
      "#.....#",
      "#######",
    ],
  },
  {
    id: "kopru",
    name: "Şeker Köprü",
    tips: ["Zikzak yolu takip et", "Tek atışta duvara kadar"],
    rows: [
      "########",
      "#S.....#",
      "######.#",
      "#......#",
      "#.######",
      "#......#",
      "########",
    ],
  },
  {
    id: "labirent",
    name: "Yıldız Yol",
    tips: ["Uzun koridorları boya", "Sıkışınca Yeniden"],
    rows: [
      "#########",
      "#S......#",
      "#######.#",
      "#.......#",
      "#.#######",
      "#.......#",
      "#######.#",
      "#.......#",
      "#########",
    ],
  },
  {
    id: "spiral",
    name: "Tatlı Spiral",
    tips: ["Zikzak şeker yolu", "Son kareye kadar"],
    rows: [
      "#######",
      "#S....#",
      "#####.#",
      "#.....#",
      "#.#####",
      "#.....#",
      "#####.#",
      "#.....#",
      "#######",
    ],
  },
  {
    id: "garaj",
    name: "Kedi Garajı",
    tips: ["Köşeleri planla", "Şampiyon ol!"],
    rows: [
      "########",
      "#S.....#",
      "######.#",
      "#......#",
      "#.######",
      "#......#",
      "########",
    ],
  },
  {
    id: "liman",
    name: "Deniz Limanı",
    tips: ["Limanı tamamen doldur", "Uzun atışlar yap"],
    rows: [
      "#########",
      "#S......#",
      "#######.#",
      "#.......#",
      "#.#######",
      "#.......#",
      "#########",
    ],
  },
];

const $ = (id) => document.getElementById(id);
const ui = {
  home: $("home"),
  how: $("how"),
  pause: $("pause"),
  result: $("result"),
  hud: $("hud"),
  level: $("level"),
  score: $("score"),
  fillPct: $("fillPct"),
  bestHome: $("bestHome"),
  finalScore: $("finalScore"),
  resultTitle: $("resultTitle"),
  resultEmoji: $("resultEmoji"),
  resultBest: $("resultBest"),
  btnPlay: $("btnPlay"),
  btnHow: $("btnHow"),
  btnHowClose: $("btnHowClose"),
  btnPause: $("btnPause"),
  btnRestart: $("btnRestart"),
  btnResume: $("btnResume"),
  btnQuit: $("btnQuit"),
  btnAgain: $("btnAgain"),
  btnHome: $("btnHome"),
  banner: $("banner"),
  bannerText: $("bannerText"),
  scorePill: document.querySelector(".score-pill"),
  app: $("app"),
};

const canvas = $("sky");
const ctx = canvas.getContext("2d");

const state = {
  mode: "home",
  running: false,
  width: 0,
  height: 0,
  dpr: 1,
  score: 0,
  best: Number(localStorage.getItem(STORAGE_KEY) || 0),
  mapIndex: 0,
  stuckCount: 0,
  fill: null,
  particles: [],
  rings: [],
  floatTexts: [],
  flash: 0,
  swipe: null,
  facing: { dc: 1, dr: 0 },
  lastTs: 0,
};

let audioCtx = null;

function ensureAudio() {
  if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  if (audioCtx.state === "suspended") audioCtx.resume();
}

function beep(freq, dur, type = "sine", gain = 0.08) {
  try {
    ensureAudio();
    const o = audioCtx.createOscillator();
    const g = audioCtx.createGain();
    o.type = type;
    o.frequency.value = freq;
    g.gain.value = gain;
    o.connect(g);
    g.connect(audioCtx.destination);
    o.start();
    g.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + dur);
    o.stop(audioCtx.currentTime + dur);
  } catch (_) {}
}

function playPop() {
  beep(520, 0.08, "triangle", 0.09);
  setTimeout(() => beep(780, 0.1, "sine", 0.06), 40);
}
function playCheer() {
  [523, 659, 784, 1046].forEach((f, i) => setTimeout(() => beep(f, 0.12, "sine", 0.07), i * 90));
}
function playBuzz() {
  beep(120, 0.18, "sawtooth", 0.05);
}

function speak(text) {
  try {
    window.speechSynthesis?.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = "tr-TR";
    u.rate = 1.05;
    window.speechSynthesis?.speak(u);
  } catch (_) {}
}

function haptic(kind = "light") {
  try {
    if (navigator.vibrate) navigator.vibrate(kind === "medium" ? 30 : 12);
  } catch (_) {}
}

function rand(a, b) {
  return a + Math.random() * (b - a);
}
function pick(arr) {
  return arr[(Math.random() * arr.length) | 0];
}

function roundRectPath(x, y, w, h, r) {
  const rr = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + rr, y);
  ctx.arcTo(x + w, y, x + w, y + h, rr);
  ctx.arcTo(x + w, y + h, x, y + h, rr);
  ctx.arcTo(x, y + h, x, y, rr);
  ctx.arcTo(x, y, x + w, y, rr);
  ctx.closePath();
}

function showScreen(name) {
  ui.home.hidden = name !== "home";
  ui.how.hidden = name !== "how";
  ui.pause.hidden = name !== "pause";
  ui.result.hidden = name !== "result";
  ui.hud.hidden = name !== "play";
  ui.btnPause.hidden = name !== "play";
  if (name !== "play") ui.btnRestart.hidden = true;
  state.mode = name;
}

function showBanner(text) {
  ui.bannerText.textContent = text;
  ui.banner.hidden = false;
  clearTimeout(showBanner._t);
  showBanner._t = setTimeout(() => {
    ui.banner.hidden = true;
  }, 900);
}

function bumpScore() {
  if (!ui.scorePill) return;
  ui.scorePill.classList.remove("pop");
  void ui.scorePill.offsetWidth;
  ui.scorePill.classList.add("pop");
}

function updateHud() {
  const f = state.fill;
  ui.score.textContent = String(state.score);
  ui.level.textContent = String((f?.mapIndex ?? state.mapIndex) + 1);
  const pct = f ? Math.round((f.filled / f.emptyTotal) * 100) : 0;
  ui.fillPct.textContent = `${pct}%`;
}

function parseMap(rows) {
  const grid = [];
  let head = null;
  let empty = 0;
  for (let r = 0; r < rows.length; r++) {
    const line = [];
    for (let c = 0; c < rows[r].length; c++) {
      const ch = rows[r][c];
      if (ch === "#") line.push(0);
      else if (ch === "S") {
        line.push(3);
        head = { c, r };
        empty += 1;
      } else {
        line.push(1);
        empty += 1;
      }
    }
    grid.push(line);
  }
  return { grid, head, emptyTotal: empty };
}

function cloneGrid(grid) {
  return grid.map((row) => row.slice());
}

function simulateStretch(grid, head, dc, dr, rows, cols) {
  let c = head.c;
  let r = head.r;
  let steps = 0;
  while (true) {
    const nc = c + dc;
    const nr = r + dr;
    if (nr < 0 || nc < 0 || nr >= rows || nc >= cols || grid[nr][nc] !== 1) break;
    grid[r][c] = 2;
    grid[nr][nc] = 3;
    c = nc;
    r = nr;
    steps += 1;
  }
  return steps ? { head: { c, r }, steps } : null;
}

function solveOpening(mapRows) {
  const parsed = parseMap(mapRows);
  const rows = parsed.grid.length;
  const cols = parsed.grid[0].length;
  const dirs = [
    { dc: 0, dr: -1, name: "yukarı", label: "▲" },
    { dc: 0, dr: 1, name: "aşağı", label: "▼" },
    { dc: -1, dr: 0, name: "sola", label: "◀" },
    { dc: 1, dr: 0, name: "sağa", label: "▶" },
  ];
  function dfs(grid, head, filled) {
    if (filled >= parsed.emptyTotal) return [];
    const options = [];
    for (const d of dirs) {
      const g2 = cloneGrid(grid);
      const res = simulateStretch(g2, head, d.dc, d.dr, rows, cols);
      if (!res) continue;
      options.push({ ...d, grid: g2, head: res.head, filled: filled + res.steps, steps: res.steps });
    }
    options.sort((a, b) => b.steps - a.steps);
    for (const opt of options) {
      const rest = dfs(opt.grid, opt.head, opt.filled);
      if (rest) return [{ dc: opt.dc, dr: opt.dr, name: opt.name, label: opt.label }, ...rest];
    }
    return null;
  }
  return dfs(cloneGrid(parsed.grid), { ...parsed.head }, 1);
}

function canMove() {
  const f = state.fill;
  if (!f || f.won) return false;
  for (const [dc, dr] of [
    [0, -1],
    [0, 1],
    [-1, 0],
    [1, 0],
  ]) {
    const nc = f.head.c + dc;
    const nr = f.head.r + dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols) continue;
    if (f.grid[nr][nc] === 1) return true;
  }
  return false;
}

function cellCenter(c, r) {
  const f = state.fill;
  return {
    x: f.originX + c * f.cell + f.cell / 2,
    y: f.originY + r * f.cell + f.cell / 2,
  };
}

function burst(x, y, color, mega = false) {
  const n = mega ? 28 : 12;
  for (let i = 0; i < n; i++) {
    const a = (Math.PI * 2 * i) / n + rand(-0.2, 0.2);
    const sp = mega ? rand(120, 340) : rand(70, 180);
    state.particles.push({
      x,
      y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp,
      life: mega ? rand(0.5, 0.95) : rand(0.3, 0.65),
      age: 0,
      size: mega ? rand(5, 12) : rand(3, 8),
      color,
      kind: mega && Math.random() < 0.4 ? "star" : "dot",
    });
  }
  state.rings.push({
    x,
    y,
    r: 6,
    max: mega ? 140 : 60,
    life: mega ? 0.65 : 0.35,
    age: 0,
    color,
    width: mega ? 8 : 4,
  });
}

function floatText(x, y, text, color, opts = {}) {
  state.floatTexts.push({
    x,
    y,
    text,
    color,
    age: 0,
    life: opts.life || 1.2,
    size: opts.size || 28,
    rise: opts.rise || 60,
    pop: !!opts.pop,
  });
}

function popTip(text, color = "#fff7fb") {
  const f = state.fill;
  const x = state.width * 0.5 + rand(-20, 20);
  const y = f ? f.originY - 12 : state.height * 0.22;
  burst(x, y + 18, color, true);
  floatText(x, y, text, color, { size: 34, life: 1.4, rise: 70, pop: true });
  state.flash = Math.max(state.flash, 0.2);
}

function initMap() {
  const mapIndex = Math.min(state.mapIndex, MAPS.length - 1);
  const level = MAPS[mapIndex];
  const parsed = parseMap(level.rows);
  const rows = parsed.grid.length;
  const cols = parsed.grid[0].length;
  const pad = 14;
  const cell = Math.floor(Math.min((state.width - pad * 2) / cols, (state.height - 140) / rows) * 1.06);
  const boardW = cell * cols;
  const boardH = cell * rows;
  state.fill = {
    mapIndex,
    title: level.name,
    tips: level.tips,
    grid: parsed.grid.map((r) => r.slice()),
    head: { ...parsed.head },
    body: [{ ...parsed.head }],
    emptyTotal: parsed.emptyTotal,
    filled: 1,
    cols,
    rows,
    cell,
    originX: Math.floor((state.width - boardW) / 2),
    originY: Math.floor((state.height - boardH) / 2 + 24),
    won: false,
    needsRestart: false,
    pulse: 0,
    moveFlash: 0,
    hintFlash: 0,
    hintDir: null,
    lastDir: { dc: 1, dr: 0 },
    solution: solveOpening(level.rows),
  };
  state.fill.grid[parsed.head.r][parsed.head.c] = 3;
  state.particles = [];
  state.rings = [];
  state.floatTexts = [];
  ui.btnRestart.hidden = true;
  updateHud();
  showBanner(level.name);
  speak(level.name);
  setTimeout(() => {
    if (!state.fill || state.fill.mapIndex !== mapIndex) return;
    level.tips.forEach((tip, i) => {
      setTimeout(() => popTip(tip, i ? "#ffeaa7" : "#fff7fb"), i * 480);
    });
  }, 200);
  if (state.stuckCount > 0 && state.fill.solution?.[0]) {
    const first = state.fill.solution[0];
    state.fill.hintDir = { dc: first.dc, dr: first.dr, label: first.label };
    state.fill.hintFlash = 5;
    setTimeout(() => {
      popTip(`İpucu: önce ${first.name} ${first.label}`, "#ffeaa7");
      speak(`İpucu: önce ${first.name} kaydır`);
    }, 700);
  }
}

function offerStuckHint() {
  const f = state.fill;
  if (!f) return;
  state.stuckCount += 1;
  const first = f.solution?.[0];
  f.hintDir = first ? { dc: first.dc, dr: first.dr, label: first.label } : null;
  f.hintFlash = 4.5;
  popTip("Sıkıştın! Yol kapandı", "#ff7675");
  setTimeout(() => {
    if (first) popTip(`İpucu: önce ${first.name} ${first.label}`, "#ffeaa7");
    else popTip("Yeniden dene", "#74b9ff");
  }, 420);
  speak(first ? `Sıkıştın. İpucu: önce ${first.name} kaydır.` : "Sıkıştın. Yeniden dene.");
}

function tryMove(dc, dr) {
  const f = state.fill;
  if (!f || f.won || f.needsRestart || (!dc && !dr)) return;
  let { c, r } = f.head;
  const firstNc = c + dc;
  const firstNr = r + dr;
  if (firstNr < 0 || firstNc < 0 || firstNr >= f.rows || firstNc >= f.cols || f.grid[firstNr][firstNc] !== 1) {
    if (canMove()) {
      popTip("Bu yöne gidemezsin", "#ff7675");
      playBuzz();
      haptic("light");
      return;
    }
    f.needsRestart = true;
    ui.btnRestart.hidden = false;
    showBanner("SIKIŞTIN!");
    offerStuckHint();
    playBuzz();
    return;
  }

  let steps = 0;
  while (true) {
    const nc = c + dc;
    const nr = r + dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols || f.grid[nr][nc] !== 1) break;
    f.grid[r][c] = 2;
    f.grid[nr][nc] = 3;
    c = nc;
    r = nr;
    f.head = { c, r };
    f.body.push({ c, r });
    f.filled += 1;
    steps += 1;
    const p = cellCenter(c, r);
    burst(p.x, p.y, pick(["#ff8fab", "#ffeaa7", "#55efc4", "#74b9ff"]), steps === 1 || steps % 2 === 0);
  }

  state.facing = { dc, dr };
  f.lastDir = { dc, dr };
  const end = cellCenter(c, r);
  burst(end.x, end.y, "#fff7fb", true);
  f.moveFlash = 0.28;
  state.flash = Math.max(state.flash, steps >= 4 ? 0.32 : 0.16);
  playPop();
  haptic("medium");
  const gained = 8 * steps;
  state.score += gained;
  bumpScore();
  updateHud();
  popTip(`+${gained}`, "#ffeaa7");
  if (steps >= 3) setTimeout(() => popTip(`${steps} kare birden!`, "#55efc4"), 150);

  if (f.hintDir && f.hintDir.dc === dc && f.hintDir.dr === dr) {
    f.hintFlash = Math.max(0, f.hintFlash - 1.5);
  }

  if (f.filled >= f.emptyTotal) {
    f.won = true;
    f.needsRestart = false;
    ui.btnRestart.hidden = true;
    showBanner("DOLDU!");
    popTip("Tüm yol doldu!", "#55efc4");
    playCheer();
    speak("Harika! Tüm yol doldu.");
    state.score += 100;
    updateHud();
    setTimeout(() => {
      state.mapIndex = f.mapIndex + 1;
      state.stuckCount = 0;
      if (state.mapIndex < MAPS.length) {
        initMap();
      } else {
        finishRun();
      }
    }, 1100);
    return;
  }

  if (!canMove()) {
    f.needsRestart = true;
    ui.btnRestart.hidden = false;
    showBanner("SIKIŞTIN!");
    offerStuckHint();
    playBuzz();
  }
}

function startGame() {
  ensureAudio();
  state.score = 0;
  state.mapIndex = 0;
  state.stuckCount = 0;
  state.running = true;
  state.lastTs = performance.now();
  showScreen("play");
  initMap();
  speak("Longcat. Kaydır, uzat, tüm yolu doldur!");
}

function finishRun() {
  state.running = false;
  state.fill = null;
  ui.btnRestart.hidden = true;
  const isNew = state.score > state.best;
  if (isNew) {
    state.best = state.score;
    localStorage.setItem(STORAGE_KEY, String(state.best));
  }
  ui.finalScore.textContent = String(state.score);
  ui.bestHome.textContent = `En iyi: ${state.best}`;
  ui.resultTitle.textContent = state.score >= 500 ? "Süper Longcat!" : state.score >= 250 ? "Harika!" : "İyi iş!";
  ui.resultEmoji.textContent = state.score >= 500 ? "🏆" : "🐱";
  ui.resultBest.textContent = isNew ? "Yeni rekor kırdın!" : `En iyi skor: ${state.best}`;
  showScreen("result");
  playCheer();
  speak(isNew ? `Tebrikler! Yeni rekorun ${state.score}` : `Skorun ${state.score}`);
}

function resize() {
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  state.dpr = dpr;
  state.width = window.innerWidth;
  state.height = window.innerHeight;
  canvas.width = Math.floor(state.width * dpr);
  canvas.height = Math.floor(state.height * dpr);
  canvas.style.width = `${state.width}px`;
  canvas.style.height = `${state.height}px`;
  ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  if (state.mode === "play" && state.fill) initMap();
}

function drawCatHead(x, y, cell, facing, pulse) {
  const bob = Math.sin(pulse * 5) * 2;
  let angle = 0;
  if (facing.dc === 1) angle = Math.PI / 2;
  else if (facing.dc === -1) angle = -Math.PI / 2;
  else if (facing.dr === 1) angle = Math.PI;
  const s = cell * 0.55;

  const aura = ctx.createRadialGradient(x, y + bob, s * 0.2, x, y + bob, s * 2);
  aura.addColorStop(0, "rgba(255, 143, 171, 0.55)");
  aura.addColorStop(1, "rgba(255, 143, 171, 0)");
  ctx.fillStyle = aura;
  ctx.beginPath();
  ctx.arc(x, y + bob, s * 2, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.translate(x, y + bob);
  ctx.rotate(angle);

  // ears
  ctx.fillStyle = "#ff8fab";
  ctx.beginPath();
  ctx.moveTo(-s * 0.55, -s * 0.55);
  ctx.lineTo(-s * 0.15, -s * 1.05);
  ctx.lineTo(-s * 0.05, -s * 0.45);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(s * 0.55, -s * 0.55);
  ctx.lineTo(s * 0.15, -s * 1.05);
  ctx.lineTo(s * 0.05, -s * 0.45);
  ctx.closePath();
  ctx.fill();
  ctx.fillStyle = "#ffe3ec";
  ctx.beginPath();
  ctx.moveTo(-s * 0.42, -s * 0.55);
  ctx.lineTo(-s * 0.2, -s * 0.88);
  ctx.lineTo(-s * 0.12, -s * 0.5);
  ctx.closePath();
  ctx.fill();
  ctx.beginPath();
  ctx.moveTo(s * 0.42, -s * 0.55);
  ctx.lineTo(s * 0.2, -s * 1.05 + s * 0.17);
  ctx.lineTo(s * 0.12, -s * 0.5);
  ctx.closePath();
  ctx.fill();

  // head
  const body = ctx.createRadialGradient(-s * 0.2, -s * 0.25, 2, 0, 0, s);
  body.addColorStop(0, "#fff7fb");
  body.addColorStop(0.45, "#ffb3c6");
  body.addColorStop(1, "#ff8fab");
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.arc(0, 0, s * 0.92, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "rgba(232, 67, 147, 0.35)";
  ctx.lineWidth = Math.max(2, s * 0.08);
  ctx.stroke();

  // eyes
  ctx.fillStyle = "#2d3436";
  ctx.beginPath();
  ctx.ellipse(-s * 0.28, -s * 0.08, s * 0.12, s * 0.16, 0, 0, Math.PI * 2);
  ctx.ellipse(s * 0.28, -s * 0.08, s * 0.12, s * 0.16, 0, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.beginPath();
  ctx.arc(-s * 0.24, -s * 0.14, s * 0.045, 0, Math.PI * 2);
  ctx.arc(s * 0.32, -s * 0.14, s * 0.045, 0, Math.PI * 2);
  ctx.fill();

  // nose + smile
  ctx.fillStyle = "#e84393";
  ctx.beginPath();
  ctx.moveTo(0, s * 0.08);
  ctx.lineTo(-s * 0.08, s * 0.18);
  ctx.lineTo(s * 0.08, s * 0.18);
  ctx.closePath();
  ctx.fill();
  ctx.strokeStyle = "#2d3436";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(0, s * 0.22, s * 0.22, 0.15 * Math.PI, 0.85 * Math.PI);
  ctx.stroke();

  // whiskers
  ctx.strokeStyle = "rgba(45,52,54,0.35)";
  ctx.lineWidth = 1.5;
  for (const side of [-1, 1]) {
    ctx.beginPath();
    ctx.moveTo(side * s * 0.35, s * 0.12);
    ctx.lineTo(side * s * 0.95, s * 0.02);
    ctx.moveTo(side * s * 0.35, s * 0.2);
    ctx.lineTo(side * s * 0.95, s * 0.22);
    ctx.stroke();
  }

  ctx.restore();
}

function drawBodySeg(x, y, cell, i) {
  const pad = cell * 0.05;
  const rr = cell * 0.42;
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  roundRectPath(x + pad + 2, y + pad + 3, cell - pad * 2, cell - pad * 2, rr);
  ctx.fill();
  const g = ctx.createRadialGradient(x + cell * 0.35, y + cell * 0.3, 2, x + cell / 2, y + cell / 2, cell * 0.55);
  g.addColorStop(0, "#fff7fb");
  g.addColorStop(0.5, i % 2 ? "#ffb3c6" : "#ff8fab");
  g.addColorStop(1, "#e84393");
  ctx.fillStyle = g;
  roundRectPath(x + pad, y + pad, cell - pad * 2, cell - pad * 2, rr);
  ctx.fill();
  ctx.strokeStyle = "rgba(255,255,255,0.45)";
  ctx.lineWidth = Math.max(2, cell * 0.05);
  roundRectPath(x + pad, y + pad, cell - pad * 2, cell - pad * 2, rr);
  ctx.stroke();
  ctx.fillStyle = "rgba(255,255,255,0.55)";
  ctx.beginPath();
  ctx.ellipse(x + cell * 0.35, y + cell * 0.32, cell * 0.12, cell * 0.08, -0.4, 0, Math.PI * 2);
  ctx.fill();
}

function drawWorld() {
  const f = state.fill;
  // pastel Longcat sky
  const bg = ctx.createLinearGradient(0, 0, 0, state.height);
  bg.addColorStop(0, "#ffd6e7");
  bg.addColorStop(0.5, "#ffeaa7");
  bg.addColorStop(1, "#dfe6ff");
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, state.width, state.height);

  // floating blobs
  for (let i = 0; i < 7; i++) {
    const t = (f?.pulse || 0) * (0.25 + i * 0.04) + i;
    const x = ((i * 97 + Math.sin(t) * 20) % (state.width + 60)) - 30;
    const y = 40 + (i * 43) % (state.height * 0.4);
    ctx.globalAlpha = 0.28;
    ctx.fillStyle = pick(["#ff8fab", "#a29bfe", "#55efc4", "#74b9ff", "#fdcb6e"]);
    ctx.beginPath();
    ctx.ellipse(x, y + Math.sin(t * 1.3) * 8, 16 + (i % 3) * 5, 12 + (i % 2) * 4, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
  }

  if (!f) return;

  // board
  ctx.fillStyle = "rgba(255,255,255,0.4)";
  roundRectPath(f.originX - 16, f.originY - 16, f.cols * f.cell + 32, f.rows * f.cell + 32, 28);
  ctx.fill();
  ctx.fillStyle = "#fffdf8";
  roundRectPath(f.originX - 8, f.originY - 8, f.cols * f.cell + 16, f.rows * f.cell + 16, 20);
  ctx.fill();
  ctx.strokeStyle = "rgba(255, 143, 171, 0.55)";
  ctx.lineWidth = 4;
  roundRectPath(f.originX - 8, f.originY - 8, f.cols * f.cell + 16, f.rows * f.cell + 16, 20);
  ctx.stroke();

  for (let r = 0; r < f.rows; r++) {
    for (let c = 0; c < f.cols; c++) {
      const x = f.originX + c * f.cell;
      const y = f.originY + r * f.cell;
      const v = f.grid[r][c];
      if (v === 0) {
        const wall = ctx.createLinearGradient(x, y, x, y + f.cell);
        wall.addColorStop(0, "#fd79a8");
        wall.addColorStop(1, "#e84393");
        ctx.fillStyle = wall;
        roundRectPath(x + 4, y + 4, f.cell - 8, f.cell - 8, f.cell * 0.26);
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.3)";
        roundRectPath(x + 8, y + 8, f.cell - 18, f.cell * 0.22, 6);
        ctx.fill();
      } else if (v === 1) {
        ctx.fillStyle = "#f1f2f6";
        roundRectPath(x + 5, y + 5, f.cell - 10, f.cell - 10, f.cell * 0.3);
        ctx.fill();
        ctx.fillStyle = `rgba(255, 143, 171, ${0.18 + 0.1 * Math.sin(f.pulse * 3 + c + r)})`;
        roundRectPath(x + 10, y + 10, f.cell - 20, f.cell - 20, f.cell * 0.24);
        ctx.fill();
      } else {
        drawBodySeg(x, y, f.cell, c + r);
      }
    }
  }

  if (f.moveFlash > 0) {
    ctx.fillStyle = `rgba(255,255,255,${f.moveFlash * 0.35})`;
    roundRectPath(f.originX - 8, f.originY - 8, f.cols * f.cell + 16, f.rows * f.cell + 16, 18);
    ctx.fill();
  }

  // direction hints
  const dirs = [
    { dc: 0, dr: -1, label: "▲" },
    { dc: 0, dr: 1, label: "▼" },
    { dc: -1, dr: 0, label: "◀" },
    { dc: 1, dr: 0, label: "▶" },
  ];
  const pulse = 0.5 + 0.5 * Math.sin(f.pulse * 5);
  for (const d of dirs) {
    const nc = f.head.c + d.dc;
    const nr = f.head.r + d.dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols || f.grid[nr][nc] !== 1) continue;
    const p = cellCenter(nc, nr);
    const isHint = f.hintFlash > 0 && f.hintDir && f.hintDir.dc === d.dc && f.hintDir.dr === d.dr;
    const rad = f.cell * (isHint ? 0.46 : 0.36);
    const ring = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, rad);
    if (isHint) {
      ring.addColorStop(0, "rgba(255,255,255,0.95)");
      ring.addColorStop(0.5, `rgba(253, 203, 110, ${0.55 + pulse * 0.4})`);
      ring.addColorStop(1, "rgba(253,203,110,0)");
    } else {
      ring.addColorStop(0, "rgba(255,255,255,0.9)");
      ring.addColorStop(0.5, `rgba(116,185,255,${0.4 + pulse * 0.35})`);
      ring.addColorStop(1, "rgba(116,185,255,0)");
    }
    ctx.fillStyle = ring;
    ctx.beginPath();
    ctx.arc(p.x, p.y, rad, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = isHint ? "#d63031" : "#0984e3";
    ctx.font = `900 ${Math.floor(f.cell * (isHint ? 0.38 : 0.32))}px Fredoka, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(d.label, p.x, p.y + 1);
  }

  const hx = f.originX + f.head.c * f.cell + f.cell / 2;
  const hy = f.originY + f.head.r * f.cell + f.cell / 2;
  drawCatHead(hx, hy, f.cell, f.lastDir || state.facing, f.pulse);

  // title
  ctx.font = "900 20px Fredoka, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.lineWidth = 5;
  ctx.strokeStyle = "rgba(74,48,64,0.25)";
  ctx.fillStyle = "#fff7fb";
  const titleY = Math.max(58, f.originY - 34);
  ctx.strokeText(f.title, state.width * 0.5, titleY);
  ctx.fillText(f.title, state.width * 0.5, titleY);

  // progress bar
  const pct = Math.round((f.filled / f.emptyTotal) * 100);
  const barW = Math.min(220, state.width * 0.62);
  const barX = state.width * 0.5 - barW / 2;
  const barY = Math.min(state.height - 42, f.originY + f.rows * f.cell + 16);
  ctx.fillStyle = "rgba(74,48,64,0.4)";
  roundRectPath(barX, barY, barW, 22, 11);
  ctx.fill();
  const fillW = Math.max(10, (barW - 6) * (pct / 100));
  const barGrad = ctx.createLinearGradient(barX, 0, barX + barW, 0);
  barGrad.addColorStop(0, "#ff8fab");
  barGrad.addColorStop(1, "#a29bfe");
  ctx.fillStyle = barGrad;
  roundRectPath(barX + 3, barY + 3, fillW, 16, 8);
  ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.font = "800 13px Nunito, sans-serif";
  ctx.fillText(`%${pct}  ·  ${f.filled}/${f.emptyTotal}`, state.width * 0.5, barY + 11);
}

function drawFX() {
  for (const p of state.particles) {
    const t = p.age / p.life;
    ctx.globalAlpha = Math.max(0, 1 - t);
    ctx.fillStyle = p.color;
    if (p.kind === "star") {
      ctx.beginPath();
      for (let i = 0; i < 10; i++) {
        const r = i % 2 === 0 ? p.size : p.size * 0.45;
        const a = (Math.PI / 5) * i - Math.PI / 2;
        const px = p.x + Math.cos(a) * r;
        const py = p.y + Math.sin(a) * r;
        if (i === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fill();
    } else {
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.globalAlpha = 1;
  for (const ring of state.rings) {
    const t = ring.age / ring.life;
    ctx.globalAlpha = Math.max(0, 1 - t);
    ctx.strokeStyle = ring.color;
    ctx.lineWidth = Math.max(1, ring.width * (1 - t * 0.7));
    ctx.beginPath();
    ctx.arc(ring.x, ring.y, ring.r, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
  for (const t of state.floatTexts) {
    const p = t.age / t.life;
    const alpha = p < 0.12 ? p / 0.12 : Math.max(0, 1 - (p - 0.12) / 0.88);
    const scale = t.pop
      ? p < 0.18
        ? 0.2 + (p / 0.18) * 1.15
        : p < 0.35
          ? 1.35 - ((p - 0.18) / 0.17) * 0.25
          : 1.05
      : 1;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(t.x, t.y);
    ctx.scale(scale, scale);
    ctx.fillStyle = t.color;
    ctx.strokeStyle = "rgba(74,48,64,0.35)";
    ctx.lineWidth = 5;
    ctx.font = `900 ${t.size}px Fredoka, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.strokeText(t.text, 0, 0);
    ctx.fillText(t.text, 0, 0);
    ctx.restore();
  }
  ctx.globalAlpha = 1;
  if (state.flash > 0) {
    ctx.fillStyle = `rgba(255,247,251,${Math.min(0.45, state.flash)})`;
    ctx.fillRect(0, 0, state.width, state.height);
  }
}

function update(dt) {
  if (state.fill) {
    state.fill.pulse += dt;
    if (state.fill.moveFlash > 0) state.fill.moveFlash = Math.max(0, state.fill.moveFlash - dt);
    if (state.fill.hintFlash > 0) state.fill.hintFlash = Math.max(0, state.fill.hintFlash - dt);
  }
  if (state.flash > 0) state.flash = Math.max(0, state.flash - dt);
  for (const p of state.particles) {
    p.age += dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vy += 280 * dt;
  }
  state.particles = state.particles.filter((p) => p.age < p.life);
  for (const r of state.rings) {
    r.age += dt;
    r.r += (r.max - r.r) * Math.min(1, dt * 6);
  }
  state.rings = state.rings.filter((r) => r.age < r.life);
  for (const t of state.floatTexts) {
    t.age += dt;
    t.y -= t.rise * dt;
  }
  state.floatTexts = state.floatTexts.filter((t) => t.age < t.life);
}

function loop(ts) {
  const dt = Math.min(0.05, (ts - (state.lastTs || ts)) / 1000);
  state.lastTs = ts;
  if (state.mode === "play" && state.running) update(dt);
  else if (state.mode === "home") update(dt * 0.4);
  drawWorld();
  drawFX();
  requestAnimationFrame(loop);
}

function pointerPos(e) {
  const t = e.touches ? e.touches[0] || e.changedTouches?.[0] : e;
  return { x: t.clientX, y: t.clientY };
}

function onDown(e) {
  if (state.mode !== "play" || !state.running || !state.fill) return;
  e.preventDefault();
  const p = pointerPos(e);
  state.swipe = { x: p.x, y: p.y };
  // tap direction pads
  const f = state.fill;
  for (const d of [
    { dc: 0, dr: -1 },
    { dc: 0, dr: 1 },
    { dc: -1, dr: 0 },
    { dc: 1, dr: 0 },
  ]) {
    const nc = f.head.c + d.dc;
    const nr = f.head.r + d.dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols || f.grid[nr][nc] !== 1) continue;
    const c = cellCenter(nc, nr);
    if (Math.hypot(p.x - c.x, p.y - c.y) < f.cell * 0.5) {
      tryMove(d.dc, d.dr);
      state.swipe = null;
      return;
    }
  }
}

function onUp(e) {
  if (!state.swipe || state.mode !== "play" || !state.running) {
    state.swipe = null;
    return;
  }
  const p = pointerPos(e);
  const dx = p.x - state.swipe.x;
  const dy = p.y - state.swipe.y;
  state.swipe = null;
  if (Math.hypot(dx, dy) < 28) return;
  if (Math.abs(dx) > Math.abs(dy)) tryMove(dx > 0 ? 1 : -1, 0);
  else tryMove(0, dy > 0 ? 1 : -1);
}

function bindUi() {
  ui.bestHome.textContent = `En iyi: ${state.best}`;
  ui.btnPlay.addEventListener("click", () => startGame());
  ui.btnHow.addEventListener("click", () => showScreen("how"));
  ui.btnHowClose.addEventListener("click", () => showScreen("home"));
  ui.btnPause.addEventListener("click", () => {
    if (!state.running) return;
    state.running = false;
    showScreen("pause");
  });
  ui.btnResume.addEventListener("click", () => {
    state.running = true;
    state.lastTs = performance.now();
    showScreen("play");
  });
  ui.btnQuit.addEventListener("click", () => {
    state.running = false;
    state.fill = null;
    showScreen("home");
  });
  ui.btnAgain.addEventListener("click", () => startGame());
  ui.btnHome.addEventListener("click", () => showScreen("home"));
  ui.btnRestart.addEventListener("click", () => {
    if (state.mode !== "play") return;
    playPop();
    initMap();
    showBanner(state.stuckCount > 0 ? "İPUCU!" : "YENİDEN!");
  });
  canvas.addEventListener("pointerdown", onDown, { passive: false });
  canvas.addEventListener("touchstart", onDown, { passive: false });
  window.addEventListener("pointerup", onUp);
  window.addEventListener("touchend", onUp);
  window.addEventListener("resize", resize);
}

resize();
bindUi();
showScreen("home");
requestAnimationFrame(loop);
