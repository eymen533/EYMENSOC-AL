const LETTERS = [
  "A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H",
  "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P",
  "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z",
];

const NUMBERS = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"];

const PRAISE = [
  "Harikasın!",
  "Süpersin!",
  "Aferin!",
  "Çok güzel!",
  "Bravo!",
  "Muhteşem!",
];

const CHAR_SAY = {
  Ç: "çe",
  Ğ: "yumuşak ge",
  I: "ı",
  İ: "i",
  Ö: "ö",
  Ş: "şe",
  Ü: "ü",
};

const STORAGE_KEY = "minik-kalem-stars-v1";

/** Kids-friendly thresholds: generous coverage, allow some stray ink */
const PASS_COVER = 0.32;
const PASS_OUTSIDE = 0.55;
const MIN_INK_RATIO = 0.004;

const state = {
  mode: "letters",
  chars: LETTERS,
  index: 0,
  color: "#e85d4c",
  drawing: false,
  hasInk: false,
  stars: 0,
  completed: new Set(),
  locked: false,
  checkTimer: null,
  voicesReady: false,
};

const els = {
  screens: {
    home: document.getElementById("screen-home"),
    pick: document.getElementById("screen-pick"),
    write: document.getElementById("screen-write"),
  },
  pickTitle: document.getElementById("pick-title"),
  pickGrid: document.getElementById("pick-grid"),
  currentChar: document.getElementById("current-char"),
  starCount: document.getElementById("star-count"),
  starsSummary: document.getElementById("stars-summary"),
  voiceHint: document.getElementById("voice-hint"),
  guide: document.getElementById("guide-canvas"),
  draw: document.getElementById("draw-canvas"),
  celebrate: document.getElementById("celebrate"),
  celebrateText: document.querySelector(".celebrate-text"),
  burst: document.querySelector(".burst"),
};

const guideCtx = els.guide.getContext("2d", { willReadFrequently: true });
const drawCtx = els.draw.getContext("2d", { willReadFrequently: true });
const maskCanvas = document.createElement("canvas");
const maskCtx = maskCanvas.getContext("2d", { willReadFrequently: true });

function loadProgress() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return;
    const data = JSON.parse(raw);
    state.stars = Number(data.stars) || 0;
    state.completed = new Set(data.completed || []);
  } catch {
    /* ignore */
  }
  updateStarUI();
}

function saveProgress() {
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      stars: state.stars,
      completed: [...state.completed],
    }),
  );
}

function updateStarUI() {
  els.starCount.textContent = `⭐ ${state.stars}`;
  els.starsSummary.textContent = `⭐ ${state.stars} yıldız`;
}

function showScreen(name) {
  Object.entries(els.screens).forEach(([key, el]) => {
    el.classList.toggle("active", key === name);
  });
}

function setHint(text) {
  if (els.voiceHint) els.voiceHint.textContent = text;
}

function sayChar(ch) {
  return CHAR_SAY[ch] || ch.toLowerCase();
}

function instructionFor(ch) {
  if (state.mode === "numbers") {
    return `${sayChar(ch)} rakamını yaz. Büyük çizgilerin üzerinden geç.`;
  }
  return `${sayChar(ch)} harfini yaz. Büyük çizgilerin üzerinden geç.`;
}

function pickTurkishVoice() {
  const voices = window.speechSynthesis?.getVoices?.() || [];
  return (
    voices.find((v) => v.lang?.toLowerCase().startsWith("tr")) ||
    voices.find((v) => /turkish|türkçe|turk/i.test(v.name)) ||
    voices.find((v) => v.lang?.toLowerCase().startsWith("en")) ||
    voices[0] ||
    null
  );
}

function speak(text, { rate = 0.92, interrupt = true } = {}) {
  return new Promise((resolve) => {
    if (!window.speechSynthesis) {
      resolve();
      return;
    }
    if (interrupt) window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(text);
    u.lang = "tr-TR";
    u.rate = rate;
    u.pitch = 1.08;
    const voice = pickTurkishVoice();
    if (voice) u.voice = voice;
    u.onend = () => resolve();
    u.onerror = () => resolve();
    window.speechSynthesis.speak(u);
  });
}

function warmVoices() {
  if (!window.speechSynthesis) return;
  const ready = () => {
    state.voicesReady = true;
  };
  ready();
  window.speechSynthesis.addEventListener("voiceschanged", ready);
  window.speechSynthesis.getVoices();
}

