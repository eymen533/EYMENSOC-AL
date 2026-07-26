const STORAGE_KEY = "balonPatlatBest";
const COLOR_STREAK_NEED = 3;
const BOOST_DURATION = 10; // hızlı müzik/boost modu (sn)
const BOOST_SCORE_MULT = 3;

const LEVELS = [
  {
    id: 1,
    name: "Seviye 1",
    time: 45,
    mode: "balloons",
    spawnBase: 0.85,
    speedMul: 1,
    label: "Isınma",
    desc: "Balonları patlat! Kurukafalılara basma!",
  },
  {
    id: 2,
    name: "Seviye 2",
    time: 45,
    mode: "hop",
    label: "Tiles Hop",
    desc: "Karolara dokun, müzikle ileri zıpla!",
  },
  {
    id: 3,
    name: "Seviye 3",
    time: 55,
    mode: "balloons",
    spawnBase: 0.36,
    speedMul: 1.55,
    label: "Şampiyonluk",
    desc: "Son seviye! En yüksek skoru yakala!",
  },
];

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
  btnHow: $("btnHow"),
  btnHowClose: $("btnHowClose"),
  btnPause: $("btnPause"),
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
  hillsOffset: 0,
  flash: 0,
  bonusTimer: 0,
  beatT: 0,
  hop: null,
};

let audioCtx = null;
let boostMusicTimer = null;

function currentLevel() {
  return LEVELS[state.levelIndex] || LEVELS[0];
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

function playHopBeat(intensity = 1) {
  ensureAudio();
  if (!audioCtx) return;
  const t = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "sine";
  osc.frequency.setValueAtTime(160 * intensity, t);
  osc.frequency.exponentialRampToValueAtTime(50, t + 0.1);
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.26 * Math.min(1.4, intensity), t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.14);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.15);

  const hat = audioCtx.createOscillator();
  const hg = audioCtx.createGain();
  hat.type = "triangle";
  hat.frequency.value = 900 + Math.random() * 400;
  hg.gain.setValueAtTime(0.0001, t + 0.08);
  hg.gain.exponentialRampToValueAtTime(0.07, t + 0.09);
  hg.gain.exponentialRampToValueAtTime(0.0001, t + 0.16);
  hat.connect(hg);
  hg.connect(audioCtx.destination);
  hat.start(t + 0.08);
  hat.stop(t + 0.17);
}

function playHopMelody() {
  ensureAudio();
  if (!audioCtx) return;
  const notes = [523.25, 659.25, 783.99, 659.25];
  const hop = state.hop;
  const idx = hop ? hop.melodyStep % notes.length : 0;
  if (hop) hop.melodyStep += 1;
  const t = audioCtx.currentTime;
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = "square";
  osc.frequency.value = notes[idx];
  gain.gain.setValueAtTime(0.0001, t);
  gain.gain.exponentialRampToValueAtTime(0.08, t + 0.01);
  gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.18);
  osc.connect(gain);
  gain.connect(audioCtx.destination);
  osc.start(t);
  osc.stop(t + 0.2);
}

