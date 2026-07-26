const STORAGE_KEY = "balonPatlatBest";

const COLORS = [
  { fill: "#ff6b6b", stroke: "#e84e4e", points: 10 },
  { fill: "#4ecdc4", stroke: "#2fb3aa", points: 10 },
  { fill: "#ffd166", stroke: "#e0b340", points: 15, gold: true },
  { fill: "#ff9f68", stroke: "#ef7f42", points: 10 },
  { fill: "#6bcb77", stroke: "#4eae5b", points: 10 },
  { fill: "#5bb8f0", stroke: "#3a9ad4", points: 12 },
  { fill: "#f78fb3", stroke: "#e06d97", points: 12 },
];

const $ = (id) => document.getElementById(id);

const ui = {
  home: $("home"),
  how: $("how"),
  pause: $("pause"),
  result: $("result"),
  hud: $("hud"),
  score: $("score"),
  time: $("time"),
  combo: $("combo"),
  comboWrap: $("comboWrap"),
  btnPlay: $("btnPlay"),
  btnHow: $("btnHow"),
  btnHowClose: $("btnHowClose"),
  btnPause: $("btnPause"),
  btnResume: $("btnResume"),
  btnQuit: $("btnQuit"),
  btnAgain: $("btnAgain"),
  btnHome: $("btnHome"),
  bestHome: $("bestHome"),
  finalScore: $("finalScore"),
  resultBest: $("resultBest"),
  resultTitle: $("resultTitle"),
  resultEmoji: $("resultEmoji"),
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
  floatTexts: [],
  score: 0,
  combo: 0,
  comboTimer: 0,
  timeLeft: 60,
  spawnTimer: 0,
  lastTs: 0,
  best: Number(localStorage.getItem(STORAGE_KEY) || 0),
  hillsOffset: 0,
};

let audioCtx = null;

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

function spawnBalloon() {
  const color = pick(COLORS);
  const r = rand(34, 52);
  const speed = rand(55, 110) + Math.min(40, state.score / 40);
  state.balloons.push({
    x: rand(r + 10, state.width - r - 10),
    y: state.height + r + rand(10, 80),
    r,
    vy: -speed,
    wobble: rand(0, Math.PI * 2),
    wobbleSpeed: rand(1.5, 3.2),
    wobbleAmp: rand(12, 28),
    color,
    popped: false,
    scale: 1,
  });
}

function burst(x, y, color) {
  for (let i = 0; i < 14; i++) {
    const angle = (Math.PI * 2 * i) / 14 + rand(-0.2, 0.2);
    const speed = rand(80, 220);
    state.particles.push({
      x,
      y,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      life: rand(0.35, 0.7),
      age: 0,
      size: rand(4, 9),
      color,
    });
  }
}

function floatText(x, y, text, color = "#1f3a4d") {
  state.floatTexts.push({ x, y, text, color, age: 0, life: 0.8 });
}

function updateHud() {
  ui.score.textContent = String(state.score);
  ui.time.textContent = String(Math.max(0, Math.ceil(state.timeLeft)));
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
  ui.hud.hidden = name !== "play";
  ui.btnPause.hidden = name !== "play";
  state.mode = name;
}

function startGame() {
  ensureAudio();
  state.running = true;
  state.score = 0;
  state.combo = 0;
  state.comboTimer = 0;
  state.timeLeft = 60;
  state.spawnTimer = 0;
  state.balloons = [];
  state.particles = [];
  state.floatTexts = [];
  state.lastTs = performance.now();
  showScreen("play");
  updateHud();
  for (let i = 0; i < 5; i++) spawnBalloon();
}

function endGame() {
  state.running = false;
  const isNewBest = state.score > state.best;
  if (isNewBest) {
    state.best = state.score;
    localStorage.setItem(STORAGE_KEY, String(state.best));
  }
  ui.finalScore.textContent = String(state.score);
  ui.bestHome.textContent = `En iyi: ${state.best}`;
  if (state.score >= 400) {
    ui.resultTitle.textContent = "Muhteşem!";
    ui.resultEmoji.textContent = "🏆";
  } else if (state.score >= 200) {
    ui.resultTitle.textContent = "Harika!";
    ui.resultEmoji.textContent = "🎉";
  } else {
    ui.resultTitle.textContent = "İyi iş!";
    ui.resultEmoji.textContent = "🎈";
  }
  ui.resultBest.textContent = isNewBest ? "Yeni rekor kırdın!" : `En iyi skor: ${state.best}`;
  showScreen("result");
  playCheer();
  haptic("heavy");
}

