const STORAGE_KEY = "balonPatlatBest";
const STORAGE_KEY_LONGCAR = "longcarBest";
const COLOR_STREAK_NEED = 3;
const BOOST_DURATION = 10; // hızlı müzik/boost modu (sn)
const BOOST_SCORE_MULT = 3;

const BALLOON_LEVELS = [
  {
    id: 1,
    name: "Seviye 1",
    time: 45,
    mode: "balloons",
    spawnBase: 0.85,
    speedMul: 1,
    label: "Isınma",
    desc: "Balonları patlat, renk kombo yap!",
  },
  {
    id: 2,
    name: "Seviye 2",
    time: 45,
    mode: "hop",
    label: "Tiles Hop",
    desc: "Işıklı karoya bas! Hızlanınca ☠'dan kaç!",
  },
  {
    id: 3,
    name: "Seviye 3",
    time: 55,
    mode: "drive",
    spawnBase: 0.42,
    speedMul: 1.2,
    label: "Tesla Yarışı",
    desc: "Tesla ile sağa sola git, balonları ez!",
  },
];

const LONGCAR_LEVELS = [
  {
    id: 1,
    name: "Longcar",
    time: 0,
    mode: "fill",
    label: "Tesla Model Y",
    desc: "Model Y’yi kaydır, Longcat gibi uzat, yolu doldur!",
  },
];

const LEVELS = BALLOON_LEVELS;

const HOP_TILE_COLORS = ["#ff6b6b", "#4ecdc4", "#5bb8f0", "#ffd166", "#f78fb3", "#6bcb77"];
const HOP_LANES = 3;

const QUIZZES = [
  {
    id: "odd-shape",
    afterLevel: 1,
    question: "Hangisi diğerlerinden farklı?",
    speak: "Hangisi diğerlerinden farklı? Üç yuvarlak ve bir kare var. Farklı olanı seç.",
    visual: `
      <div class="v-row">
        <div class="v-shape round" style="background:#ff6b6b"></div>
        <div class="v-shape round" style="background:#4ecdc4"></div>
        <div class="v-shape" style="background:#ffd166"></div>
        <div class="v-shape round" style="background:#5bb8f0"></div>
      </div>
    `,
    choices: [
      { text: "Sarı kare", correct: true, visual: `<div class="v-shape" style="background:#ffd166"></div>` },
      { text: "Kırmızı yuvarlak", correct: false, visual: `<div class="v-shape round" style="background:#ff6b6b"></div>` },
      { text: "Mavi yuvarlak", correct: false, visual: `<div class="v-shape round" style="background:#5bb8f0"></div>` },
    ],
  },
  {
    id: "pattern-color",
    afterLevel: 1,
    question: "Sıradaki renk hangisi?",
    speak: "Desene bak. Kırmızı, mavi, kırmızı, mavi. Sıradaki renk hangisi?",
    visual: `
      <div class="v-row">
        <div class="v-shape round" style="background:#ff6b6b"></div>
        <div class="v-shape round" style="background:#5bb8f0"></div>
        <div class="v-shape round" style="background:#ff6b6b"></div>
        <div class="v-shape round" style="background:#5bb8f0"></div>
        <span class="v-arrow">→</span>
        <div class="v-shape round" style="background:#d9e2ec;color:#1f3a4d">?</div>
      </div>
    `,
    choices: [
      { text: "Kırmızı", correct: true, visual: `<div class="v-shape round" style="background:#ff6b6b"></div>` },
      { text: "Yeşil", correct: false, visual: `<div class="v-shape round" style="background:#6bcb77"></div>` },
      { text: "Sarı", correct: false, visual: `<div class="v-shape round" style="background:#ffd166"></div>` },
    ],
  },
  {
    id: "count-stars",
    afterLevel: 2,
    question: "Kaç tane yıldız var?",
    speak: "Resme dikkatlice bak. Kaç tane yıldız var?",
    visual: `
      <div class="v-row">
        <div class="v-shape round" style="background:#ffd166">★</div>
        <div class="v-shape round" style="background:#ff6b6b">★</div>
        <div class="v-shape round" style="background:#4ecdc4">●</div>
        <div class="v-shape round" style="background:#ff9f68">★</div>
        <div class="v-shape round" style="background:#5bb8f0">★</div>
      </div>
    `,
    choices: [
      { text: "3", correct: false, visual: `<div class="choice-num">★★★</div>` },
      { text: "4", correct: true, visual: `<div class="choice-num">★★★★</div>` },
      { text: "5", correct: false, visual: `<div class="choice-num">★★★★★</div>` },
    ],
  },
  {
    id: "biggest",
    afterLevel: 2,
    question: "Hangisi en büyük?",
    speak: "Üç balona bak. Hangisi en büyük?",
    visual: `
      <div class="v-row">
        <div class="v-shape round small" style="background:#4ecdc4"></div>
        <div class="v-shape round big" style="background:#ff6b6b"></div>
        <div class="v-shape round" style="background:#ffd166"></div>
      </div>
    `,
    choices: [
      { text: "Kırmızı", correct: true, visual: `<div class="v-shape round big" style="background:#ff6b6b"></div>` },
      { text: "Yeşil", correct: false, visual: `<div class="v-shape round small" style="background:#4ecdc4"></div>` },
      { text: "Sarı", correct: false, visual: `<div class="v-shape round" style="background:#ffd166"></div>` },
    ],
  },
  {
    id: "count-circles",
    afterLevel: 3,
    question: "Kaç tane yuvarlak var?",
    speak: "Resme bak. Kaç tane yuvarlak balon var?",
    visual: `
      <div class="v-row">
        <div class="v-shape round" style="background:#ff6b6b"></div>
        <div class="v-shape" style="background:#ffd166"></div>
        <div class="v-shape round" style="background:#4ecdc4"></div>
        <div class="v-shape round" style="background:#5bb8f0"></div>
      </div>
    `,
    choices: [
      { text: "2", correct: false, visual: `<div class="choice-num">●●</div>` },
      { text: "3", correct: true, visual: `<div class="choice-num">●●●</div>` },
      { text: "4", correct: false, visual: `<div class="choice-num">●●●●</div>` },
    ],
  },
  {
    id: "odd-color",
    afterLevel: 3,
    question: "Hangisi farklı renk?",
    speak: "Üç şekilden hangisi farklı renkte?",
    visual: `
      <div class="v-row">
        <div class="v-shape round" style="background:#ff6b6b"></div>
        <div class="v-shape round" style="background:#ff6b6b"></div>
        <div class="v-shape round" style="background:#5bb8f0"></div>
      </div>
    `,
    choices: [
      { text: "Mavi", correct: true, visual: `<div class="v-shape round" style="background:#5bb8f0"></div>` },
      { text: "Kırmızı sol", correct: false, visual: `<div class="v-shape round" style="background:#ff6b6b"></div>` },
      { text: "Kırmızı sağ", correct: false, visual: `<div class="v-shape round" style="background:#ff6b6b"></div>` },
    ],
  },
];

const COLORS = [
  { fill: "#ff6b6b", stroke: "#e84e4e", points: 10, name: "kırmızı" },
  { fill: "#4ecdc4", stroke: "#2fb3aa", points: 10, name: "mint" },
  { fill: "#ffd166", stroke: "#e0b340", points: 15, gold: true, name: "altın" },
  { fill: "#ff9f68", stroke: "#ef7f42", points: 10, name: "turuncu" },
  { fill: "#6bcb77", stroke: "#4eae5b", points: 10, name: "yeşil" },
  { fill: "#5bb8f0", stroke: "#3a9ad4", points: 12, name: "mavi" },
  { fill: "#f78fb3", stroke: "#e06d97", points: 12, name: "pembe" },
  { fill: "#2d3436", stroke: "#111111", points: -25, skull: true, name: "kurukafa" },
];

const $ = (id) => document.getElementById(id);

const ui = {
  home: $("home"),
  how: $("how"),
  pause: $("pause"),
  quiz: $("quiz"),
  levelIntro: $("levelIntro"),
  result: $("result"),
  hud: $("hud"),
  score: $("score"),
  time: $("time"),
  level: $("level"),
  combo: $("combo"),
  comboWrap: $("comboWrap"),
  streak: $("streak"),
  streakWrap: $("streakWrap"),
  boostWrap: $("boostWrap"),
  boostTime: $("boostTime"),
  boostOverlay: $("boostOverlay"),
  btnPlay: $("btnPlay"),
  btnLongcar: $("btnLongcar"),
  btnHow: $("btnHow"),
  btnHowClose: $("btnHowClose"),
  btnPause: $("btnPause"),
  btnFillRestart: $("btnFillRestart"),
  btnResume: $("btnResume"),
  btnQuit: $("btnQuit"),
  btnAgain: $("btnAgain"),
  btnHome: $("btnHome"),
  btnSpeak: $("btnSpeak"),
  btnStartLevel: $("btnStartLevel"),
  bestHome: $("bestHome"),
  finalScore: $("finalScore"),
  resultBest: $("resultBest"),
  resultTitle: $("resultTitle"),
  resultEmoji: $("resultEmoji"),
  bonusBanner: $("bonusBanner"),
  bannerText: $("bannerText"),
  quizStage: $("quizStage"),
  quizTitle: $("quizTitle"),
  quizQuestion: $("quizQuestion"),
  quizVisual: $("quizVisual"),
  quizChoices: $("quizChoices"),
  quizFeedback: $("quizFeedback"),
  introEyebrow: $("introEyebrow"),
  introTitle: $("introTitle"),
  introText: $("introText"),
  app: $("app"),
  scorePill: document.querySelector(".score-pill"),
};

const canvas = $("sky");
const ctx = canvas.getContext("2d");

const state = {
  mode: "home",
  pack: "balloon", // balloon | longcar
  running: false,
  width: 0,
  height: 0,
  dpr: 1,
  balloons: [],
  particles: [],
  rings: [],
  floatTexts: [],
  score: 0,
  combo: 0,
  comboTimer: 0,
  colorStreak: 0,
  lastColor: null,
  streakColor: null,
  boostLeft: 0,
  timeLeft: 45,
  levelIndex: 0,
  pendingLevelIndex: 1,
  currentQuiz: null,
  usedQuizIds: [],
  spawnTimer: 0,
  lastTs: 0,
  best: Number(localStorage.getItem(STORAGE_KEY) || 0),
  bestLongcar: Number(localStorage.getItem(STORAGE_KEY_LONGCAR) || 0),
  hillsOffset: 0,
  flash: 0,
  bonusTimer: 0,
  beatT: 0,
  hop: null,
  drive: null,
  fill: null,
  fillMapIndex: 0,
  fillStuckCount: 0,
  fillTipTimer: null,
  swipe: null,
  fillFacing: { dc: 1, dr: 0 },
};

let audioCtx = null;
let boostMusicTimer = null;

function activeLevels() {
  return state.pack === "longcar" ? LONGCAR_LEVELS : BALLOON_LEVELS;
}

function currentLevel() {
  const levels = activeLevels();
  return levels[state.levelIndex] || levels[0];
}

function isLongcarPack() {
  return state.pack === "longcar";
}

function updateHomeBest() {
  if (!ui.bestHome) return;
  ui.bestHome.textContent = `Balon en iyi: ${state.best} · Longcar: ${state.bestLongcar}`;
}

function speak(text) {
  if (!window.speechSynthesis) return;
  window.speechSynthesis.cancel();
  const utter = new SpeechSynthesisUtterance(text);
  utter.lang = "tr-TR";
  utter.rate = 0.92;
  utter.pitch = 1.08;
  const voices = window.speechSynthesis.getVoices();
  const tr = voices.find((v) => v.lang?.startsWith("tr"));
  if (tr) utter.voice = tr;
  window.speechSynthesis.speak(utter);
}

function stopSpeak() {
  if (window.speechSynthesis) window.speechSynthesis.cancel();
}

function pickQuiz(afterLevel) {
  const pool = QUIZZES.filter((q) => q.afterLevel === afterLevel && !state.usedQuizIds.includes(q.id));
  const list = pool.length ? pool : QUIZZES.filter((q) => q.afterLevel === afterLevel);
  return pick(list);
}



function isHopMode() {
  return currentLevel().mode === "hop";
}

function isDriveMode() {
  return currentLevel().mode === "drive";
}


function isFillMode() {
  return currentLevel().mode === "fill";
}