function playTone(freq, duration = 0.12, type = "sine", gain = 0.08) {
  try {
    const ctx = playTone.ctx || (playTone.ctx = new (window.AudioContext || window.webkitAudioContext)());
    const osc = ctx.createOscillator();
    const g = ctx.createGain();
    osc.type = type;
    osc.frequency.value = freq;
    g.gain.value = gain;
    g.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + duration);
    osc.connect(g);
    g.connect(ctx.destination);
    osc.start();
    osc.stop(ctx.currentTime + duration);
  } catch {
    /* audio optional */
  }
}

function playSuccess() {
  playTone(523, 0.1, "triangle", 0.07);
  setTimeout(() => playTone(659, 0.1, "triangle", 0.07), 90);
  setTimeout(() => playTone(784, 0.18, "triangle", 0.08), 180);
}

function guideFontSize(w, h) {
  return Math.min(w, h) * 0.92;
}

function penWidth() {
  return Math.max(18, Math.min(els.draw.clientWidth, els.draw.clientHeight) * 0.048);
}

function paintChar(ctx, char, w, h, { fill, stroke, lineWidth, dash } = {}) {
  const fontSize = guideFontSize(w, h);
  ctx.save();
  ctx.font = `700 ${fontSize}px Fredoka, Nunito, sans-serif`;
  ctx.textAlign = "center";
  ctx.textBaseline = "middle";
  ctx.lineJoin = "round";
  ctx.lineCap = "round";
  const y = h / 2 + fontSize * 0.02;
  if (fill) {
    ctx.fillStyle = fill;
    ctx.fillText(char, w / 2, y);
  }
  if (stroke) {
    ctx.strokeStyle = stroke;
    ctx.lineWidth = lineWidth ?? Math.max(6, fontSize * 0.045);
    if (dash) ctx.setLineDash(dash);
    ctx.strokeText(char, w / 2, y);
  }
  ctx.restore();
}

function rebuildMask() {
  const w = els.guide.clientWidth;
  const h = els.guide.clientHeight;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  maskCanvas.width = Math.floor(w * dpr);
  maskCanvas.height = Math.floor(h * dpr);
  maskCtx.setTransform(dpr, 0, 0, dpr, 0, 0);
  maskCtx.clearRect(0, 0, w, h);

  const char = state.chars[state.index];
  const fontSize = guideFontSize(w, h);
  // Thick filled letter as forgiving target
  paintChar(maskCtx, char, w, h, {
    fill: "#000",
    stroke: "#000",
    lineWidth: Math.max(28, fontSize * 0.12),
  });
}

function drawGuide() {
  const w = els.guide.clientWidth;
  const h = els.guide.clientHeight;
  guideCtx.clearRect(0, 0, w, h);

  const char = state.chars[state.index];
  const fontSize = guideFontSize(w, h);

  paintChar(guideCtx, char, w, h, {
    fill: "rgba(26, 107, 138, 0.09)",
  });
  paintChar(guideCtx, char, w, h, {
    stroke: "rgba(26, 107, 138, 0.42)",
    lineWidth: Math.max(8, fontSize * 0.055),
    dash: [16, 14],
  });

  rebuildMask();
}

function resizeCanvases() {
  const stage = els.draw.parentElement;
  const dpr = Math.min(window.devicePixelRatio || 1, 2);
  const w = stage.clientWidth;
  const h = stage.clientHeight;

  [els.guide, els.draw].forEach((canvas) => {
    canvas.width = Math.floor(w * dpr);
    canvas.height = Math.floor(h * dpr);
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    const ctx = canvas.getContext("2d");
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  });

  drawGuide();
  clearInk(false);
}

function clearInk(resetFlag = true) {
  const w = els.draw.clientWidth;
  const h = els.draw.clientHeight;
  drawCtx.clearRect(0, 0, w, h);
  if (resetFlag) state.hasInk = false;
  els.celebrate.hidden = true;
}

function pointerPos(e) {
  const rect = els.draw.getBoundingClientRect();
  const point = e.touches ? e.touches[0] : e;
  return {
    x: point.clientX - rect.left,
    y: point.clientY - rect.top,
  };
}

function startDraw(e) {
  if (state.locked) return;
  e.preventDefault();
  state.drawing = true;
  const { x, y } = pointerPos(e);
  drawCtx.beginPath();
  drawCtx.moveTo(x, y);
  drawCtx.lineCap = "round";
  drawCtx.lineJoin = "round";
  drawCtx.strokeStyle = state.color;
  drawCtx.lineWidth = penWidth();
  drawCtx.lineTo(x + 0.01, y + 0.01);
  drawCtx.stroke();
  state.hasInk = true;
  playTone(340 + Math.random() * 80, 0.04, "sine", 0.03);
}