function popBalloon(b, clientX, clientY) {
  if (b.popped) return;
  b.popped = true;
  const base = b.color.points;
  state.comboTimer = 1.1;
  state.combo += 1;
  const mult = Math.min(5, 1 + Math.floor((state.combo - 1) / 2));
  const gained = base * mult;
  state.score += gained;
  burst(b.x, b.y, b.color.fill);
  floatText(b.x, b.y - b.r, mult > 1 ? `+${gained} x${mult}` : `+${gained}`, b.color.gold ? "#c48a00" : "#1f3a4d");
  playPop(b.color.gold ? 1.35 : 0.9 + Math.random() * 0.4);
  haptic(b.color.gold ? "heavy" : "medium");
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
  const g = ctx.createLinearGradient(0, 0, 0, state.height);
  g.addColorStop(0, "#9ad7ff");
  g.addColorStop(0.55, "#7ec8f8");
  g.addColorStop(1, "#ffe8b0");
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, state.width, state.height);

  // soft sun during play
  if (state.mode === "play" || state.mode === "pause" || state.mode === "result") {
    const sx = state.width * 0.82;
    const sy = state.height * 0.12;
    const sun = ctx.createRadialGradient(sx, sy, 8, sx, sy, 70);
    sun.addColorStop(0, "rgba(255, 247, 194, 0.95)");
    sun.addColorStop(0.5, "rgba(255, 209, 102, 0.75)");
    sun.addColorStop(1, "rgba(255, 209, 102, 0)");
    ctx.fillStyle = sun;
    ctx.beginPath();
    ctx.arc(sx, sy, 70, 0, Math.PI * 2);
    ctx.fill();
  }

  state.hillsOffset = (state.hillsOffset + dt * 8) % state.width;
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
  const x = b.x + Math.sin(b.wobble) * b.wobbleAmp * 0.15;
  const y = b.y;
  const r = b.r * b.scale;

  // string
  ctx.strokeStyle = "rgba(31,58,77,0.35)";
  ctx.lineWidth = 2;
  ctx.beginPath();
  ctx.moveTo(x, y + r * 0.9);
  ctx.quadraticCurveTo(x + 6, y + r * 1.4, x - 2, y + r * 1.85);
  ctx.stroke();

  // body
  const grad = ctx.createRadialGradient(x - r * 0.3, y - r * 0.35, r * 0.1, x, y, r);
  grad.addColorStop(0, "#ffffff");
  grad.addColorStop(0.18, b.color.fill);
  grad.addColorStop(1, b.color.stroke);
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
  ctx.fillStyle = "rgba(255,255,255,0.55)";
  ctx.beginPath();
  ctx.ellipse(x - r * 0.28, y - r * 0.35, r * 0.18, r * 0.28, -0.5, 0, Math.PI * 2);
  ctx.fill();

  if (b.color.gold) {
    ctx.fillStyle = "rgba(255,255,255,0.75)";
    ctx.font = `700 ${Math.floor(r * 0.7)}px Fredoka, sans-serif`;
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText("★", x, y);
  }
}

function drawParticles() {
  for (const p of state.particles) {
    const alpha = 1 - p.age / p.life;
    ctx.globalAlpha = Math.max(0, alpha);
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
    ctx.fill();
  }
  ctx.globalAlpha = 1;
}

function drawFloatTexts() {
  for (const t of state.floatTexts) {
    const alpha = 1 - t.age / t.life;
    ctx.globalAlpha = Math.max(0, alpha);
    ctx.fillStyle = t.color;
    ctx.font = "800 22px Nunito, sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(t.text, t.x, t.y);
  }
  ctx.globalAlpha = 1;
}

function update(dt) {
  if (!state.running) {
    // idle decorative balloons on home
    if (state.mode === "home") {
      state.spawnTimer -= dt;
      if (state.spawnTimer <= 0 && state.balloons.length < 8) {
        spawnBalloon();
        state.spawnTimer = rand(0.4, 1.1);
      }
    }
  } else {
    state.timeLeft -= dt;
    if (state.timeLeft <= 0) {
      state.timeLeft = 0;
      updateHud();
      endGame();
      return;
    }

    state.comboTimer -= dt;
    if (state.comboTimer <= 0) state.combo = 0;

    const spawnRate = Math.max(0.28, 0.85 - state.score / 1200);
    state.spawnTimer -= dt;
    if (state.spawnTimer <= 0) {
      spawnBalloon();
      if (Math.random() < 0.35) spawnBalloon();
      state.spawnTimer = spawnRate;
    }
    updateHud();
  }

  for (const b of state.balloons) {
    if (b.popped) {
      b.scale *= 0.82;
      continue;
    }
    b.wobble += b.wobbleSpeed * dt;
    b.x += Math.sin(b.wobble) * b.wobbleAmp * dt;
    b.y += b.vy * dt;
  }

  state.balloons = state.balloons.filter((b) => {
    if (b.popped) return b.scale > 0.08;
    return b.y + b.r > -40;
  });

  for (const p of state.particles) {
    p.age += dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
    p.vy += 280 * dt;
  }
  state.particles = state.particles.filter((p) => p.age < p.life);

  for (const t of state.floatTexts) {
    t.age += dt;
    t.y -= 40 * dt;
  }
  state.floatTexts = state.floatTexts.filter((t) => t.age < t.life);
}

function frame(ts) {
  const dt = Math.min(0.033, (ts - state.lastTs) / 1000 || 0.016);
  state.lastTs = ts;
  if (state.mode !== "pause") update(dt);
  drawBackground(dt);
  for (const b of state.balloons) drawBalloon(b);
  drawParticles();
  drawFloatTexts();
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
    showScreen("pause");
  });
  ui.btnResume.addEventListener("click", () => {
    state.running = true;
    state.lastTs = performance.now();
    showScreen("play");
  });
  ui.btnQuit.addEventListener("click", () => {
    state.running = false;
    state.balloons = [];
    showScreen("home");
  });
  ui.btnAgain.addEventListener("click", () => startGame());
  ui.btnHome.addEventListener("click", () => {
    state.balloons = [];
    showScreen("home");
  });

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
        showScreen("pause");
      } else if (state.mode === "pause" || state.mode === "how" || state.mode === "result") {
        state.running = false;
        state.balloons = [];
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
window.addEventListener("resize", resize);
window.addEventListener("orientationchange", () => setTimeout(resize, 120));
