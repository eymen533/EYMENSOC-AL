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

const STORAGE_KEY = "minik-kalem-stars-v1";

const state = {
  mode: "letters",
  chars: LETTERS,
  index: 0,
  color: "#e85d4c",
  drawing: false,
  hasInk: false,
  stars: 0,
  completed: new Set(),
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
  guide: document.getElementById("guide-canvas"),
  draw: document.getElementById("draw-canvas"),
  celebrate: document.getElementById("celebrate"),
  celebrateText: document.querySelector(".celebrate-text"),
  burst: document.querySelector(".burst"),
};

const guideCtx = els.guide.getContext("2d");
const drawCtx = els.draw.getContext("2d");

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
  // Clearing draw on resize is acceptable for kids app simplicity
  clearInk(false);
}

function drawGuide() {
  const w = els.guide.clientWidth;
  const h = els.guide.clientHeight;
  guideCtx.clearRect(0, 0, w, h);

  const char = state.chars[state.index];
  const fontSize = Math.min(w, h) * 0.72;

  guideCtx.save();
  guideCtx.font = `700 ${fontSize}px Fredoka, Nunito, sans-serif`;
  guideCtx.textAlign = "center";
  guideCtx.textBaseline = "middle";
  guideCtx.lineJoin = "round";
  guideCtx.lineCap = "round";

  // Soft filled ghost
  guideCtx.fillStyle = "rgba(26, 107, 138, 0.07)";
  guideCtx.fillText(char, w / 2, h / 2 + fontSize * 0.03);

  // Dashed outline to trace
  guideCtx.strokeStyle = "rgba(26, 107, 138, 0.35)";
  guideCtx.lineWidth = Math.max(3, fontSize * 0.035);
  guideCtx.setLineDash([10, 10]);
  guideCtx.strokeText(char, w / 2, h / 2 + fontSize * 0.03);
  guideCtx.restore();
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
  e.preventDefault();
  state.drawing = true;
  const { x, y } = pointerPos(e);
  drawCtx.beginPath();
  drawCtx.moveTo(x, y);
  drawCtx.lineCap = "round";
  drawCtx.lineJoin = "round";
  drawCtx.strokeStyle = state.color;
  drawCtx.lineWidth = Math.max(10, Math.min(els.draw.clientWidth, els.draw.clientHeight) * 0.028);
  drawCtx.lineTo(x + 0.01, y + 0.01);
  drawCtx.stroke();
  state.hasInk = true;
  playTone(340 + Math.random() * 80, 0.04, "sine", 0.03);
}

function moveDraw(e) {
  if (!state.drawing) return;
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
}

function openWrite(index) {
  state.index = index;
  els.currentChar.textContent = state.chars[index];
  showScreen("write");
  requestAnimationFrame(() => {
    resizeCanvases();
    clearInk();
  });
  playTone(520, 0.08, "triangle", 0.05);
}

function nextChar() {
  state.index = (state.index + 1) % state.chars.length;
  els.currentChar.textContent = state.chars[state.index];
  clearInk();
  drawGuide();
  playTone(480, 0.07, "triangle", 0.05);
}

function spawnBurst() {
  els.burst.innerHTML = "";
  const colors = ["#e85d4c", "#f5a623", "#2bb673", "#3b82f6", "#ffffff"];
  for (let i = 0; i < 18; i++) {
    const s = document.createElement("span");
    const angle = (Math.PI * 2 * i) / 18;
    const dist = 60 + Math.random() * 120;
    s.style.setProperty("--tx", `${Math.cos(angle) * dist}px`);
    s.style.setProperty("--ty", `${Math.sin(angle) * dist}px`);
    s.style.background = colors[i % colors.length];
    s.style.animationDelay = `${Math.random() * 0.08}s`;
    els.burst.appendChild(s);
  }
}

function markDone() {
  if (!state.hasInk) {
    els.celebrate.hidden = false;
    els.celebrateText.textContent = "Biraz yaz bakalım!";
    spawnBurst();
    playTone(220, 0.12, "sine", 0.05);
    setTimeout(() => {
      els.celebrate.hidden = true;
    }, 900);
    return;
  }

  const key = `${state.mode}:${state.chars[state.index]}`;
  if (!state.completed.has(key)) {
    state.completed.add(key);
    state.stars += 1;
    saveProgress();
    updateStarUI();
  }

  els.celebrateText.textContent = PRAISE[Math.floor(Math.random() * PRAISE.length)];
  els.celebrate.hidden = false;
  spawnBurst();
  playSuccess();

  setTimeout(() => {
    els.celebrate.hidden = true;
  }, 1200);
}

/* Events */
document.querySelectorAll("[data-mode]").forEach((btn) => {
  btn.addEventListener("click", () => openPick(btn.dataset.mode));
});

document.getElementById("btn-back-home").addEventListener("click", () => {
  showScreen("home");
  updateStarUI();
});

document.getElementById("btn-back-pick").addEventListener("click", () => {
  renderPickGrid();
  showScreen("pick");
});

document.getElementById("btn-clear").addEventListener("click", () => {
  clearInk();
  playTone(300, 0.06, "sine", 0.04);
});

document.getElementById("btn-done").addEventListener("click", markDone);
document.getElementById("btn-next").addEventListener("click", nextChar);

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

// Prevent page scroll while drawing on mobile
document.body.addEventListener(
  "touchmove",
  (e) => {
    if (state.drawing) e.preventDefault();
  },
  { passive: false },
);

loadProgress();