function moveDraw(e) {
  if (!state.drawing || state.locked) return;
  e.preventDefault();
  const { x, y } = pointerPos(e);
  drawCtx.lineTo(x, y);
  drawCtx.stroke();
  drawCtx.beginPath();
  drawCtx.moveTo(x, y);
}

function endDraw(e) {
  if (!state.drawing) return;
  e.preventDefault();
  state.drawing = false;
  drawCtx.beginPath();
  scheduleAutoCheck();
}

function scheduleAutoCheck() {
  clearTimeout(state.checkTimer);
  state.checkTimer = setTimeout(() => {
    if (state.locked || state.drawing) return;
    const score = scoreDrawing();
    if (score.pass) succeedAndAdvance();
  }, 450);
}

function scoreDrawing() {
  const w = els.draw.width;
  const h = els.draw.height;
  if (!w || !h) return { pass: false, cover: 0, outside: 1, ink: 0 };
  if (maskCanvas.width !== w || maskCanvas.height !== h) rebuildMask();
  if (maskCanvas.width !== w || maskCanvas.height !== h) {
    return { pass: false, cover: 0, outside: 1, ink: 0 };
  }

  const drawData = drawCtx.getImageData(0, 0, w, h).data;
  const maskData = maskCtx.getImageData(0, 0, w, h).data;

  let maskPixels = 0;
  let hitPixels = 0;
  let inkPixels = 0;
  let outsideInk = 0;

  for (let i = 0; i < drawData.length; i += 4) {
    const onMask = maskData[i + 3] > 40;
    const hasInk = drawData[i + 3] > 40;
    if (onMask) {
      maskPixels += 1;
      if (hasInk) hitPixels += 1;
    }
    if (hasInk) {
      inkPixels += 1;
      if (!onMask) outsideInk += 1;
    }
  }

  const total = w * h;
  const inkRatio = inkPixels / total;
  const cover = maskPixels ? hitPixels / maskPixels : 0;
  const outside = inkPixels ? outsideInk / inkPixels : 1;
  const pass =
    inkRatio >= MIN_INK_RATIO &&
    cover >= PASS_COVER &&
    outside <= PASS_OUTSIDE;

  return { pass, cover, outside, ink: inkRatio };
}

function renderPickGrid() {
  els.pickGrid.innerHTML = "";
  state.chars.forEach((ch, i) => {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "char-btn";
    btn.textContent = ch;
    btn.setAttribute("role", "listitem");
    btn.setAttribute("aria-label", `Yaz: ${ch}`);
    if (state.completed.has(`${state.mode}:${ch}`)) btn.classList.add("done");
    btn.addEventListener("click", () => openWrite(i));
    els.pickGrid.appendChild(btn);
  });
}

function openPick(mode) {
  state.mode = mode;
  state.chars = mode === "letters" ? LETTERS : NUMBERS;
  els.pickTitle.textContent = mode === "letters" ? "Harfler" : "Rakamlar";
  renderPickGrid();
  showScreen("pick");
  playTone(440, 0.08, "triangle", 0.05);
  const label = mode === "letters" ? "Harf seç. Büyük harfleri yazacağız." : "Rakam seç. Büyük rakamları yazacağız.";
  setHint(label);
  speak(label);
}

async function openWrite(index) {
  state.index = index;
  state.locked = false;
  els.currentChar.textContent = state.chars[index];
  showScreen("write");
  requestAnimationFrame(() => {
    resizeCanvases();
    clearInk();
  });
  playTone(520, 0.08, "triangle", 0.05);
  const text = instructionFor(state.chars[index]);
  setHint(text);
  await speak(text);
}

async function goToNext({ announce = true } = {}) {
  state.index = (state.index + 1) % state.chars.length;
  els.currentChar.textContent = state.chars[state.index];
  clearInk();
  drawGuide();
  state.locked = false;
  playTone(480, 0.07, "triangle", 0.05);
  if (announce) {
    const text = instructionFor(state.chars[state.index]);
    setHint(text);
    await speak(text);
  }
}

function nextChar() {
  if (state.locked) return;
  goToNext({ announce: true });
}

function spawnBurst() {
  els.burst.innerHTML = "";
  const colors = ["#e85d4c", "#f5a623", "#2bb673", "#3b82f6", "#ffffff"];
  for (let i = 0; i < 22; i++) {
    const s = document.createElement("span");
    const angle = (Math.PI * 2 * i) / 22;
    const dist = 70 + Math.random() * 140;
    s.style.setProperty("--tx", `${Math.cos(angle) * dist}px`);
    s.style.setProperty("--ty", `${Math.sin(angle) * dist}px`);
    s.style.background = colors[i % colors.length];
    s.style.animationDelay = `${Math.random() * 0.08}s`;
    els.burst.appendChild(s);
  }
}