function projectHop(lane, z) {
  const depth = 1 / (1 + z * 0.42);
  const nearY = state.height * 0.78;
  const farY = state.height * 0.2;
  const y = farY + (nearY - farY) * depth;
  const laneSpread = Math.min(state.width * 0.28, 120) * depth;
  const x = state.width * 0.5 + (lane - 1) * laneSpread;
  const radius = Math.max(14, 46 * depth);
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
    id: `${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
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
  let z = 1.2;
  let lane = 1;
  for (let i = 0; i < 16; i++) {
    if (i > 0 && Math.random() < 0.45) {
      lane = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
    }
    let kind = "normal";
    if (i > 3 && Math.random() < 0.12) kind = "skull";
    else if (i > 2 && Math.random() < 0.1) kind = "gold";
    tiles.push(makeHopTile(lane, z, kind));
    z += rand(1.05, 1.35);
  }

  state.hop = {
    tiles,
    playerLane: 1,
    playerZ: 0,
    speed: 1.55,
    baseSpeed: 1.55,
    maxSpeed: 4.4,
    hopAnim: 0,
    hopFrom: { x: 0, y: 0 },
    hopTo: { x: 0, y: 0 },
    melodyStep: 0,
    combo: 0,
    nextSpawnZ: z,
    pulse: 0,
    perfectFlash: 0,
  };
  state.balloons = [];
}

function spawnHopTilesAhead() {
  const hop = state.hop;
  if (!hop) return;
  while (hop.tiles.length < 18) {
    const last = hop.tiles[hop.tiles.length - 1];
    let lane = last ? last.lane : 1;
    if (Math.random() < 0.5) {
      lane = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
    }
    if (Math.random() < 0.22) {
      const side = Math.max(0, Math.min(2, lane + (Math.random() < 0.5 ? -1 : 1)));
      if (side !== lane) {
        hop.tiles.push(makeHopTile(side, hop.nextSpawnZ + 0.15, Math.random() < 0.15 ? "skull" : "normal"));
      }
    }
    let kind = "normal";
    if (Math.random() < 0.14) kind = "skull";
    else if (Math.random() < 0.12) kind = "gold";
    hop.tiles.push(makeHopTile(lane, hop.nextSpawnZ, kind));
    hop.nextSpawnZ += rand(1.05, 1.4);
  }
}

function getHopTargetTiles() {
  const hop = state.hop;
  if (!hop) return [];
  return hop.tiles.filter((t) => !t.hit && !t.missed && t.z > 0.35 && t.z < 2.35);
}

function onHopSuccess(tile) {
  const hop = state.hop;
  tile.hit = true;
  const from = projectHop(hop.playerLane, 0);
  const to = projectHop(tile.lane, Math.max(0.2, tile.z));
  hop.playerLane = tile.lane;
  hop.hopAnim = 1;
  hop.hopFrom = from;
  hop.hopTo = to;

  let gained = 12;
  if (tile.kind === "gold") gained = 30;
  hop.combo += 1;
  gained += Math.min(20, hop.combo * 2);
  gained = Math.round(gained * (1 + (hop.speed - hop.baseSpeed) * 0.15));
  state.score += gained;
  state.combo = hop.combo;
  state.comboTimer = 1.2;

  hop.speed = Math.min(hop.maxSpeed, hop.speed + 0.06);
  hop.perfectFlash = 0.25;

  burst(to.x, to.y, tile.color, tile.kind === "gold");
  floatText(to.x, to.y - 30, `+${gained}`, tile.kind === "gold" ? "#c48a00" : "#fff8ef", {
    size: 26,
    bold: true,
    life: 0.7,
    rise: 60,
  });
  if (tile.kind === "gold") {
    showBanner("BONUS!", "bonus");
    playBonusFanfare();
  } else {
    playHopBeat(1 + hop.combo * 0.03);
    playHopMelody();
  }
  haptic(tile.kind === "gold" ? "heavy" : "medium");
  bumpScore();

  hop.tiles.forEach((t) => {
    if (t.z <= tile.z + 0.05) t.hit = true;
  });
  const advance = tile.z;
  hop.tiles.forEach((t) => {
    t.z -= advance;
  });
  hop.nextSpawnZ -= advance;
  spawnHopTilesAhead();
  updateHud();
}

function onHopSkull(tile) {
  const hop = state.hop;
  tile.hit = true;
  hop.combo = 0;
  state.combo = 0;
  const lost = 20;
  state.score = Math.max(0, state.score - lost);
  const p = projectHop(tile.lane, tile.z);
  burst(p.x, p.y, "#111111", true);
  shakeScreen();
  floatText(p.x, p.y - 20, "☠", "#111", { size: 36, bold: true, life: 0.8, rise: 50 });
  floatText(p.x, p.y + 10, `-${lost}`, "#ff6b6b", { size: 26, bold: true, life: 0.8, rise: 45 });
  playSkullBuzz();
  haptic("heavy");
  bumpScore();
  updateHud();
}

function onHopMiss(tile) {
  const hop = state.hop;
  tile.missed = true;
  hop.combo = 0;
  state.combo = 0;
  const lost = 10;
  state.score = Math.max(0, state.score - lost);
  const p = projectHop(tile.lane, 0.4);
  floatText(p.x, p.y, "Kaçtı!", "#ff6b6b", { size: 22, bold: true, life: 0.7, rise: 40 });
  playSkullBuzz();
  haptic("light");
  updateHud();
}

function updateHop(dt) {
  const hop = state.hop;
  if (!hop) return;

  state.timeLeft -= dt;
  if (state.timeLeft <= 0) {
    state.timeLeft = 0;
    updateHud();
    endGame();
    return;
  }

  const progress = 1 - state.timeLeft / currentLevel().time;
  const targetSpeed = hop.baseSpeed + (hop.maxSpeed - hop.baseSpeed) * progress;
  hop.speed += (targetSpeed - hop.speed) * Math.min(1, dt * 1.5);

  hop.pulse += dt * (3 + hop.speed);
  if (hop.hopAnim > 0) hop.hopAnim = Math.max(0, hop.hopAnim - dt * 3.2);
  if (hop.perfectFlash > 0) hop.perfectFlash = Math.max(0, hop.perfectFlash - dt);

  // sürekli ritim: hız arttıkça BPM artar
  hop.beatAcc = (hop.beatAcc || 0) + dt;
  const beatEvery = Math.max(0.22, 0.55 - (hop.speed - hop.baseSpeed) * 0.08);
  if (hop.beatAcc >= beatEvery) {
    hop.beatAcc = 0;
    playHopBeat(0.7 + hop.speed * 0.08);
  }

  for (const tile of hop.tiles) {
    if (tile.hit || tile.missed) continue;
    tile.z -= hop.speed * dt;
    if (tile.z <= 0.15 && tile.kind !== "skull") {
      onHopMiss(tile);
    } else if (tile.z <= 0.05 && tile.kind === "skull") {
      tile.missed = true;
    }
  }

  hop.tiles = hop.tiles.filter((t) => t.z > -1.5 && !(t.hit && t.z < -0.2));
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
  g.addColorStop(0, "#1b1464");
  g.addColorStop(0.45, "#6c5ce7");
  g.addColorStop(1, "#fd79a8");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, state.width, state.height);

  const beat = 0.5 + 0.5 * Math.sin(hop.pulse * 2);
  const glow = ctx.createRadialGradient(
    state.width * 0.5,
    state.height * 0.35,
    20,
    state.width * 0.5,
    state.height * 0.35,
    220 + beat * 40
  );
  glow.addColorStop(0, `rgba(255, 255, 255, ${0.12 + beat * 0.1 + hop.perfectFlash})`);
  glow.addColorStop(1, "rgba(255,255,255,0)");
  ctx.fillStyle = glow;
  ctx.fillRect(0, 0, state.width, state.height);

  for (let lane = 0; lane < HOP_LANES; lane++) {
    const a = projectHop(lane, 0.2);
    const b = projectHop(lane, 11);
    ctx.strokeStyle = "rgba(255,255,255,0.12)";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(a.x, a.y);
    ctx.lineTo(b.x, b.y);
    ctx.stroke();
  }

  const sorted = [...hop.tiles].sort((a, b) => b.z - a.z);
  const targets = getHopTargetTiles();
  const targetIds = new Set(targets.map((t) => t.id));

  for (const tile of sorted) {
    if (tile.hit && tile.pop < 0.1) continue;
    const p = projectHop(tile.lane, Math.max(0.05, tile.z));
    const active = targetIds.has(tile.id);
    const pulseScale = active ? 1 + Math.sin(hop.pulse * 4) * 0.08 : 1;
    const r = p.r * pulseScale * (tile.hit ? tile.pop : 1);

    ctx.fillStyle = "rgba(0,0,0,0.2)";
    ctx.beginPath();
    ctx.ellipse(p.x, p.y + r * 0.35, r * 0.9, r * 0.28, 0, 0, Math.PI * 2);
    ctx.fill();

    const grad = ctx.createRadialGradient(p.x - r * 0.25, p.y - r * 0.3, r * 0.1, p.x, p.y, r);
    if (tile.kind === "skull") {
      grad.addColorStop(0, "#636e72");
      grad.addColorStop(1, "#1e272e");
    } else {
      grad.addColorStop(0, "#ffffff");
      grad.addColorStop(0.25, tile.color);
      grad.addColorStop(1, tile.color);
    }
    ctx.fillStyle = grad;
    ctx.beginPath();
    ctx.arc(p.x, p.y, r, 0, Math.PI * 2);
    ctx.fill();

    if (active) {
      ctx.strokeStyle = "rgba(255,255,255,0.95)";
      ctx.lineWidth = Math.max(3, r * 0.12);
      ctx.beginPath();
      ctx.arc(p.x, p.y, r + 4, 0, Math.PI * 2);
      ctx.stroke();
    }

    if (tile.kind === "gold") {
      ctx.fillStyle = "#fff";
      ctx.font = `700 ${Math.floor(r * 0.9)}px Fredoka, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("★", p.x, p.y + 1);
    } else if (tile.kind === "skull") {
      ctx.fillStyle = "#dfe6e9";
      ctx.font = `700 ${Math.floor(r * 0.9)}px Fredoka, sans-serif`;
      ctx.textAlign = "center";
      ctx.textBaseline = "middle";
      ctx.fillText("☠", p.x, p.y + 1);
    }

    if (tile.hit) tile.pop *= 0.85;
  }

  let px;
  let py;
  let pr;
  if (hop.hopAnim > 0) {
    const t = 1 - hop.hopAnim;
    const ease = t * t * (3 - 2 * t);
    px = hop.hopFrom.x + (hop.hopTo.x - hop.hopFrom.x) * ease;
    py = hop.hopFrom.y + (hop.hopTo.y - hop.hopFrom.y) * ease - Math.sin(Math.PI * t) * 50;
    pr = 22;
  } else {
    const p = projectHop(hop.playerLane, 0);
    px = p.x;
    py = p.y - 8;
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

  if (targets.length && hop.combo < 2) {
    ctx.fillStyle = "rgba(255,248,239,0.9)";
    ctx.font = "800 16px Nunito, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("Parlayan karoya dokun!", state.width * 0.5, state.height * 0.12);
  }
}