const FILL_LEVELS = [
  {
    id: "bahce",
    name: "Balon Bahçesi",
    tips: ["Model Y’yi kaydır!", "Tek yönde duvara kadar uzar", "Şarj istasyonuna ulaş!"],
    stuckHints: ["Kenarlardan dolaş", "Şarjı sona bırak", "Uzun kenarı önce doldur"],
    facts: ["Tesla Model Y elektrikli bir SUV’dur", "Şarj olunca enerji dolar ⚡", "Longcar gibi uzayarak yolu boya"],
    theme: {
      sky: ["#ffeaa7", "#fd79a8", "#a29bfe"],
      wall: ["#fd79a8", "#e84393"],
      empty: ["#f1f2f6", "#fab1a0"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#fd79a8",
      decor: "balloons",
    },
    rows: [
      "#######",
      "#S....#",
      "#.....#",
      "#.C...#",
      "#.....#",
      "#######",
    ],
  },
  {
    id: "kopru",
    name: "Gökkuşağı Köprü",
    tips: ["Köprüden geç!", "Dar geçitte planlı ol", "Sonda şarj var"],
    stuckHints: ["Zikzak koridoru takip et", "Önce sağa git", "Şarja erken varma"],
    facts: ["Gökkuşağında 7 renk vardır", "Elektrik de bir enerjidir", "Model Y sessiz gider"],
    theme: {
      sky: ["#a29bfe", "#81ecec", "#ffeaa7"],
      wall: ["#a29bfe", "#6c5ce7"],
      empty: ["#f1f2f6", "#a29bfe"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#a29bfe",
      decor: "rainbow",
    },
    rows: [
      "########",
      "#S.....#",
      "######.#",
      "#......#",
      "#.######",
      "#.....C#",
      "########",
    ],
  },
  {
    id: "yildiz",
    name: "Yıldız Labirent",
    tips: ["Zikzak yolu boya!", "Sağa uzun atış yap", "Şarj istasyonu sonda"],
    stuckHints: ["Koridoru sırayla doldur", "Sağa kaydırarak başla", "Şarja doğru ilerle"],
    facts: ["Yıldızlar ateş toplarıdır", "Güneş bir yıldızdır", "Gece yolculuğu eğlenceli"],
    theme: {
      sky: ["#dfe6e9", "#a29bfe", "#74b9ff"],
      wall: ["#636e72", "#2d3436"],
      empty: ["#f1f2f6", "#74b9ff"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#74b9ff",
      decor: "stars",
    },
    rows: [
      "#########",
      "#S......#",
      "#######.#",
      "#.......#",
      "#.#######",
      "#.......#",
      "#######.#",
      "#C......#",
      "#########",
    ],
  },
  {
    id: "spiral",
    name: "Şeker Spiral",
    tips: ["Zikzak şeker yolunu boya!", "Tek kaydırmada uzat", "Şarj istasyonuna var"],
    stuckHints: ["Sağa uzun atış", "Aşağı-sol ritmini bozma", "Şarj solda sonda"],
    facts: ["Spiral doğada çoktur", "Salyangoz kabuğu spiraldir", "Şarj istasyonu enerji verir"],
    theme: {
      sky: ["#55efc4", "#81ecec", "#ffeaa7"],
      wall: ["#00cec9", "#00b894"],
      empty: ["#f1f2f6", "#55efc4"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#00b894",
      decor: "candy",
    },
    rows: [
      "#######",
      "#S....#",
      "#####.#",
      "#.....#",
      "#.#####",
      "#.....#",
      "#####.#",
      "#C....#",
      "#######",
    ],
  },
  {
    id: "garaj",
    name: "Süper Garaj",
    tips: ["Garaj koridorunu doldur!", "Tek kaydırmada uzat", "Şarj ünitesine gir"],
    stuckHints: ["Sağa uzun atış", "Aşağı in, sola dön", "Şarj köşede bekliyor"],
    facts: ["Garajda araba dinlenir", "Model Y eve şarj olur", "⚡ ile enerji dolar"],
    theme: {
      sky: ["#74b9ff", "#81ecec", "#ffeaa7"],
      wall: ["#0984e3", "#0652dd"],
      empty: ["#f1f2f6", "#74b9ff"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#0984e3",
      decor: "balloons",
    },
    rows: [
      "########",
      "#S.....#",
      "######.#",
      "#......#",
      "#.######",
      "#.....C#",
      "########",
    ],
  },
  {
    id: "otoyol",
    name: "Şehir Otoyolu",
    tips: ["Uzun otoyolu boya!", "Zikzak şeritleri takip et", "Şarj istasyonuna var"],
    stuckHints: ["Önce sağa git", "Şerit değiştirme sırasını bozma", "Şarj solda sonda"],
    facts: ["Otoyollar uzun yollardır", "Elektrikli araçlar şehirde temiz", "Şarj ağı her yere yayılır"],
    theme: {
      sky: ["#fd79a8", "#a29bfe", "#74b9ff"],
      wall: ["#e17055", "#d63031"],
      empty: ["#f1f2f6", "#fd79a8"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#e17055",
      decor: "rainbow",
    },
    rows: [
      "##########",
      "#S.......#",
      "########.#",
      "#........#",
      "#.########",
      "#........#",
      "########.#",
      "#C.......#",
      "##########",
    ],
  },
  {
    id: "liman",
    name: "Deniz Limanı",
    tips: ["Liman yolunu tamamla!", "Kıvrımları takip et", "İskelede şarj var"],
    stuckHints: ["Sağa uzun git", "Aşağı-sol-aşağı ritmini bozma", "Şarj iskelede"],
    facts: ["Limanlar gemiler içindir", "Elektrik denizi kirletmez", "Model Y maceraya hazır"],
    theme: {
      sky: ["#81ecec", "#74b9ff", "#ffeaa7"],
      wall: ["#00cec9", "#0984e3"],
      empty: ["#f1f2f6", "#81ecec"],
      fill: ["#ffffff", "#f5f6fa", "#dfe6e9"],
      head: ["#ffffff", "#dfe6e9", "#636e72"],
      accent: "#00cec9",
      decor: "candy",
    },
    rows: [
      "#########",
      "#S......#",
      "#######.#",
      "#.......#",
      "#.#######",
      "#......C#",
      "#########",
    ],
  },
];

const FILL_MAPS = FILL_LEVELS; // geriye uyumluluk

function getFillLevel(mapIndex) {
  return FILL_LEVELS[Math.min(mapIndex || 0, FILL_LEVELS.length - 1)];
}

function parseFillMap(rows) {
  const grid = [];
  let head = null;
  let charge = null;
  let empty = 0;
  for (let r = 0; r < rows.length; r++) {
    const line = [];
    for (let c = 0; c < rows[r].length; c++) {
      const ch = rows[r][c];
      if (ch === "#") line.push(0);
      else if (ch === "S") {
        line.push(3); // head
        head = { c, r };
        empty += 1;
      } else if (ch === "C") {
        line.push(1); // empty + charge station
        charge = { c, r };
        empty += 1;
      } else {
        line.push(1); // empty
        empty += 1;
      }
    }
    grid.push(line);
  }
  // şarj yoksa çözüm sonuna yakın sağ-alt boşluğu hedef say
  if (!charge && head) {
    for (let r = grid.length - 1; r >= 0 && !charge; r--) {
      for (let c = grid[0].length - 1; c >= 0; c--) {
        if (grid[r][c] === 1) {
          charge = { c, r };
          break;
        }
      }
    }
  }
  return { grid, head, charge, emptyTotal: empty };
}

function canFillMove() {
  const f = state.fill;
  if (!f || f.won) return false;
  const dirs = [
    [0, -1],
    [0, 1],
    [-1, 0],
    [1, 0],
  ];
  for (const [dc, dr] of dirs) {
    const nc = f.head.c + dc;
    const nr = f.head.r + dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols) continue;
    if (f.grid[nr][nc] === 1) return true;
  }
  return false;
}

function cloneFillGrid(grid) {
  return grid.map((row) => row.slice());
}

function simulateFillLine(grid, head, dc, dr, rows, cols) {
  let c = head.c;
  let r = head.r;
  let steps = 0;
  while (true) {
    const nc = c + dc;
    const nr = r + dr;
    if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) break;
    if (grid[nr][nc] !== 1) break;
    grid[r][c] = 2;
    grid[nr][nc] = 3;
    c = nc;
    r = nr;
    steps += 1;
  }
  if (!steps) return null;
  return { head: { c, r }, steps };
}

function countFillExits(grid, head, rows, cols) {
  let n = 0;
  const dirs = [
    [0, -1],
    [0, 1],
    [-1, 0],
    [1, 0],
  ];
  for (const [dc, dr] of dirs) {
    const nc = head.c + dc;
    const nr = head.r + dr;
    if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;
    if (grid[nr][nc] === 1) n += 1;
  }
  return n;
}

function solveFillPath(mapRows) {
  const parsed = parseFillMap(mapRows);
  const rows = parsed.grid.length;
  const cols = parsed.grid[0].length;
  const emptyTotal = parsed.emptyTotal;
  const dirs = [
    { dc: 0, dr: -1, name: "yukarı", label: "▲" },
    { dc: 0, dr: 1, name: "aşağı", label: "▼" },
    { dc: -1, dr: 0, name: "sola", label: "◀" },
    { dc: 1, dr: 0, name: "sağa", label: "▶" },
  ];

  function dfs(grid, head, filled) {
    if (filled >= emptyTotal) return [];
    const options = [];
    for (const d of dirs) {
      const g2 = cloneFillGrid(grid);
      const res = simulateFillLine(g2, head, d.dc, d.dr, rows, cols);
      if (!res) continue;
      const exits = countFillExits(g2, res.head, rows, cols);
      if (filled + res.steps < emptyTotal && exits === 0) continue;
      options.push({
        ...d,
        grid: g2,
        head: res.head,
        filled: filled + res.steps,
        steps: res.steps,
        exits,
      });
    }
    // uzun atışları önce dene (Longcar hissi)
    options.sort((a, b) => b.steps - a.steps || a.exits - b.exits);
    for (const opt of options) {
      const rest = dfs(opt.grid, opt.head, opt.filled);
      if (rest) {
        return [{ dc: opt.dc, dr: opt.dr, name: opt.name, label: opt.label }, ...rest];
      }
    }
    return null;
  }

  return dfs(cloneFillGrid(parsed.grid), { ...parsed.head }, 1);
}

function dirHintText(step) {
  if (!step) return "İpucu: yolu yeniden planla";
  return `İpucu: önce ${step.name} kaydır ${step.label}`;
}

function offerStuckHint(reason = "stuck") {
  const f = state.fill;
  if (!f) return;
  const level = getFillLevel(f.mapIndex);
  if (!f.solution) {
    f.solution = solveFillPath(level.rows);
  }
  f.stuckCount = (f.stuckCount || 0) + 1;
  state.fillStuckCount = f.stuckCount;
  const sol = f.solution || [];
  const first = sol[0];
  const second = sol[1];

  f.hintDir = first ? { dc: first.dc, dr: first.dr, label: first.label } : null;
  f.hintFlash = 4.5;

  const tips = [];
  if (reason === "wrong") {
    tips.push("Yanlış yön — duvara gittin");
  } else {
    tips.push("Sıkıştın! Yol kapandı");
  }
  tips.push(dirHintText(first));
  if (f.stuckCount >= 2 && second) {
    tips.push(`Sonra ${second.name} git ${second.label}`);
  } else if (level.stuckHints && level.stuckHints.length) {
    tips.push(level.stuckHints[(f.stuckCount - 1) % level.stuckHints.length]);
  } else {
    tips.push("Yeniden dene, ipucunu takip et");
  }

  const colors = ["#ff7675", "#ffeaa7", "#74b9ff"];
  tips.forEach((tip, i) => {
    setTimeout(() => {
      if (!state.fill) return;
      popFillTip(tip, colors[i % colors.length], { mega: i < 2, life: 1.65, yOff: i * 8 });
    }, i * 420);
  });

  const speakText = first
    ? reason === "wrong"
      ? `Yanlış yön. İpucu: önce ${first.name} kaydır.`
      : `Sıkıştın. İpucu: önce ${first.name} kaydır. Yeniden dene.`
    : "Sıkıştın. Yeniden dene.";
  speak(speakText);
}

function setFillRestartVisible(show) {
  if (!ui.btnFillRestart) return;
  ui.btnFillRestart.hidden = !show;
}

function initFillMode() {
  state.hop = null;
  state.drive = null;
  state.balloons = [];
  const mapIndex = Math.min(state.fillMapIndex || 0, FILL_LEVELS.length - 1);
  const level = getFillLevel(mapIndex);
  const parsed = parseFillMap(level.rows);
  const rows = parsed.grid.length;
  const cols = parsed.grid[0].length;
  const pad = 12;
  const cell = Math.floor(
    Math.min((state.width - pad * 2) / cols, (state.height - 130) / rows) * 1.08
  );
  const boardW = cell * cols;
  const boardH = cell * rows;
  if (state.fillTipTimer) {
    clearTimeout(state.fillTipTimer);
    state.fillTipTimer = null;
  }
  state.fill = {
    mapIndex,
    levelId: level.id,
    title: level.name,
    theme: level.theme,
    facts: level.facts.slice(),
    tips: level.tips.slice(),
    grid: parsed.grid.map((row) => row.slice()),
    head: { ...parsed.head },
    body: [{ ...parsed.head }],
    emptyTotal: parsed.emptyTotal,
    filled: 1,
    charge: parsed.charge ? { ...parsed.charge } : null,
    cols,
    rows,
    cell,
    originX: Math.floor((state.width - boardW) / 2),
    originY: Math.floor((state.height - boardH) / 2 + 28),
    won: false,
    moveFlash: 0,
    hintPulse: 0,
    needsRestart: false,
    tipCooldown: 0,
    factIndex: 0,
    stuckCount: state.fillStuckCount || 0,
    lastDir: { dc: 1, dr: 0 },
    solution: solveFillPath(level.rows),
    hintDir: null,
    hintFlash: 0,
    sparkles: Array.from({ length: 18 }, (_, i) => ({
      x: Math.random(),
      y: Math.random(),
      s: 0.4 + Math.random() * 0.8,
      sp: 0.2 + Math.random() * 0.6,
      phase: Math.random() * Math.PI * 2,
    })),
  };
  state.fill.grid[parsed.head.r][parsed.head.c] = 3;
  setFillRestartVisible(false);
  state.floatTexts = [];
  state.particles = [];
  state.rings = [];
  showBanner(level.name, "combo");
  speak(level.name);
  // önceki sıkışmadan gelen ipucu varsa hemen göster
  if (state.fillStuckCount > 0 && state.fill.solution && state.fill.solution[0]) {
    const first = state.fill.solution[0];
    state.fill.hintDir = { dc: first.dc, dr: first.dr, label: first.label };
    state.fill.hintFlash = 5;
    setTimeout(() => {
      if (!state.fill || state.fill.mapIndex !== mapIndex) return;
      popFillTip(dirHintText(first), "#ffeaa7", { mega: true, life: 1.8 });
      speak(`İpucu: önce ${first.name} kaydır`);
    }, 700);
  }
  setTimeout(() => {
    if (!state.fill || state.fill.mapIndex !== mapIndex) return;
    const tips = [
      level.name,
      ...level.tips.slice(0, 2),
      `Harita ${mapIndex + 1} / ${FILL_LEVELS.length}`,
    ];
    const colors = ["#ffeaa7", "#fff8ef", "#74b9ff", "#55efc4"];
    tips.forEach((tip, i) => {
      setTimeout(() => popFillTip(tip, colors[i % colors.length], { mega: i === 0 }), i * 520);
    });
    scheduleFillFactBurst();
  }, 180);
}

function scheduleFillFactBurst() {
  const f = state.fill;
  if (!f || f.won || f.needsRestart) return;
  if (state.fillTipTimer) clearTimeout(state.fillTipTimer);
  state.fillTipTimer = setTimeout(() => {
    if (!state.fill || state.fill.won || state.fill.needsRestart) return;
    const facts = state.fill.facts || [];
    if (!facts.length) return;
    const fact = facts[state.fill.factIndex % facts.length];
    state.fill.factIndex += 1;
    popFillTip(fact, "#fff8ef", { mega: true, life: 1.7 });
    speak(fact);
    scheduleFillFactBurst();
  }, 5200 + Math.random() * 1800);
}

function fillCellCenter(c, r) {
  const f = state.fill;
  return {
    x: f.originX + c * f.cell + f.cell / 2,
    y: f.originY + r * f.cell + f.cell / 2,
  };
}

function tryFillMove(dc, dr) {
  const f = state.fill;
  if (!f || f.won || f.needsRestart || (!dc && !dr)) return;
  let { c, r } = f.head;
  const firstNc = c + dc;
  const firstNr = r + dr;
  if (firstNr < 0 || firstNc < 0 || firstNr >= f.rows || firstNc >= f.cols || f.grid[firstNr][firstNc] !== 1) {
    if (canFillMove()) {
      popFillTip("Bu yöne gidemezsin", "#ff7675");
      playSkullBuzz();
      haptic("light");
      return;
    }
    f.needsRestart = true;
    setFillRestartVisible(true);
    showBanner("SIKIŞTIN!", "boost");
    offerStuckHint("stuck");
    playSkullBuzz();
    haptic("light");
    return;
  }

  // Longcar: tek kaydırmada duvara/doluya kadar uzar
  let steps = 0;
  const neon = (f.theme && f.theme.accent) || "#00cec9";
  while (true) {
    const nc = c + dc;
    const nr = r + dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols) break;
    if (f.grid[nr][nc] !== 1) break;
    f.grid[r][c] = 2;
    f.grid[nr][nc] = 3;
    c = nc;
    r = nr;
    f.head = { c, r };
    f.body.push({ c, r });
    f.filled += 1;
    steps += 1;
    const p = fillCellCenter(c, r);
    burst(p.x, p.y, neon, steps === 1 || steps % 2 === 0);
    if (steps % 2 === 0) {
      state.rings.push({
        x: p.x,
        y: p.y,
        r: 6,
        max: f.cell * 1.2,
        life: 0.4,
        age: 0,
        color: neon,
        width: 5,
      });
    }
  }

  state.fillFacing = { dc, dr };
  f.lastDir = { dc, dr };
  const end = fillCellCenter(c, r);
  burst(end.x, end.y, "#ffeaa7", true);
  burst(end.x, end.y, "#74b9ff", steps >= 3);
  state.rings.push({
    x: end.x,
    y: end.y,
    r: 10,
    max: f.cell * (1.4 + Math.min(2, steps * 0.2)),
    life: 0.55,
    age: 0,
    color: "#ffffff",
    width: 4,
  });
  state.flash = Math.max(state.flash, steps >= 4 ? 0.35 : 0.2);

  f.moveFlash = 0.32;
  playHopMelody();
  playPop(1.05 + Math.min(0.35, steps * 0.05));
  haptic("medium");
  const gained = 8 * steps;
  state.score += gained;
  bumpScore();
  updateHud();
  const progress = Math.round((f.filled / f.emptyTotal) * 100);
  popFillTip(`+${gained} ⚡`, "#ffeaa7", { size: 32, mega: true });
  if (steps >= 3) {
    setTimeout(() => popFillTip(`${steps} kare birden!`, "#55efc4", { mega: true }), 160);
  }

  if (f.hintDir && f.hintDir.dc === dc && f.hintDir.dr === dr) {
    f.hintFlash = Math.max(0, f.hintFlash - 1.5);
  }

  if (f.filled >= f.emptyTotal) {
    f.won = true;
    f.needsRestart = false;
    setFillRestartVisible(false);
    if (state.fillTipTimer) {
      clearTimeout(state.fillTipTimer);
      state.fillTipTimer = null;
    }
    showBanner("ŞARJ!", "combo");
    for (let i = 0; i < 5; i++) {
      setTimeout(() => {
        burst(state.width * (0.2 + i * 0.15), state.height * 0.35, pick(["#00cec9", "#74b9ff", "#ffeaa7", "#fd79a8"]), true);
      }, i * 90);
    }
    const onCharge =
      f.charge && f.head.c === f.charge.c && f.head.r === f.charge.r;
    if (onCharge) {
      popFillTip("Şarj istasyonu! ⚡", "#55efc4", { mega: true, life: 1.8 });
      setTimeout(() => popFillTip("Batarya doldu!", "#ffeaa7", { mega: true }), 280);
      speak("Harika! Şarj istasyonuna ulaştın. Batarya doldu.");
      state.score += 160;
    } else {
      popFillTip("Tüm yol doldu!", "#55efc4", { mega: true, life: 1.7 });
      setTimeout(() => popFillTip(`${f.title} · süper!`, "#ffeaa7", { mega: true }), 320);
      speak("Harika! Tüm yol doldu.");
      state.score += 120;
    }
    playCheer();
    state.flash = Math.max(state.flash, 0.55);
    updateHud();
    setTimeout(() => {
      state.fillMapIndex = f.mapIndex + 1;
      state.fillStuckCount = 0;
      if (state.fillMapIndex < FILL_LEVELS.length) {
        const next = getFillLevel(state.fillMapIndex);
        showBanner(next.name, "boost");
        initFillMode();
        speak(next.name);
      } else {
        state.fillMapIndex = 0;
        completeLevel();
      }
    }, 1200);
    return;
  }

  if (!canFillMove()) {
    f.needsRestart = true;
    setFillRestartVisible(true);
    showBanner("SIKIŞTIN!", "boost");
    offerStuckHint("stuck");
    playSkullBuzz();
    haptic("medium");
  } else if (progress === 25) {
    popFillTip("Güzel sürüş!", "#74b9ff", { mega: true });
  } else if (progress === 50) {
    popFillTip("Yarı şarj!", "#74b9ff", { mega: true });
  } else if (progress === 75) {
    popFillTip("Neredeyse dolu!", "#55efc4", { mega: true });
  } else if (progress >= 90) {
    popFillTip("Son viraj!", "#ffeaa7", { mega: true });
  }
}

function updateFill(dt) {
  const f = state.fill;
  if (!f) return;
  f.hintPulse += dt;
  if (f.moveFlash > 0) f.moveFlash = Math.max(0, f.moveFlash - dt);
  if (f.hintFlash > 0) f.hintFlash = Math.max(0, f.hintFlash - dt);
  // sonsuz süre — süre göstergesini gizle/dondur
  state.timeLeft = 0;
  updateHud();
}

function drawFillWorld() {
  const f = state.fill;
  if (!f) return;
  const theme = f.theme || {
    sky: ["#a29bfe", "#74b9ff", "#ffeaa7"],
    wall: ["#e17055", "#d63031"],
    empty: ["#dfe6e9", "#74b9ff"],
    fill: ["#fff5c8", "#ffd166", "#e17055"],
    head: ["#ffffff", "#ff7675", "#d63031"],
    accent: "#0984e3",
    decor: "balloons",
  };

  // Unique themed sky per map
  const bg = ctx.createLinearGradient(0, 0, 0, state.height);
  bg.addColorStop(0, theme.sky[0]);
  bg.addColorStop(0.5, theme.sky[1] || theme.sky[0]);
  bg.addColorStop(1, theme.sky[2] || theme.sky[1] || theme.sky[0]);
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, state.width, state.height);

  // soft vignette
  const vig = ctx.createRadialGradient(
    state.width * 0.5,
    state.height * 0.45,
    Math.min(state.width, state.height) * 0.2,
    state.width * 0.5,
    state.height * 0.5,
    Math.max(state.width, state.height) * 0.75
  );
  vig.addColorStop(0, "rgba(255,255,255,0)");
  vig.addColorStop(1, "rgba(20,20,40,0.18)");
  ctx.fillStyle = vig;
  ctx.fillRect(0, 0, state.width, state.height);

  drawFillDecor(f, theme);

  // board outer glow
  const glow = ctx.createRadialGradient(
    state.width * 0.5,
    f.originY + (f.rows * f.cell) / 2,
    20,
    state.width * 0.5,
    f.originY + (f.rows * f.cell) / 2,
    Math.max(f.cols, f.rows) * f.cell * 0.9
  );
  glow.addColorStop(0, "rgba(255,255,255,0.55)");
  glow.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, state.width, state.height);

  // board frame — Longcat soft mat
  ctx.fillStyle = "rgba(255,255,255,0.35)";
  roundRectPath(f.originX - 16, f.originY - 16, f.cols * f.cell + 32, f.rows * f.cell + 32, 28);
  ctx.fill();
  ctx.fillStyle = "#fffdf8";
  roundRectPath(f.originX - 8, f.originY - 8, f.cols * f.cell + 16, f.rows * f.cell + 16, 20);
  ctx.fill();
  ctx.strokeStyle = "rgba(255, 182, 193, 0.55)";
  ctx.lineWidth = 4;
  roundRectPath(f.originX - 8, f.originY - 8, f.cols * f.cell + 16, f.rows * f.cell + 16, 20);
  ctx.stroke();

  for (let r = 0; r < f.rows; r++) {
    for (let c = 0; c < f.cols; c++) {
      const x = f.originX + c * f.cell;
      const y = f.originY + r * f.cell;
      const v = f.grid[r][c];
      if (v === 0) {
        ctx.fillStyle = theme.wall[1] || "#dfe6e9";
        roundRectPath(x + 3, y + 3, f.cell - 6, f.cell - 6, f.cell * 0.28);
        ctx.fill();
        const wall = ctx.createLinearGradient(x, y, x, y + f.cell);
        wall.addColorStop(0, theme.wall[0]);
        wall.addColorStop(1, theme.wall[1] || theme.wall[0]);
        ctx.fillStyle = wall;
        roundRectPath(x + 5, y + 5, f.cell - 10, f.cell - 10, f.cell * 0.24);
        ctx.fill();
        ctx.fillStyle = "rgba(255,255,255,0.35)";
        roundRectPath(x + 8, y + 8, f.cell - 18, f.cell * 0.22, 6);
        ctx.fill();
      } else if (v === 1) {
        const isCharge = f.charge && f.charge.c === c && f.charge.r === r;
        if (isCharge) {
          drawChargeStation(x, y, f.cell, f.hintPulse, false);
        } else {
          ctx.fillStyle = "#f1f2f6";
          roundRectPath(x + 4, y + 4, f.cell - 8, f.cell - 8, f.cell * 0.3);
          ctx.fill();
          ctx.fillStyle = hexToRgba(theme.empty[1] || "#fab1a0", 0.22 + 0.12 * Math.sin(f.hintPulse * 3 + c + r));
          roundRectPath(x + 9, y + 9, f.cell - 18, f.cell - 18, f.cell * 0.24);
          ctx.fill();
        }
      } else {
        const isCharge = f.charge && f.charge.c === c && f.charge.r === r;
        if (isCharge) {
          drawChargeStation(x, y, f.cell, f.hintPulse, true);
        } else {
          drawLongcarBodySegment(x, y, f.cell, theme, c + r);
        }
      }
    }
  }

  if (f.moveFlash > 0) {
    ctx.fillStyle = `rgba(255,255,255,${f.moveFlash * 0.35})`;
    roundRectPath(f.originX - 8, f.originY - 8, f.cols * f.cell + 16, f.rows * f.cell + 16, 18);
    ctx.fill();
  }

  // Tesla Model Y head (Longcat-style stretch head)
  const hx = f.originX + f.head.c * f.cell + f.cell / 2;
  const hy = f.originY + f.head.r * f.cell + f.cell / 2;
  const facing = f.lastDir || state.fillFacing || { dc: 1, dr: 0 };
  drawModelY(hx, hy, f.cell, facing, f.hintPulse);

  // glowing direction pads
  const dirs = [
    { dc: 0, dr: -1, label: "▲" },
    { dc: 0, dr: 1, label: "▼" },
    { dc: -1, dr: 0, label: "◀" },
    { dc: 1, dr: 0, label: "▶" },
  ];
  const pulse = 0.5 + 0.5 * Math.sin(f.hintPulse * 5);
  for (const d of dirs) {
    const nc = f.head.c + d.dc;
    const nr = f.head.r + d.dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols) continue;
    if (f.grid[nr][nc] !== 1) continue;
    const p = fillCellCenter(nc, nr);
    const isHint =
      f.hintFlash > 0 &&
      f.hintDir &&
      f.hintDir.dc === d.dc &&
      f.hintDir.dr === d.dr;
    const ring = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, f.cell * (isHint ? 0.48 : 0.38));
    if (isHint) {
      const blink = 0.55 + 0.45 * Math.sin(f.hintPulse * 8);
      ring.addColorStop(0, "rgba(255,255,255,0.95)");
      ring.addColorStop(0.45, `rgba(255, 209, 102, ${0.55 + blink * 0.4})`);
      ring.addColorStop(1, "rgba(255, 118, 117, 0)");
    } else {
      ring.addColorStop(0, "rgba(255,255,255,0.9)");
      ring.addColorStop(0.5, hexToRgba(theme.accent || "#74b9ff", 0.45 + pulse * 0.4));
      ring.addColorStop(1, hexToRgba(theme.accent || "#74b9ff", 0));
    }
    ctx.fillStyle = ring;
    ctx.beginPath();
    ctx.arc(p.x, p.y, f.cell * (isHint ? 0.48 : 0.38), 0, Math.PI * 2);
    ctx.fill();
    if (isHint) {
      ctx.strokeStyle = "#ffeaa7";
      ctx.lineWidth = 3;
      ctx.beginPath();
      ctx.arc(p.x, p.y, f.cell * 0.42, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.fillStyle = isHint ? "#d63031" : theme.accent || "#0984e3";
    ctx.font = `900 ${Math.floor(f.cell * (isHint ? 0.4 : 0.34))}px Fredoka, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(d.label, p.x, p.y + 1);
  }

  // floating hint chip while flashing
  if (f.hintFlash > 0 && f.hintDir) {
    const alpha = Math.min(1, f.hintFlash / 1.2);
    ctx.save();
    ctx.globalAlpha = alpha;
    const chipY = Math.max(52, f.originY - 58);
    ctx.fillStyle = "rgba(45,52,54,0.72)";
    roundRectPath(state.width * 0.5 - 110, chipY - 16, 220, 32, 16);
    ctx.fill();
    ctx.fillStyle = "#ffeaa7";
    ctx.font = "900 15px Fredoka, Nunito, sans-serif";
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(`İPUCU ${f.hintDir.label}  bu yöne git!`, state.width * 0.5, chipY);
    ctx.restore();
  }

  // title + progress
  const pct = Math.round((f.filled / f.emptyTotal) * 100);
  const titleY = Math.max(58, f.originY - 34);
  ctx.save();
  ctx.font = "900 20px Fredoka, Nunito, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.lineWidth = 5;
  ctx.strokeStyle = "rgba(31,58,77,0.28)";
  ctx.fillStyle = "#fff8ef";
  ctx.strokeText(f.title || "Longcar", state.width * 0.5, titleY);
  ctx.fillText(f.title || "Longcar", state.width * 0.5, titleY);
  ctx.restore();

  const barW = Math.min(220, state.width * 0.62);
  const barX = state.width * 0.5 - barW / 2;
  const barY = Math.min(state.height - 42, f.originY + f.rows * f.cell + 16);
  ctx.fillStyle = "rgba(45,52,54,0.45)";
  roundRectPath(barX, barY, barW, 22, 11);
  ctx.fill();
  const fillW = Math.max(10, (barW - 6) * (pct / 100));
  const barGrad = ctx.createLinearGradient(barX, 0, barX + barW, 0);
  barGrad.addColorStop(0, theme.fill[1] || "#ffd166");
  barGrad.addColorStop(1, theme.head[1] || "#ff7675");
  ctx.fillStyle = barGrad;
  roundRectPath(barX + 3, barY + 3, fillW, 16, 8);
  ctx.fill();
  ctx.fillStyle = "#fff";
  ctx.font = "800 13px Nunito, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText(`%${pct}  ·  ${f.filled}/${f.emptyTotal}`, state.width * 0.5, barY + 11);
}

function drawFillDecor(f, theme) {
  const decor = theme.decor || "balloons";
  if (decor === "stars") {
    for (const s of f.sparkles || []) {
      const x = s.x * state.width;
      const y = ((s.y + f.hintPulse * s.sp * 0.04) % 1) * state.height * 0.95;
      const tw = 0.35 + 0.65 * Math.abs(Math.sin(f.hintPulse * 3 + s.phase));
      ctx.globalAlpha = tw;
      ctx.fillStyle = "#ffeaa7";
      drawStar(x, y, 5, 3 * s.s, 1.4 * s.s);
      ctx.globalAlpha = 1;
    }
    return;
  }
  if (decor === "rainbow") {
    for (let i = 0; i < 6; i++) {
      const colors = ["#ff7675", "#fdcb6e", "#ffeaa7", "#55efc4", "#74b9ff", "#a29bfe"];
      ctx.strokeStyle = colors[i];
      ctx.globalAlpha = 0.28;
      ctx.lineWidth = 10;
      ctx.beginPath();
      ctx.arc(state.width * 0.5, state.height * 0.95, state.width * 0.55 - i * 12, Math.PI * 1.05, Math.PI * 1.95);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }
  if (decor === "candy") {
    for (let i = 0; i < 10; i++) {
      const t = f.hintPulse * (0.4 + i * 0.03) + i;
      const x = ((i * 97 + Math.cos(t) * 20) % (state.width + 30)) - 15;
      const y = 50 + (i * 41) % (state.height * 0.4);
      ctx.save();
      ctx.translate(x, y + Math.sin(t * 1.3) * 5);
      ctx.rotate(t * 0.4);
      ctx.fillStyle = i % 2 ? "#fd79a8" : "#55efc4";
      ctx.globalAlpha = 0.45;
      roundRectPath(-8, -4, 16, 8, 4);
      ctx.fill();
      ctx.restore();
      ctx.globalAlpha = 1;
    }
  }
  // floating balloons for balloons / rainbow fallback accents
  if (decor === "balloons" || decor === "rainbow") {
    const cols = ["#ff7675", "#55efc4", "#ffeaa7", "#fd79a8", "#74b9ff", "#a29bfe"];
    for (let i = 0; i < 9; i++) {
      const t = f.hintPulse * (0.28 + i * 0.04) + i;
      const bx = ((i * 89 + Math.sin(t) * 22) % (state.width + 50)) - 25;
      const by = 36 + (i * 39) % (state.height * 0.38);
      const br = 11 + (i % 3) * 4;
      ctx.globalAlpha = 0.38;
      ctx.fillStyle = cols[i % cols.length];
      ctx.beginPath();
      ctx.ellipse(bx, by + Math.sin(t * 1.4) * 7, br * 0.85, br, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(255,255,255,0.35)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(bx, by + br);
      ctx.quadraticCurveTo(bx + 4, by + br + 12, bx - 2, by + br + 22);
      ctx.stroke();
      ctx.globalAlpha = 1;
    }
  }
  // soft clouds (not for night star map)
  if (decor !== "stars") {
    ctx.fillStyle = "rgba(255,255,255,0.5)";
    for (let i = 0; i < 5; i++) {
      const cx = (i * 130 + f.hintPulse * 14) % (state.width + 90) - 45;
      const cy = 28 + i * 30;
      ctx.beginPath();
      ctx.arc(cx, cy, 18, 0, Math.PI * 2);
      ctx.arc(cx + 16, cy - 6, 14, 0, Math.PI * 2);
      ctx.arc(cx + 28, cy + 2, 12, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}

function drawStar(x, y, points, outer, inner) {
  ctx.beginPath();
  for (let i = 0; i < points * 2; i++) {
    const r = i % 2 === 0 ? outer : inner;
    const a = (Math.PI / points) * i - Math.PI / 2;
    const px = x + Math.cos(a) * r;
    const py = y + Math.sin(a) * r;
    if (i === 0) ctx.moveTo(px, py);
    else ctx.lineTo(px, py);
  }
  ctx.closePath();
  ctx.fill();
}

function hexToRgba(hex, a) {
  if (!hex || hex[0] !== "#" || (hex.length !== 7 && hex.length !== 4)) {
    return `rgba(116,185,255,${a})`;
  }
  let r;
  let g;
  let b;
  if (hex.length === 4) {
    r = parseInt(hex[1] + hex[1], 16);
    g = parseInt(hex[2] + hex[2], 16);
    b = parseInt(hex[3] + hex[3], 16);
  } else {
    r = parseInt(hex.slice(1, 3), 16);
    g = parseInt(hex.slice(3, 5), 16);
    b = parseInt(hex.slice(5, 7), 16);
  }
  return `rgba(${r},${g},${b},${a})`;
}

function drawChargeStation(x, y, cell, pulseT, filled) {
  const pad = cell * 0.06;
  const blink = 0.55 + 0.45 * Math.sin((pulseT || 0) * 6);
  // base pad
  ctx.fillStyle = filled ? "#dff9fb" : "#fff8ef";
  roundRectPath(x + pad, y + pad, cell - pad * 2, cell - pad * 2, cell * 0.28);
  ctx.fill();
  ctx.strokeStyle = `rgba(0, 206, 201, ${0.55 + blink * 0.4})`;
  ctx.lineWidth = Math.max(3, cell * 0.08);
  roundRectPath(x + pad, y + pad, cell - pad * 2, cell - pad * 2, cell * 0.28);
  ctx.stroke();

  // charging pedestal
  const cx = x + cell / 2;
  const cy = y + cell * 0.58;
  ctx.fillStyle = "#2d3436";
  roundRectPath(cx - cell * 0.12, cy - cell * 0.08, cell * 0.24, cell * 0.28, 5);
  ctx.fill();
  ctx.fillStyle = "#636e72";
  roundRectPath(cx - cell * 0.18, cy + cell * 0.16, cell * 0.36, cell * 0.08, 4);
  ctx.fill();

  // glowing bolt
  ctx.fillStyle = `rgba(253, 203, 110, ${0.75 + blink * 0.25})`;
  ctx.font = `900 ${Math.floor(cell * 0.42)}px Fredoka, sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("⚡", cx, y + cell * 0.32);

  // screen label
  ctx.fillStyle = filled ? "#00b894" : "#0984e3";
  ctx.font = `900 ${Math.max(10, Math.floor(cell * 0.16))}px Nunito, sans-serif`;
  ctx.fillText(filled ? "DOLU" : "ŞARJ", cx, y + cell * 0.82);

  // aura
  const aura = ctx.createRadialGradient(cx, cy, 4, cx, cy, cell * 0.55);
  aura.addColorStop(0, `rgba(0, 206, 201, ${0.25 * blink})`);
  aura.addColorStop(1, "rgba(0,206,201,0)");
  ctx.fillStyle = aura;
  ctx.beginPath();
  ctx.arc(cx, cy, cell * 0.55, 0, Math.PI * 2);
  ctx.fill();
}

function drawLongcarBodySegment(x, y, cell, theme, seed) {
  const pad = cell * 0.04;
  const rr = cell * 0.4;
  // Longcat chunky blob body in Model Y pearl white
  ctx.fillStyle = "rgba(0,0,0,0.08)";
  roundRectPath(x + pad + 2, y + pad + 3, cell - pad * 2, cell - pad * 2, rr);
  ctx.fill();
  const body = ctx.createRadialGradient(
    x + cell * 0.35,
    y + cell * 0.3,
    2,
    x + cell / 2,
    y + cell / 2,
    cell * 0.55
  );
  body.addColorStop(0, "#ffffff");
  body.addColorStop(0.55, "#f5f6fa");
  body.addColorStop(1, "#dcdde1");
  ctx.fillStyle = body;
  roundRectPath(x + pad, y + pad, cell - pad * 2, cell - pad * 2, rr);
  ctx.fill();
  // soft pink Longcat outline
  ctx.strokeStyle = "rgba(255, 159, 243, 0.55)";
  ctx.lineWidth = Math.max(2, cell * 0.06);
  roundRectPath(x + pad, y + pad, cell - pad * 2, cell - pad * 2, rr);
  ctx.stroke();
  // highlight
  ctx.fillStyle = "rgba(255,255,255,0.7)";
  ctx.beginPath();
  ctx.ellipse(x + cell * 0.35, y + cell * 0.32, cell * 0.14, cell * 0.09, -0.4, 0, Math.PI * 2);
  ctx.fill();
  // tiny Tesla stripe
  ctx.fillStyle = seed % 2 === 0 ? "rgba(116,185,255,0.35)" : "rgba(45,52,54,0.12)";
  roundRectPath(x + cell * 0.28, y + cell * 0.62, cell * 0.44, cell * 0.1, 4);
  ctx.fill();
}

function drawModelY(x, y, cell, facing, pulseT) {
  const bob = Math.sin((pulseT || 0) * 6) * 1.4;
  let angle = 0;
  if (facing.dc === 1) angle = Math.PI / 2;
  else if (facing.dc === -1) angle = -Math.PI / 2;
  else if (facing.dr === 1) angle = Math.PI;
  else angle = 0;

  const s = cell * 0.58;
  // Longcat-like soft aura
  const aura = ctx.createRadialGradient(x, y + bob, s * 0.2, x, y + bob, s * 2.2);
  aura.addColorStop(0, "rgba(255, 182, 193, 0.55)");
  aura.addColorStop(0.45, "rgba(116, 185, 255, 0.25)");
  aura.addColorStop(1, "rgba(0,0,0,0)");
  ctx.fillStyle = aura;
  ctx.beginPath();
  ctx.arc(x, y + bob, s * 2.2, 0, Math.PI * 2);
  ctx.fill();

  ctx.save();
  ctx.translate(x, y + bob);
  ctx.rotate(angle);

  // shadow
  ctx.fillStyle = "rgba(0,0,0,0.22)";
  ctx.beginPath();
  ctx.ellipse(2, 4, s * 0.85, s * 1.15, 0, 0, Math.PI * 2);
  ctx.fill();

  // Model Y body — wider crossover proportions
  const body = ctx.createLinearGradient(-s, -s, s, s);
  body.addColorStop(0, "#ffffff");
  body.addColorStop(0.4, "#f5f6fa");
  body.addColorStop(1, "#b2bec3");
  roundRectPath(-s * 0.72, -s * 1.12, s * 1.44, s * 2.24, s * 0.42);
  ctx.fillStyle = body;
  ctx.fill();
  ctx.strokeStyle = "rgba(255, 159, 243, 0.65)";
  ctx.lineWidth = Math.max(2, s * 0.1);
  roundRectPath(-s * 0.72, -s * 1.12, s * 1.44, s * 2.24, s * 0.42);
  ctx.stroke();

  // panoramic glass roof (Model Y signature)
  const glass = ctx.createLinearGradient(0, -s * 0.85, 0, s * 0.35);
  glass.addColorStop(0, "#1e272e");
  glass.addColorStop(0.55, "#485460");
  glass.addColorStop(1, "#747d8c");
  roundRectPath(-s * 0.5, -s * 0.72, s * 1.0, s * 1.15, s * 0.28);
  ctx.fillStyle = glass;
  ctx.fill();
  ctx.fillStyle = "rgba(255,255,255,0.25)";
  ctx.beginPath();
  ctx.ellipse(-s * 0.15, -s * 0.4, s * 0.28, s * 0.14, -0.35, 0, Math.PI * 2);
  ctx.fill();
  // roof cross seam
  ctx.strokeStyle = "rgba(255,255,255,0.2)";
  ctx.lineWidth = 1.5;
  ctx.beginPath();
  ctx.moveTo(0, -s * 0.65);
  ctx.lineTo(0, s * 0.3);
  ctx.stroke();

  // front light bar
  const blink = 0.65 + 0.35 * Math.sin((pulseT || 0) * 10);
  ctx.fillStyle = `rgba(116,185,255,${blink})`;
  roundRectPath(-s * 0.38, -s * 1.08, s * 0.76, s * 0.14, s * 0.06);
  ctx.fill();

  // headlight beam
  const beam = ctx.createRadialGradient(0, -s * 1.15, 2, 0, -s * 2.3, s * 1.7);
  beam.addColorStop(0, `rgba(116,185,255,${0.5 * blink})`);
  beam.addColorStop(1, "rgba(116,185,255,0)");
  ctx.fillStyle = beam;
  ctx.beginPath();
  ctx.moveTo(-s * 0.32, -s * 1.1);
  ctx.lineTo(s * 0.32, -s * 1.1);
  ctx.lineTo(s, -s * 2.5);
  ctx.lineTo(-s, -s * 2.5);
  ctx.closePath();
  ctx.fill();

  // rear light
  ctx.fillStyle = "#ff6b6b";
  roundRectPath(-s * 0.34, s * 0.95, s * 0.68, s * 0.11, 2);
  ctx.fill();

  // wheels — Model Y stance
  ctx.fillStyle = "#1e272e";
  roundRectPath(-s * 0.82, -s * 0.62, s * 0.2, s * 0.42, 4);
  ctx.fill();
  roundRectPath(s * 0.62, -s * 0.62, s * 0.2, s * 0.42, 4);
  ctx.fill();
  roundRectPath(-s * 0.82, s * 0.18, s * 0.2, s * 0.42, 4);
  ctx.fill();
  roundRectPath(s * 0.62, s * 0.18, s * 0.2, s * 0.42, 4);
  ctx.fill();
  // wheel hubs
  ctx.fillStyle = "#dfe6e9";
  for (const [wx, wy] of [[-s*0.72,-s*0.41],[s*0.72,-s*0.41],[-s*0.72,s*0.39],[s*0.72,s*0.39]]) {
    ctx.beginPath();
    ctx.arc(wx, wy, s * 0.07, 0, Math.PI * 2);
    ctx.fill();
  }

  // Tesla T mark
  ctx.fillStyle = "#2f3542";
  ctx.font = `900 ${Math.floor(s * 0.42)}px Fredoka, sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("Y", 0, s * 0.58);

  ctx.restore();
}

function drawFillCar(x, y, cell, facing, theme, pulseT) {
  drawModelY(x, y, cell, facing, pulseT);
}

function handleFillPointer(x, y) {
  const f = state.fill;
  if (!f || f.won) return;
  // yön hücrelerine dokunma
  const dirs = [
    { dc: 0, dr: -1 },
    { dc: 0, dr: 1 },
    { dc: -1, dr: 0 },
    { dc: 1, dr: 0 },
  ];
  for (const d of dirs) {
    const nc = f.head.c + d.dc;
    const nr = f.head.r + d.dr;
    if (nr < 0 || nc < 0 || nr >= f.rows || nc >= f.cols) continue;
    if (f.grid[nr][nc] !== 1) continue;
    const p = fillCellCenter(nc, nr);
    const hit = f.cell * 0.55;
    if (Math.abs(x - p.x) < hit && Math.abs(y - p.y) < hit) {
      tryFillMove(d.dc, d.dr);
      return;
    }
  }
  // tahta dışına / genel kaydırma için swipe kullanacağız
}


function initDriveMode() {
  state.hop = null;
  state.balloons = [];
  state.drive = {
    carX: state.width * 0.5,
    targetX: state.width * 0.5,
    carY: state.height * 0.78,
    steer: 0,
    roadOffset: 0,
    speed: 280,
    wheelAngle: 0,
    headlightPulse: 0,
    trail: [],
    pointerActive: false,
  };
  for (let i = 0; i < 6; i++) spawnDriveBalloon(true);
}

function spawnDriveBalloon(initial = false) {
  const boosting = state.boostLeft > 0;
  let color;
  if (boosting && Math.random() < 0.28) {
    color = COLORS.find((c) => c.skull);
  } else if (Math.random() < 0.14) {
    color = COLORS.find((c) => c.gold);
  } else {
    color = pick(COLORS.filter((c) => !c.gold && !c.skull));
  }
  const r = color.gold || color.skull ? rand(36, 50) : rand(30, 44);
  const margin = 36;
  state.balloons.push({
    x: rand(margin + r, state.width - margin - r),
    y: initial ? rand(-state.height * 0.2, state.height * 0.45) : -r - rand(10, 120),
    r,
    vy: rand(90, 150) + (boosting ? 70 : 0) + Math.min(80, state.score / 50),
    wobble: rand(0, Math.PI * 2),
    wobbleSpeed: rand(1.8, 3.5),
    wobbleAmp: rand(18, 40),
    color,
    popped: false,
    scale: 1,
    pulse: rand(0, Math.PI * 2),
    birth: performance.now(),
    driveMode: true,
  });
}

function drawTesla(x, y, steer = 0) {
  // Üstten görünüm — araç düz, öne (yukarı) bakıyor
  const lean = Math.max(-0.18, Math.min(0.18, steer * 0.05));
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(lean);

  // gölge
  ctx.fillStyle = "rgba(0,0,0,0.3)";
  ctx.beginPath();
  ctx.ellipse(4, 10, 34, 58, 0, 0, Math.PI * 2);
  ctx.fill();

  // gövde (Model 3 / Y üstten)
  const body = ctx.createLinearGradient(-32, -60, 32, 60);
  body.addColorStop(0, "#ffffff");
  body.addColorStop(0.5, "#dfe6e9");
  body.addColorStop(1, "#b2bec3");
  roundRectPath(-30, -58, 60, 116, 22);
  ctx.fillStyle = body;
  ctx.fill();

  // cam tavan
  const glass = ctx.createLinearGradient(0, -40, 0, 20);
  glass.addColorStop(0, "#1e272e");
  glass.addColorStop(1, "#576574");
  roundRectPath(-22, -36, 44, 58, 14);
  ctx.fillStyle = glass;
  ctx.fill();
  ctx.fillStyle = "rgba(255,255,255,0.2)";
  ctx.beginPath();
  ctx.ellipse(-8, -20, 12, 8, -0.3, 0, Math.PI * 2);
  ctx.fill();

  // ön far şeridi (üstte = ileri)
  const pulse = 0.7 + Math.sin(state.beatT * 9) * 0.25;
  const light = ctx.createLinearGradient(-20, -56, 20, -56);
  light.addColorStop(0, "rgba(116,185,255,0)");
  light.addColorStop(0.5, `rgba(116,185,255,${pulse})`);
  light.addColorStop(1, "rgba(116,185,255,0)");
  ctx.fillStyle = light;
  roundRectPath(-18, -56, 36, 7, 3);
  ctx.fill();

  // ışık huzmesi ileri
  const beam = ctx.createRadialGradient(0, -70, 2, 0, -120, 80);
  beam.addColorStop(0, `rgba(116,185,255,${0.4 * pulse})`);
  beam.addColorStop(1, "rgba(116,185,255,0)");
  ctx.fillStyle = beam;
  ctx.beginPath();
  ctx.moveTo(-16, -58);
  ctx.lineTo(16, -58);
  ctx.lineTo(50, -150);
  ctx.lineTo(-50, -150);
  ctx.closePath();
  ctx.fill();

  // arka stop
  ctx.fillStyle = "#ff6b6b";
  roundRectPath(-16, 50, 32, 5, 2);
  ctx.fill();

  // tekerlekler
  ctx.fillStyle = "#1e272e";
  roundRectPath(-34, -38, 10, 22, 4);
  ctx.fill();
  roundRectPath(24, -38, 10, 22, 4);
  ctx.fill();
  roundRectPath(-34, 20, 10, 22, 4);
  ctx.fill();
  roundRectPath(24, 20, 10, 22, 4);
  ctx.fill();

  // Tesla T
  ctx.fillStyle = "#2f3542";
  ctx.font = "900 15px Fredoka, sans-serif";
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.fillText("T", 0, 36);

  ctx.restore();
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

function drawDriveWorld(dt) {
  const drive = state.drive;
  if (!drive) return;

  // sunset / neon highway sky
  const sky = ctx.createLinearGradient(0, 0, 0, state.height);
  sky.addColorStop(0, "#0f0c29");
  sky.addColorStop(0.35, "#302b63");
  sky.addColorStop(0.7, "#ff6b6b");
  sky.addColorStop(1, "#feca57");
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, state.width, state.height);

  // sun
  const sun = ctx.createRadialGradient(state.width * 0.5, state.height * 0.42, 10, state.width * 0.5, state.height * 0.42, 90);
  sun.addColorStop(0, "rgba(255, 234, 167, 0.95)");
  sun.addColorStop(0.5, "rgba(255, 159, 67, 0.55)");
  sun.addColorStop(1, "rgba(255, 107, 107, 0)");
  ctx.fillStyle = sun;
  ctx.beginPath();
  ctx.arc(state.width * 0.5, state.height * 0.42, 90, 0, Math.PI * 2);
  ctx.fill();

  // city silhouettes
  ctx.fillStyle = "rgba(20, 20, 40, 0.85)";
  const baseY = state.height * 0.52;
  for (let i = 0; i < 12; i++) {
    const bx = ((i * 70 - drive.roadOffset * 0.15) % (state.width + 80)) - 40;
    const bh = 40 + (i % 5) * 18;
    ctx.fillRect(bx, baseY - bh, 48, bh);
  }

  // road
  const roadTop = state.height * 0.55;
  ctx.fillStyle = "#2f3542";
  ctx.beginPath();
  ctx.moveTo(0, state.height);
  ctx.lineTo(0, roadTop + 40);
  ctx.lineTo(state.width * 0.15, roadTop);
  ctx.lineTo(state.width * 0.85, roadTop);
  ctx.lineTo(state.width, roadTop + 40);
  ctx.lineTo(state.width, state.height);
  ctx.closePath();
  ctx.fill();

  // road edge glow
  ctx.strokeStyle = "rgba(116, 185, 255, 0.45)";
  ctx.lineWidth = 4;
  ctx.beginPath();
  ctx.moveTo(state.width * 0.18, roadTop + 8);
  ctx.lineTo(24, state.height);
  ctx.moveTo(state.width * 0.82, roadTop + 8);
  ctx.lineTo(state.width - 24, state.height);
  ctx.stroke();

  // dashed center lines
  ctx.strokeStyle = "#f1c40f";
  ctx.lineWidth = 5;
  ctx.setLineDash([28, 26]);
  ctx.lineDashOffset = -drive.roadOffset;
  ctx.beginPath();
  ctx.moveTo(state.width * 0.5, roadTop + 10);
  ctx.lineTo(state.width * 0.5, state.height + 20);
  ctx.stroke();
  ctx.setLineDash([]);

  // motion streaks when boosting
  if (state.boostLeft > 0) {
    ctx.strokeStyle = "rgba(255,255,255,0.35)";
    ctx.lineWidth = 2;
    for (let i = 0; i < 14; i++) {
      const sx = (i * 97 + drive.roadOffset * 2) % state.width;
      const sy = (i * 53 + drive.roadOffset) % state.height;
      ctx.beginPath();
      ctx.moveTo(sx, sy);
      ctx.lineTo(sx, sy + 28);
      ctx.stroke();
    }
  }

  // balloons drawn by caller after this, then car on top
}

function updateDrive(dt) {
  const drive = state.drive;
  if (!drive) return;

  // timer / boost
  if (state.boostLeft > 0) {
    state.boostLeft -= dt;
    if (state.boostLeft <= 0) {
      state.boostLeft = 0;
      setBoosting(false);
      showBanner("BOOST BİTTİ", "bonus");
    }
  } else {
    state.timeLeft -= dt;
    if (state.timeLeft <= 0) {
      state.timeLeft = 0;
      updateHud();
      endGame();
      return;
    }
  }

  state.comboTimer -= dt;
  if (state.comboTimer <= 0) state.combo = 0;

  // steer toward target
  const maxX = state.width - 70;
  const minX = 70;
  drive.targetX = Math.max(minX, Math.min(maxX, drive.targetX));
  const prevX = drive.carX;
  drive.carX += (drive.targetX - drive.carX) * Math.min(1, dt * 10);
  drive.steer = (drive.carX - prevX) / Math.max(dt, 0.001) / 200;
  drive.carY = state.height * 0.78;
  drive.speed = state.boostLeft > 0 ? 420 : 280;
  drive.roadOffset = (drive.roadOffset + drive.speed * dt) % 1000;
  drive.wheelAngle += drive.speed * dt * 0.05;
  drive.headlightPulse += dt;

  // spawn balloons from top
  const boosting = state.boostLeft > 0;
  const spawnRate = boosting ? 0.18 : Math.max(0.28, 0.55 - state.score / 2000);
  state.spawnTimer -= dt;
  if (state.spawnTimer <= 0) {
    spawnDriveBalloon();
    if (Math.random() < 0.4) spawnDriveBalloon();
    if (boosting && Math.random() < 0.5) spawnDriveBalloon();
    state.spawnTimer = spawnRate;
  }

  // collide car with balloons
  const carHitY = drive.carY - 10;
  const carW = 70;
  for (const b of state.balloons) {
    if (b.popped) continue;
    const dx = b.x - drive.carX;
    const dy = b.y - carHitY;
    if (Math.abs(dx) < carW * 0.7 + b.r * 0.35 && Math.abs(dy) < 36 + b.r * 0.4) {
      popBalloon(b);
    }
  }

  updateHud();
}

function playHopBeat(intensity = 1) {
  ensureAudio();
  if (!audioCtx || (state.hop && state.hop.musicGlitch > 0)) return;
  const t = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "sine";
  osc.frequency.setValueAtTime(150 + 40 * intensity, t);
  osc.frequency.exponentialRampToValueAtTime(55, t + 0.09);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.22 * Math.min(1.3, intensity), t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.12);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.13);
}

function playHopMelody() {
  ensureAudio();
  if (!audioCtx || (state.hop && state.hop.musicGlitch > 0)) return;
  const notes = [523.25, 587.33, 659.25, 783.99, 659.25, 587.33];
  const hop = state.hop;
  const idx = hop ? hop.melodyStep % notes.length : 0;
  if (hop) hop.melodyStep += 1;
  const t = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "triangle";
  osc.frequency.value = notes[idx];
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.1, t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.2);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.22);
}

function playMusicGlitch() {
  ensureAudio();
  if (!audioCtx) return;
  for (let i = 0; i < 5; i++) {
    const t = audioCtx.currentTime + i * 0.04;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "sawtooth";
    osc.frequency.setValueAtTime(120 + Math.random() * 600, t);
    osc.frequency.exponentialRampToValueAtTime(40 + Math.random() * 80, t + 0.15);
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.14, t + 0.01);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.18);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + 0.2);
  }
}

function projectHop(lane, z) {
  const depth = 1 / (1 + z * 0.48);
  const nearY = state.height * 0.76;
  const farY = state.height * 0.22;
  const y = farY + (nearY - farY) * depth;
  const laneSpread = Math.min(state.width * 0.3, 125) * depth;
  const x = state.width * 0.5 + (lane - 1) * laneSpread;
  const radius = Math.max(16, 48 * depth);
  return { x, y, r: radius, depth };
}

function makeHopTile(lane, z, kind) {
  const color =
    kind === "skull"
      ? "#2d3436"
      : kind === "gold"
        ? "#ffd166"
        : pick(HOP_TILE_COLORS);
  return {
    id: `t_${Math.random().toString(36).slice(2, 9)}`,
    lane,
    z,
    kind,
    color,
    hit: false,
    missed: false,
    pop: 1,
  };
}

function initHopMode() {
  const tiles = [];
  let z = 1.4;
  let lane = 1;
  // Temiz tek yol: her adımda 1 ana karo, ara sıra yan şeritte kurukafa
  for (let i = 0; i < 10; i++) {
    if (i > 0 && Math.random() < 0.4) {
      lane = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
    }
    let kind = "normal";
    if (i > 2 && Math.random() < 0.12) kind = "gold";
    tiles.push(makeHopTile(lane, z, kind));
    // Hızlanınca / ara sıra yanına kurukafa (basılmayacak)
    if (i > 1 && Math.random() < 0.28) {
      const side = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
      if (side !== lane) tiles.push(makeHopTile(side, z + 0.05, "skull"));
    }
    z += 1.55;
  }

  state.hop = {
    tiles,
    playerLane: 1,
    speed: 1.35,
    baseSpeed: 1.35,
    maxSpeed: 3.6,
    hopAnim: 0,
    hopFrom: { x: 0, y: 0 },
    hopTo: { x: 0, y: 0 },
    melodyStep: 0,
    combo: 0,
    nextSpawnZ: z,
    pulse: 0,
    perfectFlash: 0,
    beatAcc: 0,
    elapsed: 0,
    musicGlitch: 0,
    speedPhase: 0,
  };
  state.balloons = [];
  state.particles = [];
  state.rings = [];
  state.floatTexts = [];
}

function spawnHopTilesAhead() {
  const hop = state.hop;
  if (!hop) return;
  // Sadece aktif (yakında) karo sayısını sınırla — birikmeyi önle
  const live = hop.tiles.filter((t) => !t.hit && !t.missed);
  if (live.length >= 12) return;

  while (live.length + (hop.tiles.length - live.length) < 14 && hop.tiles.filter((t) => !t.hit && !t.missed).length < 12) {
    const goods = hop.tiles.filter((t) => !t.hit && !t.missed && t.kind !== "skull");
    const last = goods.length ? goods.reduce((a, b) => (a.z > b.z ? a : b)) : null;
    let lane = last ? last.lane : hop.playerLane;
    if (Math.random() < 0.42) {
      lane = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
    }
    const z = Math.max(hop.nextSpawnZ, last ? last.z + 1.5 : 2);
    let kind = "normal";
    if (Math.random() < 0.12) kind = "gold";
    hop.tiles.push(makeHopTile(lane, z, kind));
    // Hızlandıktan sonra daha sık kurukafa
    const skullRate = hop.speedPhase >= 1 ? 0.38 : 0.22;
    if (Math.random() < skullRate) {
      const side = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
      if (side !== lane) hop.tiles.push(makeHopTile(side, z + 0.08, "skull"));
    }
    hop.nextSpawnZ = z + 1.55;
    if (hop.tiles.filter((t) => !t.hit && !t.missed).length >= 12) break;
  }
}

function getNextHopTarget() {
  const hop = state.hop;
  if (!hop) return null;
  // Tek hedef: en yakındaki basılacak (normal/gold) karo
  const candidates = hop.tiles
    .filter((t) => !t.hit && !t.missed && t.kind !== "skull" && t.z > 0.45 && t.z < 4.5)
    .sort((a, b) => a.z - b.z);
  return candidates[0] || null;
}

function dramaticSkullBurst(x, y) {
  state.flash = 0.55;
  shakeScreen();
  burst(x, y, "#111111", true);
  burst(x, y, "#ff6b6b", true);
  burst(x, y, "#636e72", true);
  for (let i = 0; i < 3; i++) {
    state.rings.push({
      x,
      y,
      r: 6,
      max: 100 + i * 70,
      life: 0.55 + i * 0.12,
      age: 0,
      color: i === 1 ? "#ff6b6b" : "#2d3436",
      width: 10 - i * 2,
    });
  }
  showBanner("EYVAH!", "boost");
}

function onHopSuccess(tile) {
  const hop = state.hop;
  if (!tile || tile.hit || tile.missed) return;
  tile.hit = true;
  const from = projectHop(hop.playerLane, 0);
  const to = projectHop(tile.lane, Math.max(0.25, tile.z));
  hop.playerLane = tile.lane;
  hop.hopAnim = 1;
  hop.hopFrom = from;
  hop.hopTo = to;

  let gained = 14;
  if (tile.kind === "gold") gained = 32;
  hop.combo += 1;
  gained += Math.min(24, hop.combo * 2);
  gained = Math.round(gained * (1 + hop.speedPhase * 0.15));
  state.score += gained;
  state.combo = hop.combo;
  state.comboTimer = 1.3;
  hop.perfectFlash = 0.28;

  burst(to.x, to.y, tile.color, tile.kind === "gold");
  floatText(to.x, to.y - 28, `+${gained}`, "#fff8ef", { size: 28, bold: true, life: 0.75, rise: 65 });
  playHopBeat(1 + hop.combo * 0.04);
  playHopMelody();
  if (tile.kind === "gold") {
    showBanner("BONUS!", "bonus");
    playBonusFanfare();
  }
  haptic("medium");
  bumpScore();

  // Geride kalanları temizle — birikme olmasın
  hop.tiles.forEach((t) => {
    if (t.z <= tile.z + 0.2) {
      t.hit = true;
      t.pop = 0.01;
    }
  });
  const advance = tile.z;
  hop.tiles.forEach((t) => {
    t.z -= advance;
  });
  hop.nextSpawnZ = Math.max(hop.nextSpawnZ - advance, 3);
  hop.tiles = hop.tiles.filter((t) => t.z > -0.5 && !(t.hit && t.pop < 0.05));
  spawnHopTilesAhead();
  updateHud();
}

function onHopSkull(tile) {
  const hop = state.hop;
  if (!tile || tile.hit) return;
  tile.hit = true;
  hop.combo = 0;
  state.combo = 0;
  hop.musicGlitch = 1.1;
  const lost = 30;
  state.score = Math.max(0, state.score - lost);
  const p = projectHop(tile.lane, Math.max(0.2, tile.z));
  dramaticSkullBurst(p.x, p.y);
  floatText(p.x, p.y - 24, "☠", "#fff", { size: 48, bold: true, life: 1.1, rise: 70 });
  floatText(p.x, p.y + 18, `-${lost}`, "#ff6b6b", { size: 32, bold: true, life: 1, rise: 55 });
  playMusicGlitch();
  playSkullBuzz();
  haptic("heavy");
  bumpScore();
  // hafif yavaşlat (müzik bozulması hissi)
  hop.speed = Math.max(hop.baseSpeed, hop.speed * 0.82);
  updateHud();
}

function onHopMiss(tile) {
  const hop = state.hop;
  tile.missed = true;
  hop.combo = 0;
  state.combo = 0;
  const lost = 8;
  state.score = Math.max(0, state.score - lost);
  const p = projectHop(tile.lane, 0.5);
  floatText(p.x, p.y, "Geçti!", "#ffd166", { size: 20, bold: true, life: 0.6, rise: 36 });
  haptic("light");
  updateHud();
}

function updateHop(dt) {
  const hop = state.hop;
  if (!hop) return;

  hop.elapsed += dt;
  state.timeLeft -= dt;
  if (state.timeLeft <= 0) {
    state.timeLeft = 0;
    updateHud();
    endGame();
    return;
  }

  // Belli saniyeden sonra hızlan (Tiles Hop gibi aşamalı)
  if (hop.elapsed > 28) hop.speedPhase = 2;
  else if (hop.elapsed > 12) hop.speedPhase = 1;
  else hop.speedPhase = 0;

  const phaseSpeed = hop.baseSpeed + hop.speedPhase * 0.85;
  hop.speed += (phaseSpeed - hop.speed) * Math.min(1, dt * 2);

  if (hop.musicGlitch > 0) hop.musicGlitch = Math.max(0, hop.musicGlitch - dt);
  hop.pulse += dt * (3.2 + hop.speed);
  if (hop.hopAnim > 0) hop.hopAnim = Math.max(0, hop.hopAnim - dt * 3.4);
  if (hop.perfectFlash > 0) hop.perfectFlash = Math.max(0, hop.perfectFlash - dt);

  // Ritim müziği — hedefe basınca da melodi ekleniyor
  hop.beatAcc += dt;
  const beatEvery = hop.speedPhase === 0 ? 0.5 : hop.speedPhase === 1 ? 0.36 : 0.26;
  if (hop.beatAcc >= beatEvery) {
    hop.beatAcc = 0;
    playHopBeat(0.75 + hop.speedPhase * 0.15);
  }

  for (const tile of hop.tiles) {
    if (tile.hit || tile.missed) continue;
    tile.z -= hop.speed * dt;
    if (tile.z <= 0.2) {
      if (tile.kind === "skull") tile.missed = true; // geçmek iyi
      else onHopMiss(tile);
    }
  }

  hop.tiles = hop.tiles.filter((t) => {
    if (t.z < -1) return false;
    if ((t.hit || t.missed) && t.z < 0.1) return false;
    return true;
  });
  spawnHopTilesAhead();

  state.comboTimer -= dt;
  if (state.comboTimer <= 0) {
    state.combo = 0;
    hop.combo = 0;
  }
  updateHud();
}

function drawHopWorld() {
  const hop = state.hop;
  if (!hop) return;

  const g = ctx.createLinearGradient(0, 0, 0, state.height);
  if (hop.musicGlitch > 0) {
    g.addColorStop(0, "#2d3436");
    g.addColorStop(0.5, "#6c5ce7");
    g.addColorStop(1, "#ff6b6b");
  } else {
    g.addColorStop(0, "#1b1464");
    g.addColorStop(0.45, "#6c5ce7");
    g.addColorStop(1, "#fd79a8");
  }
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, state.width, state.height);

  const beat = 0.5 + 0.5 * Math.sin(hop.pulse * 2);
  const glow = ctx.createRadialGradient(
    state.width * 0.5,
    state.height * 0.35,
    20,
    state.width * 0.5,
    state.height * 0.35,
    240 + beat * 50
  );
  glow.addColorStop(0, `rgba(255,255,255,${0.1 + beat * 0.12 + hop.perfectFlash})`);
  glow.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, state.width, state.height);

  for (let lane = 0; lane < HOP_LANES; lane++) {
    const a = projectHop(lane, 0.25);
    const b = projectHop(lane, 10);
    ctx.strokeStyle = "rgba(255,255,255,0.14)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
  }

  const target = getNextHopTarget();
  const sorted = [...hop.tiles].sort((a, b) => b.z - a.z);

  for (const tile of sorted) {
    if (tile.hit && tile.pop < 0.08) continue;
    const p = projectHop(tile.lane, Math.max(0.08, tile.z));
    const isTarget = target && tile.id === target.id;
    const pulseScale = isTarget ? 1 + Math.sin(hop.pulse * 5) * 0.12 : 1;
    const r = p.r * pulseScale * (tile.hit ? tile.pop : 1);

    // Hedef karo için büyük ışık halesi
    if (isTarget && !tile.hit) {
      const halo = ctx.createRadialGradient(p.x, p.y, r * 0.2, p.x, p.y, r * 2.2);
      halo.addColorStop(0, "rgba(255,255,255,0.75)");
      halo.addColorStop(0.35, "rgba(255,209,102,0.45)");
      halo.addColorStop(1, "rgba(255,209,102,0)");
      ctx.fillStyle = halo;
      ctx.beginPath();
      ctx.arc(p.x, p.y, r * 2.2, 0, Math.PI * 2);
      ctx.fill();

      ctx.strokeStyle = `rgba(255,255,255,${0.7 + beat * 0.3})`;
      ctx.lineWidth = Math.max(4, r * 0.16);
      ctx.beginPath();
      ctx.arc(p.x, p.y, r + 8 + Math.sin(hop.pulse * 6) * 4, 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.fillStyle = "rgba(0,0,0,0.22)";
    ctx.beginPath();
    ctx.ellipse(p.x, p.y + r * 0.35, r * 0.9, r * 0.28, 0, 0, Math.PI * 2);
    ctx.fill();

    const grad = ctx.createRadialGradient(p.x - r * 0.25, p.y - r * 0.3, r * 0.1, p.x, p.y, r);
    if (tile.kind === "skull") {
      grad.addColorStop(0, "#636e72");
      grad.addColorStop(1, "#1e272e");
    } else {
      grad.addColorStop(0, "#ffffff");
      grad.addColorStop(0.22, tile.color);
      grad.addColorStop(1, tile.color);
    }
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    ctx.fill();

    if (tile.kind === "gold") {
      ctx.fillStyle = "#fff";
      ctx.font = `700 ${Math.floor(r * 0.9)}px Fredoka, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("★", p.x, p.y + 1);
    } else if (tile.kind === "skull") {
      ctx.fillStyle = "#dfe6e9";
      ctx.font = `700 ${Math.floor(r * 0.95)}px Fredoka, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("☠", p.x, p.y + 1);
    }

    if (tile.hit) tile.pop *= 0.82;
  }

  // Oyuncu
  let px;
  let py;
  let pr;
  if (hop.hopAnim > 0) {
    const t = 1 - hop.hopAnim;
    const ease = t * t * (3 - 2 * t);
    px = hop.hopFrom.x + (hop.hopTo.x - hop.hopFrom.x) * ease;
    py = hop.hopFrom.y + (hop.hopTo.y - hop.hopFrom.y) * ease - Math.sin(Math.PI * t) * 55;
    pr = 22;
  } else {
    const p = projectHop(hop.playerLane, 0);
    px = p.x;
    py = p.y - 10;
    pr = 24;
  }

  ctx.fillStyle = "rgba(0,0,0,0.25)";
  ctx.beginPath();
  ctx.ellipse(px, py + 22, 18, 8, 0, 0, Math.PI * 2);
  ctx.fill();
  const body = ctx.createRadialGradient(px - 6, py - 8, 4, px, py, pr);
  body.addColorStop(0, "#fff5e8");
  body.addColorStop(1, "#ff9ff3");
  ctx.fillStyle = body;
  ctx.beginPath();
  ctx.arc(px, py, pr, 0, Math.PI * 2);
  ctx.fill();
  ctx.fillStyle = "#1f3a4d";
  ctx.beginPath();
  ctx.arc(px - 7, py - 2, 3, 0, Math.PI * 2);
  ctx.arc(px + 7, py - 2, 3, 0, Math.PI * 2);
  ctx.fill();
  ctx.strokeStyle = "#1f3a4d";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.arc(px, py + 6, 8, 0.15 * Math.PI, 0.85 * Math.PI);
  ctx.stroke();

  // Işıklı hedefe ok / yazı
  if (target) {
    const tp = projectHop(target.lane, target.z);
    ctx.fillStyle = "rgba(255,248,239,0.95)";
    ctx.font = "900 18px Fredoka, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("▼ BAS", tp.x, tp.y - tp.r - 16);
  }

  if (hop.speedPhase >= 1) {
    ctx.fillStyle = "rgba(255,248,239,0.85)";
    ctx.font = "800 14px Nunito, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(hop.speedPhase >= 2 ? "ÇOK HIZLI!" : "HIZLANDI!", state.width * 0.5, state.height * 0.08);
  }
}

function hopHitTest(x, y) {
  const hop = state.hop;
  if (!hop) return null;
  // Önce tüm yakın karolara bak (kurukafa dahil)
  const near = hop.tiles.filter((t) => !t.hit && !t.missed && t.z > 0.3 && t.z < 3.2);
  let best = null;
  let bestDist = Infinity;
  for (const tile of near) {
    const p = projectHop(tile.lane, tile.z);
    const dx = x - p.x;
    const dy = y - p.y;
    const d = dx * dx + dy * dy;
    const hitR = p.r * (tile.kind === "skull" ? 1.25 : 1.55);
    if (d <= hitR * hitR && d < bestDist) {
      best = tile;
      bestDist = d;
    }
  }
  return best;
}


function ensureAudio() {
  if (!audioCtx) {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (Ctx) audioCtx = new Ctx();
  }
  if (audioCtx?.state === "suspended") audioCtx.resume();
}

function playPop(pitch = 1) {
  ensureAudio();
  if (!audioCtx) return;
  const t = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "triangle";
  osc.frequency.setValueAtTime(420 * pitch, t);
  osc.frequency.exponentialRampToValueAtTime(120 * pitch, t + 0.12);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.22, t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.14);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.15);
}

function playCheer() {
  ensureAudio();
  if (!audioCtx) return;
  [523.25, 659.25, 783.99].forEach((freq, i) => {
    const t = audioCtx.currentTime + i * 0.08;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "sine";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.16, t + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.25);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + 0.26);
  });
}

function haptic(style = "medium") {
  const plugins = window.Capacitor?.Plugins;
  if (plugins?.Haptics?.impact) {
    const map = { light: "LIGHT", medium: "MEDIUM", heavy: "HEAVY" };
    plugins.Haptics.impact({ style: map[style] || "MEDIUM" });
    return;
  }
  if (navigator.vibrate) navigator.vibrate(style === "heavy" ? 30 : 15);
}

function resize() {
  state.dpr = Math.min(window.devicePixelRatio || 1, 2);
  state.width = window.innerWidth;
  state.height = window.innerHeight;
  canvas.width = Math.floor(state.width * state.dpr);
  canvas.height = Math.floor(state.height * state.dpr);
  canvas.style.width = `${state.width}px`;
  canvas.style.height = `${state.height}px`;
  ctx.setTransform(state.dpr, 0, 0, state.dpr, 0, 0);
}

function rand(min, max) {
  return min + Math.random() * (max - min);
}

function pick(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

function playBonusFanfare() {
  ensureAudio();
  if (!audioCtx) return;
  [392, 523.25, 659.25, 783.99, 1046.5].forEach((freq, i) => {
    const t = audioCtx.currentTime + i * 0.05;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = i % 2 ? "triangle" : "sine";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.2, t + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.28);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + 0.3);
  });
}

function playComboFanfare() {
  ensureAudio();
  if (!audioCtx) return;
  [261.63, 329.63, 392, 523.25, 659.25, 783.99].forEach((freq, i) => {
    const t = audioCtx.currentTime + i * 0.045;
    const osc = audioCtx.createOscillator();
    const gain = audioCtx.createGain();
    osc.type = "square";
    osc.frequency.value = freq;
    gain.gain.setValueAtTime(0.0001, t);
    gain.gain.exponentialRampToValueAtTime(0.12, t + 0.015);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.22);
    osc.connect(gain);
    gain.connect(audioCtx.destination);
    osc.start(t);
    osc.stop(t + 0.24);
  });
}

function playBoostBeat() {
  ensureAudio();
  if (!audioCtx) return;
  const t = audioCtx.currentTime;
  // kick
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "sine";
  osc.frequency.setValueAtTime(150, t);
  osc.frequency.exponentialRampToValueAtTime(45, t + 0.12);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.28, t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.17);

  // hi clap / spark
  const n = audioCtx.createOscillator();
  const ng = audioCtx.createGain();
  n.type = "triangle";
  n.frequency.value = 880 + Math.random() * 200;
  ng.gain.setValueAtTime(0.0001, t + 0.12);
  ng.gain.exponentialRampToValueAtTime(0.08, t + 0.13);
  ng.gain.exponentialRampToValueAtTime(0.0001, t + 0.22);
  n.connect(ng);
  ng.connect(audioCtx.destination);
  n.start(t + 0.12);
  n.stop(t + 0.23);
}

function startBoostMusic() {
  stopBoostMusic();
  playBoostBeat();
  boostMusicTimer = setInterval(() => {
    if (state.boostLeft > 0 && state.running && state.mode === "play") playBoostBeat();
    else stopBoostMusic();
  }, 280);
}

function stopBoostMusic() {
  if (boostMusicTimer) {
    clearInterval(boostMusicTimer);
    boostMusicTimer = null;
  }
}

function playSkullBuzz() {
  ensureAudio();
  if (!audioCtx) return;
  const t = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "sawtooth";
  osc.frequency.setValueAtTime(180, t);
  osc.frequency.exponentialRampToValueAtTime(70, t + 0.28);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.18, t + 0.02);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.32);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.34);
}

function spawnBalloon(forceBoostStyle = false) {
  const boosting = state.boostLeft > 0 || forceBoostStyle;
  const level = currentLevel();
  let color;
  // Kurukafa sadece BOOST sırasında çıksın
  if (boosting && Math.random() < 0.22) {
    color = COLORS.find((c) => c.skull);
  } else if (Math.random() < (boosting ? 0.1 : 0.16)) {
    color = COLORS.find((c) => c.gold);
  } else {
    color = pick(COLORS.filter((c) => !c.gold && !c.skull));
  }
  const r = color.gold || color.skull ? rand(42, 58) : rand(boosting ? 30 : 34, boosting ? 48 : 52);
  const speed =
    ((boosting ? rand(140, 240) : rand(55, 110)) + Math.min(40, state.score / 40)) * (level.speedMul || 1);
  state.balloons.push({
    x: rand(r + 10, state.width - r - 10),
    y: state.height + r + rand(10, boosting ? 40 : 80),
    r,
    vy: -speed,
    wobble: rand(0, Math.PI * 2),
    wobbleSpeed: rand(1.5, boosting ? 5 : 3.2),
    wobbleAmp: rand(12, 28),
    color,
    popped: false,
    scale: 1,
    pulse: rand(0, Math.PI * 2),
    birth: performance.now(),
  });
}

function burst(x, y, color, mega = false) {
  const count = mega ? 42 : 18;
  for (let i = 0; i < count; i++) {
    const angle = (Math.PI * 2 * i) / count + rand(-0.25, 0.25);
    const speed = mega ? rand(140, 420) : rand(90, 260);
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: mega ? rand(0.55, 1.05) : rand(0.35, 0.75),
      age: 0,
      size: mega ? rand(6, 14) : rand(4, 10),
      color: mega && Math.random() < 0.35 ? pick(["#ffd166", "#fff8ef", "#ff6b6b", "#ff9f68"]) : color,
      kind: mega && Math.random() < 0.45 ? "star" : "dot",
      spin: rand(0, Math.PI * 2),
      spinSpeed: rand(-10, 10),
    });
  }

  // confetti shards
  const shards = mega ? 28 : 10;
  for (let i = 0; i < shards; i++) {
    const angle = rand(0, Math.PI * 2);
    const speed = mega ? rand(120, 380) : rand(70, 200);
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed - rand(40, 120),
      life: mega ? rand(0.7, 1.2) : rand(0.4, 0.8),
      age: 0,
      size: mega ? rand(8, 16) : rand(5, 10),
      color: pick(["#ff6b6b", "#4ecdc4", "#ffd166", "#ff9f68", "#5bb8f0", "#f78fb3", "#fff8ef"]),
      kind: "shard",
      spin: rand(0, Math.PI * 2),
      spinSpeed: rand(-14, 14),
    });
  }

  state.rings.push({
    x,
    y,
    r: 8,
    max: mega ? 160 : 70,
    life: mega ? 0.7 : 0.4,
    age: 0,
    color: mega ? "#ffd166" : color,
    width: mega ? 10 : 5,
  });

  if (mega) {
    state.rings.push({
      x,
      y,
      r: 4,
      max: 220,
      life: 0.85,
      age: 0,
      color: "#fff8ef",
      width: 6,
    });
    state.rings.push({
      x,
      y,
      r: 2,
      max: 110,
      life: 0.5,
      age: 0,
      color: "#ff6b6b",
      width: 8,
    });
  }
}

function floatText(x, y, text, color = "#1f3a4d", opts = {}) {
  state.floatTexts.push({
    x,
    y,
    text,
    color,
    age: 0,
    life: opts.life || 0.9,
    size: opts.size || 22,
    bold: !!opts.bold,
    rise: opts.rise || 50,
    pop: !!opts.pop,
    stroke: opts.stroke || "rgba(31,58,77,0.25)",
  });
}

function popFillTip(text, color = "#fff8ef", opts = {}) {
  const f = state.fill;
  const x = state.width * 0.5 + (opts.jitter ? rand(-40, 40) : rand(-18, 18));
  const y = (f ? f.originY - 18 : state.height * 0.22) + (opts.yOff || 0);
  const mega = !!opts.mega;
  burst(x, y + 24, color, mega);
  burst(x, y + 24, "#ffd166", mega);
  if (mega) {
    state.rings.push({
      x,
      y: y + 24,
      r: 10,
      max: 150,
      life: 0.7,
      age: 0,
      color,
      width: 8,
    });
    state.flash = Math.max(state.flash, 0.28);
  } else {
    state.flash = Math.max(state.flash, 0.14);
  }
  floatText(x, y, text, color, {
    size: opts.size || (mega ? 38 : 30),
    bold: true,
    life: opts.life || (mega ? 1.55 : 1.25),
    rise: mega ? 90 : 68,
    pop: true,
    stroke: "rgba(31,58,77,0.4)",
  });
}

function showBanner(text, mode = "bonus") {
  const el = ui.bonusBanner;
  if (!el) return;
  if (ui.bannerText) ui.bannerText.textContent = text;
  el.classList.remove("combo-mode", "boost-mode");
  if (mode === "combo") el.classList.add("combo-mode");
  if (mode === "boost") el.classList.add("boost-mode");
  el.hidden = false;
  void el.offsetWidth;
  clearTimeout(showBanner._t);
  showBanner._t = setTimeout(() => {
    el.hidden = true;
    el.classList.remove("combo-mode", "boost-mode");
  }, 950);
}

function showBonusBanner() {
  showBanner("BONUS!", "bonus");
}

function bumpScore() {
  if (!ui.scorePill) return;
  ui.scorePill.classList.remove("pop");
  void ui.scorePill.offsetWidth;
  ui.scorePill.classList.add("pop");
}

function shakeScreen() {
  if (!ui.app) return;
  ui.app.classList.remove("shake");
  void ui.app.offsetWidth;
  ui.app.classList.add("shake");
}

function setBoosting(on) {
  if (ui.app) ui.app.classList.toggle("boosting", on);
  if (ui.boostOverlay) ui.boostOverlay.hidden = !on;
  if (on) startBoostMusic();
  else stopBoostMusic();
}

function triggerColorCombo(atX, atY, color) {
  state.flash = 0.45;
  shakeScreen();
  burst(atX, atY, color.fill, true);
  // ekstra renk fırtınası
  for (let i = 0; i < 3; i++) {
    setTimeout(() => {
      burst(
        atX + rand(-40, 40),
        atY + rand(-30, 30),
        color.fill,
        true
      );
    }, 80 * (i + 1));
  }
  showBanner("RENK KOMBO!", "combo");
  floatText(atX, atY - 30, "RENK KOMBO!", color.stroke, { size: 34, bold: true, life: 1.15, rise: 70 });
  playComboFanfare();
  haptic("heavy");

  // seriyi sıfırla, boost başlat
  state.colorStreak = 0;
  state.lastColor = null;
  state.streakColor = null;
  startBoost();
}

function startBoost() {
  const wasBoosting = state.boostLeft > 0;
  state.boostLeft = BOOST_DURATION;
  setBoosting(true);
  if (!wasBoosting) {
    showBanner("BOOST!", "boost");
    // hemen ekstra balon yağmuru
    for (let i = 0; i < 8; i++) spawnBalloon(true);
  }
}

function updateHud() {
  const level = currentLevel();
  ui.score.textContent = String(state.score);
  ui.time.textContent = isFillMode()
    ? `${(state.fill && state.fill.mapIndex + 1) || 1}/${FILL_LEVELS.length}`
    : String(Math.max(0, Math.ceil(state.timeLeft)));
  if (ui.level) ui.level.textContent = isLongcarPack() ? "Y" : String(level.id);

  if (state.running && state.boostLeft > 0) {
    ui.boostWrap.hidden = false;
    ui.boostTime.textContent = String(Math.ceil(state.boostLeft));
  } else {
    ui.boostWrap.hidden = true;
  }

  if (state.running && state.colorStreak > 0 && state.boostLeft <= 0 && !isHopMode()) {
    ui.streakWrap.hidden = false;
    ui.streak.textContent = `${state.colorStreak}/${COLOR_STREAK_NEED}`;
    if (ui.streakWrap && state.streakColor) {
      ui.streakWrap.style.boxShadow = `0 0 0 3px ${state.streakColor}55, 0 8px 20px var(--shadow)`;
    }
  } else {
    ui.streakWrap.hidden = true;
    if (ui.streakWrap) ui.streakWrap.style.boxShadow = "";
  }

  if (state.running && state.combo >= 2) {
    ui.comboWrap.hidden = false;
    ui.combo.textContent = `x${state.combo}`;
  } else {
    ui.comboWrap.hidden = true;
  }
}

function showScreen(name) {
  ui.home.hidden = name !== "home";
  ui.how.hidden = name !== "how";
  ui.pause.hidden = name !== "pause";
  ui.result.hidden = name !== "result";
  if (ui.quiz) ui.quiz.hidden = name !== "quiz";
  if (ui.levelIntro) ui.levelIntro.hidden = name !== "levelIntro";
  ui.hud.hidden = name !== "play";
  ui.btnPause.hidden = name !== "play";
  if (ui.btnFillRestart && name !== "play") ui.btnFillRestart.hidden = true;
  state.mode = name;
  if (name !== "quiz") stopSpeak();
}

function startBalloonGame() {
  ensureAudio();
  stopBoostMusic();
  stopSpeak();
  state.pack = "balloon";
  state.score = 0;
  state.usedQuizIds = [];
  state.levelIndex = 0;
  state.pendingLevelIndex = 0;
  state.fillMapIndex = 0;
  state.fillStuckCount = 0;
  setBoosting(false);
  startLevel(0, true);
}

function startLongcarGame() {
  ensureAudio();
  stopBoostMusic();
  stopSpeak();
  state.pack = "longcar";
  state.score = 0;
  state.usedQuizIds = [];
  state.levelIndex = 0;
  state.pendingLevelIndex = 0;
  state.fillMapIndex = 0;
  state.fillStuckCount = 0;
  state.fillFacing = { dc: 1, dr: 0 };
  setBoosting(false);
  startLevel(0, true);
  showBanner("LONGCAR!", "combo");
  speak("Longcar. Tesla Model Y ile Longcat gibi uzat, yolu doldur!");
}

/** @deprecated use startBalloonGame */
function startGame() {
  startBalloonGame();
}

function startLevel(levelIndex, fromMenu = false) {
  const levels = activeLevels();
  const level = levels[levelIndex];
  if (!level) {
    finishRun();
    return;
  }
  ensureAudio();
  stopBoostMusic();
  state.levelIndex = levelIndex;
  state.running = true;
  state.combo = 0;
  state.comboTimer = 0;
  state.colorStreak = 0;
  state.lastColor = null;
  state.streakColor = null;
  state.boostLeft = 0;
  state.timeLeft = level.time;
  state.spawnTimer = 0;
  state.balloons = [];
  state.particles = [];
  state.rings = [];
  state.floatTexts = [];
  state.flash = 0;
  state.bonusTimer = 0;
  state.beatT = 0;
  state.lastTs = performance.now();
  if (ui.bonusBanner) ui.bonusBanner.hidden = true;
  setBoosting(false);
  showScreen("play");
  updateHud();
  showBanner(level.name, "boost");
  if (!fromMenu) speak(`${level.name}. ${level.desc}`);
  if (level.mode === "hop") {
    initHopMode();
    state.drive = null;
    state.fill = null;
  } else if (level.mode === "drive") {
    state.hop = null;
    state.fill = null;
    initDriveMode();
  } else if (level.mode === "fill") {
    state.hop = null;
    state.drive = null;
    if (state.fillMapIndex == null) state.fillMapIndex = 0;
    initFillMode();
  } else {
    state.hop = null;
    state.drive = null;
    state.fill = null;
    for (let i = 0; i < (levelIndex === 0 ? 5 : 7); i++) spawnBalloon();
  }
}

function completeLevel() {
  state.running = false;
  state.boostLeft = 0;
  setBoosting(false);
  stopBoostMusic();
  state.balloons = [];
  state.hop = null;
  state.drive = null;
  state.fill = null;

  const finishedId = currentLevel().id;
  const nextIndex = state.levelIndex + 1;

  if (nextIndex >= activeLevels().length) {
    finishRun();
    return;
  }

  // Longcar'te quiz yok — haritalar fill içinde akar
  if (isLongcarPack()) {
    finishRun();
    return;
  }

  // Sonraki seviyeye geçmek için akıl sorusu
  state.pendingLevelIndex = nextIndex;
  openQuiz(finishedId);
}

function openQuiz(afterLevelId) {
  const quiz = pickQuiz(afterLevelId);
  state.currentQuiz = quiz;
  state.usedQuizIds.push(quiz.id);

  ui.quizStage.textContent = `${afterLevelId}. Aşama Tamam!`;
  ui.quizTitle.textContent = "Akıl Sorusu";
  ui.quizQuestion.textContent = quiz.question;
  ui.quizVisual.innerHTML = quiz.visual;
  ui.quizFeedback.hidden = true;
  ui.quizFeedback.classList.remove("ok");
  ui.quizChoices.innerHTML = "";

  const shuffled = [...quiz.choices].sort(() => Math.random() - 0.5);
  shuffled.forEach((choice) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "quiz-choice visual-choice";
    btn.setAttribute("aria-label", choice.text);
    btn.innerHTML = `
      <span class="choice-visual">${choice.visual || ""}</span>
      <span class="choice-sr">${choice.text}</span>
    `;
    btn.addEventListener("click", () => answerQuiz(choice, btn));
    ui.quizChoices.appendChild(btn);
  });

  showScreen("quiz");
  setTimeout(() => speak(`${afterLevelId}. aşama tamam. ${quiz.speak}`), 250);
}

function answerQuiz(choice, btn) {
  const buttons = [...ui.quizChoices.querySelectorAll(".quiz-choice")];
  buttons.forEach((b) => {
    b.disabled = true;
  });

  if (choice.correct) {
    btn.classList.add("correct");
    ui.quizFeedback.hidden = false;
    ui.quizFeedback.classList.add("ok");
    ui.quizFeedback.textContent = "Doğru! Sonraki seviyeye geçiyoruz.";
    playCheer();
    speak("Doğru cevap! Sonraki seviyeye geçiyoruz.");
    setTimeout(() => showLevelIntro(state.pendingLevelIndex), 1400);
  } else {
    btn.classList.add("wrong");
    const correctBtn = buttons.find((b) => {
      const label = b.getAttribute("aria-label");
      return state.currentQuiz.choices.some((c) => c.correct && c.text === label);
    });
    if (correctBtn) correctBtn.classList.add("correct");
    ui.quizFeedback.hidden = false;
    ui.quizFeedback.classList.remove("ok");
    ui.quizFeedback.textContent = "Tekrar dene! Soruyu dinle ve görsele bak.";
    speak("Bu olmadı. Tekrar dene. Soruyu dinle ve görsele bak.");
    setTimeout(() => {
      openQuiz(currentLevel().id);
    }, 1600);
  }
}

function showLevelIntro(levelIndex) {
  const level = activeLevels()[levelIndex];
  if (!level) {
    finishRun();
    return;
  }
  ui.introEyebrow.textContent = level.label;
  ui.introTitle.textContent = level.name;
  ui.introText.textContent = level.desc;
  showScreen("levelIntro");
  speak(`${level.name}. ${level.desc}. Başla demen yeterli.`);
}

function finishRun() {
  state.running = false;
  state.boostLeft = 0;
  setBoosting(false);
  stopBoostMusic();
  stopSpeak();
  let isNewBest = false;
  if (isLongcarPack()) {
    isNewBest = state.score > state.bestLongcar;
    if (isNewBest) {
      state.bestLongcar = state.score;
      localStorage.setItem(STORAGE_KEY_LONGCAR, String(state.bestLongcar));
    }
  } else {
    isNewBest = state.score > state.best;
    if (isNewBest) {
      state.best = state.score;
      localStorage.setItem(STORAGE_KEY, String(state.best));
    }
  }
  ui.finalScore.textContent = String(state.score);
  updateHomeBest();
  if (isLongcarPack()) {
    if (state.score >= 600) {
      ui.resultTitle.textContent = "Şarj Şampiyonu!";
      ui.resultEmoji.textContent = "⚡";
    } else if (state.score >= 300) {
      ui.resultTitle.textContent = "Harika Sürüş!";
      ui.resultEmoji.textContent = "🚗";
    } else {
      ui.resultTitle.textContent = "İyi yol!";
      ui.resultEmoji.textContent = "🔋";
    }
    ui.resultBest.textContent = isNewBest
      ? "Yeni Longcar rekoru!"
      : `Longcar en iyi: ${state.bestLongcar}`;
  } else if (state.score >= 900) {
    ui.resultTitle.textContent = "Şampiyon!";
    ui.resultEmoji.textContent = "🏆";
    ui.resultBest.textContent = isNewBest ? "Yeni rekor kırdın!" : `En iyi skor: ${state.best}`;
  } else if (state.score >= 500) {
    ui.resultTitle.textContent = "Harika!";
    ui.resultEmoji.textContent = "🎉";
    ui.resultBest.textContent = isNewBest ? "Yeni rekor kırdın!" : `En iyi skor: ${state.best}`;
  } else {
    ui.resultTitle.textContent = "İyi iş!";
    ui.resultEmoji.textContent = "🎈";
    ui.resultBest.textContent = isNewBest ? "Yeni rekor kırdın!" : `En iyi skor: ${state.best}`;
  }
  showScreen("result");
  playCheer();
  speak(isNewBest ? `Tebrikler! Yeni rekorun ${state.score}` : `Skorun ${state.score}. Tekrar oynamak ister misin?`);
  haptic("heavy");
}

function endGame() {
  // seviye süresi bittiğinde
  completeLevel();
}

function popBalloon(b) {
  if (b.popped) return;
  b.popped = true;
  const isBonus = !!b.color.gold;
  const isSkull = !!b.color.skull;
  const boosting = state.boostLeft > 0;

  if (isSkull) {
    const lost = Math.abs(b.color.points);
    state.score = Math.max(0, state.score - lost);
    state.combo = 0;
    state.comboTimer = 0;
    state.colorStreak = 0;
    state.lastColor = null;
    state.streakColor = null;
    dramaticSkullBurst(b.x, b.y);
    floatText(b.x, b.y - b.r - 8, "☠", "#fff", { size: 52, bold: true, life: 1.15, rise: 75 });
    floatText(b.x, b.y + 12, `-${lost}`, "#ff6b6b", { size: 34, bold: true, life: 1.1, rise: 55 });
    playMusicGlitch();
    playSkullBuzz();
    haptic("heavy");
    bumpScore();
    // Boost'ta kurukafaya basınca boost biraz bozulur
    if (state.boostLeft > 0) state.boostLeft = Math.max(0, state.boostLeft - 2.5);
    updateHud();
    return;
  }

  const base = b.color.points;
  state.comboTimer = boosting ? 1.4 : 1.1;
  state.combo += 1;
  const mult = Math.min(5, 1 + Math.floor((state.combo - 1) / 2));
  const bonusExtra = isBonus ? 25 : 0;
  let gained = (base * mult + bonusExtra) * (boosting ? BOOST_SCORE_MULT : 1);
  gained = Math.round(gained);
  state.score += gained;

  burst(b.x, b.y, b.color.fill, isBonus || boosting);
  bumpScore();

  // Aynı renk serisi (altın seriyi bozmaz)
  let triggeredColorCombo = false;
  if (!isBonus) {
    if (state.lastColor === b.color.fill) {
      state.colorStreak += 1;
    } else {
      state.colorStreak = 1;
      state.lastColor = b.color.fill;
    }
    state.streakColor = b.color.fill;
    if (state.colorStreak >= COLOR_STREAK_NEED && !boosting) {
      triggeredColorCombo = true;
      triggerColorCombo(b.x, b.y, b.color);
    }
  }

  if (triggeredColorCombo) {
    floatText(b.x, b.y + 18, `+${gained}`, "#fff8ef", { size: 26, bold: true, life: 0.9, rise: 50 });
  } else if (isBonus) {
    state.flash = Math.max(state.flash, 0.35);
    state.bonusTimer = 0.9;
    showBonusBanner();
    shakeScreen();
    floatText(b.x, b.y - b.r - 10, "BONUS!", "#c48a00", { size: 36, bold: true, life: 1.1, rise: 70 });
    floatText(b.x, b.y + 8, `+${gained}`, "#fff8ef", { size: 28, bold: true, life: 1, rise: 55 });
    playBonusFanfare();
    haptic("heavy");
  } else if (boosting) {
    floatText(b.x, b.y - b.r, `+${gained}`, "#fff8ef", { size: 28, bold: true, life: 0.7, rise: 70 });
    playPop(1.2 + Math.random() * 0.5);
    haptic("light");
  } else {
    const streakLabel = state.colorStreak > 1 ? ` ${state.colorStreak}/${COLOR_STREAK_NEED}` : "";
    floatText(
      b.x,
      b.y - b.r,
      (mult > 1 ? `+${gained} x${mult}` : `+${gained}`) + streakLabel,
      state.colorStreak > 1 ? b.color.stroke : "#1f3a4d",
      { size: mult > 1 || state.colorStreak > 1 ? 24 : 22, bold: mult > 1 || state.colorStreak > 1, life: 0.85, rise: 55 }
    );
    playPop(0.9 + Math.random() * 0.4);
    haptic("medium");
  }
  updateHud();
}

function hitTest(x, y) {
  for (let i = state.balloons.length - 1; i >= 0; i--) {
    const b = state.balloons[i];
    if (b.popped) continue;
    const dx = x - b.x;
    const dy = y - (b.y - b.r * 0.15);
    if (dx * dx + dy * dy <= (b.r * 1.15) * (b.r * 1.15)) return b;
  }
  return null;
}

function drawBackground(dt) {
  const boosting = state.boostLeft > 0 && state.mode === "play";
  const beat = boosting ? 0.5 + 0.5 * Math.sin(state.beatT * Math.PI * 2 * 3.4) : 0;

  const g = ctx.createLinearGradient(0, 0, 0, state.height);
  if (boosting) {
    g.addColorStop(0, "#ff9aa8");
    g.addColorStop(0.35, "#7ec8f8");
    g.addColorStop(0.7, "#ffd166");
    g.addColorStop(1, "#ffe8b0");
  } else {
    g.addColorStop(0, "#9ad7ff");
    g.addColorStop(0.55, "#7ec8f8");
    g.addColorStop(1, "#ffe8b0");
  }
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, state.width, state.height);

  if (boosting) {
    const pulse = ctx.createRadialGradient(
      state.width * 0.5,
      state.height * 0.4,
      10,
      state.width * 0.5,
      state.height * 0.4,
      180 + beat * 80
    );
    pulse.addColorStop(0, `rgba(255,248,239,${0.22 + beat * 0.2})`);
    pulse.addColorStop(1, "rgba(255,248,239,0)");
    ctx.fillStyle = pulse;
    ctx.fillRect(0, 0, state.width, state.height);
  }

  // soft sun during play
  if (state.mode === "play" || state.mode === "pause" || state.mode === "result") {
    const sx = state.width * 0.82;
    const sy = state.height * 0.12;
    const sun = ctx.createRadialGradient(sx, sy, 8, sx, sy, 70 + beat * 20);
    sun.addColorStop(0, "rgba(255, 247, 194, 0.95)");
    sun.addColorStop(0.5, "rgba(255, 209, 102, 0.75)");
    sun.addColorStop(1, "rgba(255, 209, 102, 0)");
    ctx.fillStyle = sun;
    ctx.beginPath();
    ctx.arc(sx, sy, 70 + beat * 20, 0, Math.PI * 2);
    ctx.fill();
  }

  state.hillsOffset = (state.hillsOffset + dt * (boosting ? 28 : 8)) % state.width;
  drawHills(state.height * 0.78, "#8fd48f", 38, 0);
  drawHills(state.height * 0.84, "#6bcb6f", 48, 40);
  drawHills(state.height * 0.9, "#57b35c", 56, 80);

  ctx.fillStyle = "#4aa352";
  ctx.fillRect(0, state.height * 0.94, state.width, state.height * 0.06);
}

function drawHills(baseY, color, amp, phase) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(0, state.height);
  for (let x = 0; x <= state.width; x += 12) {
    const y = baseY + Math.sin((x + phase) * 0.01) * amp * 0.35 + Math.sin((x + phase) * 0.025) * amp * 0.2;
    ctx.lineTo(x, y);
  }
  ctx.lineTo(state.width, state.height);
  ctx.closePath();
  ctx.fill();
}

function drawBalloon(b) {
  const pulse = b.color.gold || b.color.skull ? 1 + Math.sin(b.pulse) * 0.08 : 1;
  const x = b.x + Math.sin(b.wobble) * b.wobbleAmp * 0.15;
  const y = b.y;
  const r = b.r * b.scale * pulse;

  if (b.color.gold && !b.popped) {
    const glow = ctx.createRadialGradient(x, y, r * 0.2, x, y, r * 1.7);
    glow.addColorStop(0, "rgba(255, 209, 102, 0.55)");
    glow.addColorStop(0.55, "rgba(255, 159, 104, 0.2)");
    glow.addColorStop(1, "rgba(255, 209, 102, 0)");
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(x, y, r * 1.7, 0, Math.PI * 2);
    ctx.fill();
  }

  if (b.color.skull && !b.popped) {
    const glow = ctx.createRadialGradient(x, y, r * 0.2, x, y, r * 1.6);
    glow.addColorStop(0, "rgba(99, 110, 114, 0.45)");
    glow.addColorStop(0.55, "rgba(45, 52, 54, 0.25)");
    glow.addColorStop(1, "rgba(0, 0, 0, 0)");
    ctx.fillStyle = glow;
    ctx.beginPath();
    ctx.arc(x, y, r * 1.6, 0, Math.PI * 2);
    ctx.fill();
  }

  // string
  ctx.strokeStyle = b.color.skull ? "rgba(0,0,0,0.45)" : "rgba(31,58,77,0.35)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(x, y + r * 0.9);
  ctx.quadraticCurveTo(x + 6, y + r * 1.4, x - 2, y + r * 1.85);
  ctx.stroke();

  // body
  const grad = ctx.createRadialGradient(x - r * 0.3, y - r * 0.35, r * 0.1, x, y, r);
  if (b.color.skull) {
    grad.addColorStop(0, "#636e72");
    grad.addColorStop(0.35, b.color.fill);
    grad.addColorStop(1, b.color.stroke);
  } else {
    grad.addColorStop(0, "#ffffff");
    grad.addColorStop(0.18, b.color.fill);
    grad.addColorStop(1, b.color.stroke);
  }
  ctx.fillStyle = grad;
  ctx.beginPath();
  ctx.ellipse(x, y, r * 0.86, r, 0, 0, Math.PI * 2);
  ctx.fill();

  // knot
  ctx.fillStyle = b.color.stroke;
  ctx.beginPath();
  ctx.moveTo(x, y + r * 0.88);
  ctx.lineTo(x - 6, y + r * 1.08);
  ctx.lineTo(x + 6, y + r * 1.08);
  ctx.closePath();
  ctx.fill();

  // shine
  ctx.fillStyle = b.color.skull ? "rgba(255,255,255,0.2)" : "rgba(255,255,255,0.55)";
  ctx.beginPath();
  ctx.ellipse(x - r * 0.28, y - r * 0.35, r * 0.18, r * 0.28, -0.5, 0, Math.PI * 2);
  ctx.fill();

  if (b.color.gold) {
    ctx.fillStyle = "rgba(255,255,255,0.9)";
    ctx.font = `700 ${Math.floor(r * 0.72)}px Fredoka, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("★", x, y);
    for (let i = 0; i < 3; i++) {
      const a = b.pulse * 1.8 + (i * Math.PI * 2) / 3;
      const sx = x + Math.cos(a) * r * 1.15;
      const sy = y + Math.sin(a) * r * 0.9;
      ctx.fillStyle = `rgba(255,248,239,${0.55 + Math.sin(b.pulse + i) * 0.35})`;
      ctx.beginPath();
      ctx.arc(sx, sy, 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  if (b.color.skull) {
    ctx.fillStyle = "#dfe6e9";
    ctx.font = `700 ${Math.floor(r * 0.78)}px Fredoka, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("☠", x, y + r * 0.05);
  }
}

function drawStar(x, y, size, rotation) {
  ctx.save();
  ctx.translate(x, y);
  ctx.rotate(rotation);
  ctx.beginPath();
  for (let i = 0; i < 5; i++) {
    const a = (i * Math.PI * 2) / 5 - Math.PI / 2;
    const a2 = a + Math.PI / 5;
    ctx.lineTo(Math.cos(a) * size, Math.sin(a) * size);
    ctx.lineTo(Math.cos(a2) * size * 0.45, Math.sin(a2) * size * 0.45);
  }
  ctx.closePath();
  ctx.fill();
  ctx.restore();
}

function drawParticles() {
  for (const p of state.particles) {
    const alpha = 1 - p.age / p.life;
    ctx.globalAlpha = Math.max(0, alpha);
    ctx.fillStyle = p.color;
    if (p.kind === "star") {
      drawStar(p.x, p.y, p.size, p.spin);
    } else if (p.kind === "shard") {
      ctx.save();
      ctx.translate(p.x, p.y);
      ctx.rotate(p.spin);
      ctx.fillRect(-p.size * 0.25, -p.size * 0.6, p.size * 0.5, p.size * 1.2);
      ctx.restore();
    } else {
      ctx.beginPath();
      ctx.arc(p.x, p.y, p.size * (0.7 + alpha * 0.3), 0, Math.PI * 2);
      ctx.fill();
    }
  }
  ctx.globalAlpha = 1;
}

function drawRings() {
  for (const ring of state.rings) {
    const t = ring.age / ring.life;
    const alpha = Math.max(0, 1 - t);
    ctx.globalAlpha = alpha;
    ctx.strokeStyle = ring.color;
    ctx.lineWidth = Math.max(1, ring.width * (1 - t * 0.7));
    ctx.beginPath();
    ctx.arc(ring.x, ring.y, ring.r, 0, Math.PI * 2);
    ctx.stroke();
  }
  ctx.globalAlpha = 1;
}

function drawFloatTexts() {
  for (const t of state.floatTexts) {
    const p = t.age / t.life;
    const alpha = p < 0.12 ? p / 0.12 : Math.max(0, 1 - (p - 0.12) / 0.88);
    let scale;
    if (t.pop) {
      scale = p < 0.18 ? 0.2 + (p / 0.18) * 1.15 : p < 0.35 ? 1.35 - ((p - 0.18) / 0.17) * 0.25 : 1.05;
    } else {
      scale = p < 0.2 ? 0.6 + (p / 0.2) * 0.55 : 1.05 - (p - 0.2) * 0.15;
    }
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(t.x, t.y);
    ctx.scale(scale, scale);
    ctx.rotate(t.pop ? Math.sin(p * 12) * 0.04 : 0);
    ctx.fillStyle = t.color;
    ctx.strokeStyle = t.stroke || "rgba(31,58,77,0.25)";
    ctx.lineWidth = t.pop ? 6 : 4;
    ctx.font = `${t.bold ? 900 : 800} ${t.size}px Fredoka, Nunito, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    if (t.bold || t.pop) ctx.strokeText(t.text, 0, 0);
    ctx.fillText(t.text, 0, 0);
    ctx.restore();
  }
  ctx.globalAlpha = 1;
}

function drawFlash() {
  if (state.flash <= 0) return;
  const a = Math.min(1, state.flash * 2.2);
  const g = ctx.createRadialGradient(
    state.width * 0.5,
    state.height * 0.42,
    20,
    state.width * 0.5,
    state.height * 0.42,
    Math.max(state.width, state.height) * 0.7
  );
  g.addColorStop(0, `rgba(255, 248, 239, ${0.55 * a})`);
  g.addColorStop(0.45, `rgba(255, 209, 102, ${0.28 * a})`);
  g.addColorStop(1, `rgba(255, 107, 107, 0)`);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, state.width, state.height);
}

function update(dt) {
  if (state.flash > 0) state.flash = Math.max(0, state.flash - dt);
  if (state.bonusTimer > 0) state.bonusTimer = Math.max(0, state.bonusTimer - dt);
  state.beatT += dt;

  if (!state.running) {
    if (state.mode === "home") {
      state.spawnTimer -= dt;
      if (state.spawnTimer <= 0 && state.balloons.length < 8) {
        spawnBalloon();
        state.spawnTimer = rand(0.4, 1.1);
      }
    }
  } else if (isHopMode()) {
    updateHop(dt);
  } else if (isDriveMode()) {
    updateDrive(dt);
  } else if (isFillMode()) {
    updateFill(dt);
  } else {
    // Boost sırasında ana süre dondurulur
    if (state.boostLeft > 0) {
      state.boostLeft -= dt;
      if (state.boostLeft <= 0) {
        state.boostLeft = 0;
        setBoosting(false);
        showBanner("BOOST BİTTİ", "bonus");
      }
    } else {
      state.timeLeft -= dt;
      if (state.timeLeft <= 0) {
        state.timeLeft = 0;
        updateHud();
        endGame();
        return;
      }
    }

    state.comboTimer -= dt;
    if (state.comboTimer <= 0) state.combo = 0;

    const boosting = state.boostLeft > 0;
    const level = currentLevel();
    const spawnRate = boosting
      ? 0.12
      : Math.max(0.2, (level.spawnBase || 0.5) - state.score / 1600);
    state.spawnTimer -= dt;
    if (state.spawnTimer <= 0) {
      spawnBalloon();
      if (boosting || Math.random() < 0.35 + level.id * 0.08) spawnBalloon();
      if (boosting && Math.random() < 0.55) spawnBalloon();
      if (!boosting && level.id >= 3 && Math.random() < 0.25) spawnBalloon();
      state.spawnTimer = spawnRate;
    }
    updateHud();
  }

  for (const b of state.balloons) {
    if (b.popped) {
      b.scale *= 0.78;
      continue;
    }
    b.wobble += b.wobbleSpeed * dt;
    b.pulse = (b.pulse || 0) + dt * (b.color.gold || b.color.skull ? 6 : 3);
    b.x += Math.sin(b.wobble) * b.wobbleAmp * dt;
    if (b.driveMode) {
      b.y += b.vy * dt * (state.boostLeft > 0 ? 1.25 : 1);
    } else {
      b.y += b.vy * dt * (state.boostLeft > 0 ? 1.15 : 1);
    }
  }

  state.balloons = state.balloons.filter((b) => {
    if (b.popped) return b.scale > 0.08;
    if (b.driveMode) return b.y - b.r < state.height + 60;
    return b.y + b.r > -40;
  });

  for (const p of state.particles) {
    p.age += dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vy += (p.kind === "shard" ? 360 : 280) * dt;
    p.vx *= 0.99;
    if (p.spinSpeed) p.spin += p.spinSpeed * dt;
  }
  state.particles = state.particles.filter((p) => p.age < p.life);

  for (const ring of state.rings) {
    ring.age += dt;
    const t = Math.min(1, ring.age / ring.life);
    ring.r = ring.max * (0.15 + t * 0.85);
  }
  state.rings = state.rings.filter((r) => r.age < r.life);

  for (const t of state.floatTexts) {
    t.age += dt;
    t.y -= (t.rise || 45) * dt;
  }
  state.floatTexts = state.floatTexts.filter((t) => t.age < t.life);
}

function frame(ts) {
  const dt = Math.min(0.033, (ts - state.lastTs) / 1000 || 0.016);
  state.lastTs = ts;
  if (state.mode !== "pause") update(dt);

  if (state.mode === "play" && isHopMode()) {
    drawHopWorld();
  } else if (state.mode === "play" && isDriveMode()) {
    drawDriveWorld(dt);
    for (const b of state.balloons) drawBalloon(b);
    if (state.drive) drawTesla(state.drive.carX, state.drive.carY, state.drive.steer);
  } else if (state.mode === "play" && isFillMode()) {
    drawFillWorld();
  } else {
    drawBackground(dt);
    for (const b of state.balloons) drawBalloon(b);
  }
  drawRings();
  drawParticles();
  drawFloatTexts();
  drawFlash();
  requestAnimationFrame(frame);
}

function pointerPos(e) {
  if (e.touches && e.touches[0]) {
    return { x: e.touches[0].clientX, y: e.touches[0].clientY };
  }
  return { x: e.clientX, y: e.clientY };
}

function onPointer(e) {
  if (state.mode !== "play" || !state.running) return;
  e.preventDefault();
  const { x, y } = pointerPos(e);
  if (isFillMode()) {
    state.swipe = { x, y };
    handleFillPointer(x, y);
    return;
  }
  if (isHopMode()) {
    const tile = hopHitTest(x, y);
    if (!tile) return;
    if (tile.kind === "skull") onHopSkull(tile);
    else onHopSuccess(tile);
    return;
  }
  if (isDriveMode()) {
    if (state.drive) {
      state.drive.targetX = x;
      state.drive.pointerActive = true;
    }
    return;
  }
  const hit = hitTest(x, y);
  if (hit) popBalloon(hit, x, y);
}

function onPointerMove(e) {
  if (state.mode !== "play" || !state.running) return;
  if (isDriveMode() && state.drive) {
    const { x } = pointerPos(e);
    state.drive.targetX = x;
  }
}

function onPointerUp(e) {
  if (state.drive) state.drive.pointerActive = false;
  if (!isFillMode() || !state.swipe || !state.running || state.mode !== "play") {
    state.swipe = null;
    return;
  }
  const { x, y } = pointerPos(e.changedTouches ? e : e);
  // touchend may need changedTouches
  let ux = x;
  let uy = y;
  if (e.changedTouches && e.changedTouches[0]) {
    ux = e.changedTouches[0].clientX;
    uy = e.changedTouches[0].clientY;
  } else if (e.clientX != null) {
    ux = e.clientX;
    uy = e.clientY;
  }
  const dx = ux - state.swipe.x;
  const dy = uy - state.swipe.y;
  state.swipe = null;
  if (Math.hypot(dx, dy) < 28) return;
  if (Math.abs(dx) > Math.abs(dy)) tryFillMove(dx > 0 ? 1 : -1, 0);
  else tryFillMove(0, dy > 0 ? 1 : -1);
}

function bindUi() {
  updateHomeBest();

  ui.btnPlay.addEventListener("click", () => startBalloonGame());
  if (ui.btnLongcar) ui.btnLongcar.addEventListener("click", () => startLongcarGame());
  ui.btnHow.addEventListener("click", () => showScreen("how"));
  ui.btnHowClose.addEventListener("click", () => showScreen("home"));
  ui.btnPause.addEventListener("click", () => {
    if (!state.running) return;
    state.running = false;
    stopBoostMusic();
    showScreen("pause");
  });
  if (ui.btnFillRestart) {
    ui.btnFillRestart.addEventListener("click", () => {
      if (!isFillMode()) return;
      playPop(0.9);
      const hadStuck = (state.fillStuckCount || 0) > 0;
      initFillMode();
      showBanner(hadStuck ? "İPUCU!" : "YENİDEN!", hadStuck ? "boost" : "bonus");
      if (!hadStuck) speak("Yeniden başlıyoruz.");
    });
  }
  ui.btnResume.addEventListener("click", () => {
    state.running = true;
    state.lastTs = performance.now();
    if (state.boostLeft > 0) setBoosting(true);
    showScreen("play");
  });
  ui.btnQuit.addEventListener("click", () => {
    state.running = false;
    state.boostLeft = 0;
    setBoosting(false);
    stopSpeak();
    state.balloons = [];
    showScreen("home");
    updateHomeBest();
  });
  ui.btnAgain.addEventListener("click", () => {
    if (isLongcarPack()) startLongcarGame();
    else startBalloonGame();
  });
  ui.btnHome.addEventListener("click", () => {
    state.boostLeft = 0;
    setBoosting(false);
    stopSpeak();
    state.balloons = [];
    showScreen("home");
    updateHomeBest();
  });
  if (ui.btnSpeak) {
    ui.btnSpeak.addEventListener("click", () => {
      if (state.currentQuiz) speak(state.currentQuiz.speak);
    });
  }
  if (ui.btnStartLevel) {
    ui.btnStartLevel.addEventListener("click", () => {
      startLevel(state.pendingLevelIndex);
    });
  }

  canvas.addEventListener("pointerdown", onPointer, { passive: false });
  canvas.addEventListener("touchstart", onPointer, { passive: false });
  canvas.addEventListener("pointermove", onPointerMove, { passive: false });
  canvas.addEventListener("touchmove", (e) => {
    if (state.mode !== "play" || !isDriveMode()) return;
    e.preventDefault();
    onPointerMove(e);
  }, { passive: false });
  window.addEventListener("pointerup", onPointerUp);
  window.addEventListener("touchend", onPointerUp);
}

function setupNative() {
  const plugins = window.Capacitor?.Plugins;
  if (plugins?.StatusBar) {
    plugins.StatusBar.setStyle?.({ style: "LIGHT" });
    plugins.StatusBar.setBackgroundColor?.({ color: "#7EC8F8" });
  }
  if (plugins?.App?.addListener) {
    plugins.App.addListener("backButton", ({ canGoBack }) => {
      if (state.mode === "play") {
        state.running = false;
        stopBoostMusic();
        showScreen("pause");
      } else if (state.mode === "quiz") {
        // quiz sırasında geri = ana menü
        stopSpeak();
        showScreen("home");
      } else if (state.mode === "levelIntro") {
        startLevel(state.pendingLevelIndex);
      } else if (state.mode === "pause" || state.mode === "how" || state.mode === "result") {
        state.running = false;
        state.balloons = [];
        stopSpeak();
        showScreen("home");
      } else if (!canGoBack) {
        plugins.App.exitApp?.();
      }
    });
  }
}

resize();
bindUi();
showScreen("home");
for (let i = 0; i < 6; i++) spawnBalloon();
requestAnimationFrame(frame);
setupNative();
if (window.speechSynthesis) {
  window.speechSynthesis.getVoices();
  window.speechSynthesis.addEventListener("voiceschanged", () => {
    window.speechSynthesis.getVoices();
  });
}
window.addEventListener("resize", resize);
window.addEventListener("orientationchange", () => setTimeout(resize, 120));