async function succeedAndAdvance() {
  if (state.locked) return;
  state.locked = true;
  clearTimeout(state.checkTimer);

  const ch = state.chars[state.index];
  const key = `${state.mode}:${ch}`;
  if (!state.completed.has(key)) {
    state.completed.add(key);
    state.stars += 1;
    saveProgress();
    updateStarUI();
  }

  const praise = PRAISE[Math.floor(Math.random() * PRAISE.length)];
  els.celebrateText.textContent = praise;
  els.celebrate.hidden = false;
  spawnBurst();
  playSuccess();
  setHint(praise);
  await speak(`${praise} Doğru yazdın.`);

  els.celebrate.hidden = true;
  await goToNext({ announce: true });
}

async function markDone() {
  if (state.locked) return;

  if (!state.hasInk) {
    const msg = "Biraz yaz bakalım. Çizgilerin üzerinden geç.";
    els.celebrate.hidden = false;
    els.celebrateText.textContent = "Biraz yaz!";
    spawnBurst();
    playTone(220, 0.12, "sine", 0.05);
    setHint(msg);
    await speak(msg);
    els.celebrate.hidden = true;
    return;
  }

  const score = scoreDrawing();
  if (score.pass) {
    await succeedAndAdvance();
    return;
  }

  const tip =
    score.cover < PASS_COVER
      ? "Harfin üzerinden daha fazla geç. Tekrar dene."
      : "Biraz daha düzgün yaz. Çizgilerin içinden geç.";
  setHint(tip);
  els.celebrate.hidden = false;
  els.celebrateText.textContent = "Tekrar dene!";
  spawnBurst();
  playTone(260, 0.12, "sine", 0.05);
  await speak(tip);
  els.celebrate.hidden = true;
}

/* Events */
document.querySelectorAll("[data-mode]").forEach((btn) => {
  btn.addEventListener("click", () => openPick(btn.dataset.mode));
});

document.getElementById("btn-back-home").addEventListener("click", () => {
  state.locked = false;
  window.speechSynthesis?.cancel();
  showScreen("home");
  updateStarUI();
  setHint("Harf veya rakam seçerek başla.");
});

document.getElementById("btn-back-pick").addEventListener("click", () => {
  state.locked = false;
  window.speechSynthesis?.cancel();
  renderPickGrid();
  showScreen("pick");
});

document.getElementById("btn-clear").addEventListener("click", () => {
  if (state.locked) return;
  clearInk();
  playTone(300, 0.06, "sine", 0.04);
  const tip = "Temizledim. Yeniden yaz.";
  setHint(tip);
  speak(tip);
});

document.getElementById("btn-done").addEventListener("click", markDone);
document.getElementById("btn-next").addEventListener("click", nextChar);

document.getElementById("btn-repeat")?.addEventListener("click", () => {
  if (state.locked) return;
  const text = instructionFor(state.chars[state.index]);
  setHint(text);
  speak(text);
});

document.querySelectorAll(".swatch").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".swatch").forEach((s) => s.classList.remove("active"));
    btn.classList.add("active");
    state.color = btn.dataset.color;
    playTone(400, 0.05, "sine", 0.03);
  });
});

["mousedown", "touchstart"].forEach((evt) => {
  els.draw.addEventListener(evt, startDraw, { passive: false });
});
["mousemove", "touchmove"].forEach((evt) => {
  els.draw.addEventListener(evt, moveDraw, { passive: false });
});
["mouseup", "mouseleave", "touchend", "touchcancel"].forEach((evt) => {
  els.draw.addEventListener(evt, endDraw, { passive: false });
});

window.addEventListener("resize", () => {
  if (els.screens.write.classList.contains("active")) resizeCanvases();
});

document.body.addEventListener(
  "touchmove",
  (e) => {
    if (state.drawing) e.preventDefault();
  },
  { passive: false },
);

// Unlock audio/speech on first tap (mobile browsers)
document.addEventListener(
  "pointerdown",
  () => {
    try {
      playTone.ctx || (playTone.ctx = new (window.AudioContext || window.webkitAudioContext)());
      playTone.ctx.resume?.();
    } catch {
      /* ignore */
    }
    warmVoices();
  },
  { once: true },
);

warmVoices();
loadProgress();
setHint("Harf veya rakam seçerek başla.");