function hopHitTest(x, y) {
  const targets = getHopTargetTiles();
  let best = null;
  let bestDist = Infinity;
  for (const tile of targets) {
    const p = projectHop(tile.lane, tile.z);
    const dx = x - p.x;
    const dy = y - p.y;
    const d = dx * dx + dy * dy;
    const hitR = p.r * 1.45;
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
  const skullChance = state.mode === "play" ? 0.1 + level.id * 0.03 : 0;
  if (skullChance && Math.random() < skullChance) {
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
  ui.time.textContent = String(Math.max(0, Math.ceil(state.timeLeft)));
  if (ui.level) ui.level.textContent = String(level.id);

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
  state.mode = name;
  if (name !== "quiz") stopSpeak();
}

function startGame() {
  ensureAudio();
  stopBoostMusic();
  stopSpeak();
  state.score = 0;
  state.usedQuizIds = [];
  state.levelIndex = 0;
  state.pendingLevelIndex = 1;
  setBoosting(false);
  startLevel(0, true);
}

function startLevel(levelIndex, fromMenu = false) {
  const level = LEVELS[levelIndex];
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
  } else {
    state.hop = null;
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

  const finishedId = currentLevel().id;
  const nextIndex = state.levelIndex + 1;

  if (nextIndex >= LEVELS.length) {
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
  const level = LEVELS[levelIndex];
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
  const isNewBest = state.score > state.best;
  if (isNewBest) {
    state.best = state.score;
    localStorage.setItem(STORAGE_KEY, String(state.best));
  }
  ui.finalScore.textContent = String(state.score);
  ui.bestHome.textContent = `En iyi: ${state.best}`;
  if (state.score >= 900) {
    ui.resultTitle.textContent = "Şampiyon!";
    ui.resultEmoji.textContent = "🏆";
  } else if (state.score >= 500) {
    ui.resultTitle.textContent = "Harika!";
    ui.resultEmoji.textContent = "🎉";
  } else {
    ui.resultTitle.textContent = "İyi iş!";
    ui.resultEmoji.textContent = "🎈";
  }
  ui.resultBest.textContent = isNewBest ? "Yeni rekor kırdın!" : `En iyi skor: ${state.best}`;
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
    burst(b.x, b.y, "#111111", true);
    // dark smoke-ish extra burst
    burst(b.x, b.y, "#636e72", false);
    shakeScreen();
    state.flash = 0.2;
    floatText(b.x, b.y - b.r - 8, "☠", "#111111", { size: 40, bold: true, life: 1, rise: 60 });
    floatText(b.x, b.y + 10, `-${lost}`, "#ff6b6b", { size: 30, bold: true, life: 1, rise: 50 });
    playSkullBuzz();
    haptic("heavy");
    bumpScore();
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
    const alpha = p < 0.15 ? p / 0.15 : Math.max(0, 1 - (p - 0.15) / 0.85);
    const scale = p < 0.2 ? 0.6 + (p / 0.2) * 0.55 : 1.05 - (p - 0.2) * 0.15;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.translate(t.x, t.y);
    ctx.scale(scale, scale);
    ctx.fillStyle = t.color;
    ctx.strokeStyle = "rgba(31,58,77,0.25)";
    ctx.lineWidth = 4;
    ctx.font = `${t.bold ? 900 : 800} ${t.size}px Fredoka, Nunito, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    if (t.bold) ctx.strokeText(t.text, 0, 0);
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
    b.y += b.vy * dt * (state.boostLeft > 0 ? 1.15 : 1);
  }

  state.balloons = state.balloons.filter((b) => {
    if (b.popped) return b.scale > 0.08;
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
  if (isHopMode()) {
    const tile = hopHitTest(x, y);
    if (!tile) return;
    if (tile.kind === "skull") onHopSkull(tile);
    else onHopSuccess(tile);
    return;
  }
  const hit = hitTest(x, y);
  if (hit) popBalloon(hit, x, y);
}

function bindUi() {
  ui.bestHome.textContent = `En iyi: ${state.best}`;

  ui.btnPlay.addEventListener("click", () => startGame());
  ui.btnHow.addEventListener("click", () => showScreen("how"));
  ui.btnHowClose.addEventListener("click", () => showScreen("home"));
  ui.btnPause.addEventListener("click", () => {
    if (!state.running) return;
    state.running = false;
    stopBoostMusic();
    showScreen("pause");
  });
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
  });
  ui.btnAgain.addEventListener("click", () => startGame());
  ui.btnHome.addEventListener("click", () => {
    state.boostLeft = 0;
    setBoosting(false);
    stopSpeak();
    state.balloons = [];
    showScreen("home");
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
