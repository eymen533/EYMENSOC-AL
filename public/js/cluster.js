(() => {
  "use strict";

  const CIRC = 2 * Math.PI * 118; // ~741.7
  const SWEEP = 270 / 360; // visible arc portion
  const ARC_LEN = CIRC * SWEEP;

  const els = {
    boot: document.getElementById("boot"),
    enterBtn: document.getElementById("enterBtn"),
    cluster: document.getElementById("cluster"),
    connStatus: document.getElementById("connStatus"),
    unitBtn: document.getElementById("unitBtn"),
    speedValue: document.getElementById("speedValue"),
    speedUnit: document.getElementById("speedUnit"),
    speedArc: document.getElementById("speedArc"),
    rpmValue: document.getElementById("rpmValue"),
    rpmArc: document.getElementById("rpmArc"),
    gearValue: document.getElementById("gearValue"),
    fuelBar: document.getElementById("fuelBar"),
    fuelVal: document.getElementById("fuelVal"),
    tempBar: document.getElementById("tempBar"),
    tempVal: document.getElementById("tempVal"),
    turboMeter: document.getElementById("turboMeter"),
    turboBar: document.getElementById("turboBar"),
    turboVal: document.getElementById("turboVal"),
    throttleBar: document.getElementById("throttleBar"),
    brakeBar: document.getElementById("brakeBar"),
    metaInfo: document.getElementById("metaInfo"),
    sigL: document.getElementById("sigL"),
    sigR: document.getElementById("sigR"),
    beam: document.getElementById("beam"),
    warnHb: document.getElementById("warnHb"),
    warnAbs: document.getElementById("warnAbs"),
    warnTc: document.getElementById("warnTc"),
    warnOil: document.getElementById("warnOil"),
    warnBat: document.getElementById("warnBat"),
    warnShift: document.getElementById("warnShift"),
  };

  const state = {
    preferKm: true,
    overrideUnit: null, // null | 'km' | 'mi'
    maxSpeed: 260,
    maxRpm: 8000,
    lastGear: null,
    connected: false,
    demo: false,
  };

  /* ---- Gauge ticks ---- */
  function buildTicks(groupId, max, step, majorEvery, labelDivisor) {
    const g = document.getElementById(groupId);
    if (!g) return;
    g.innerHTML = "";
    const start = -210;
    const end = 60;
    const span = end - start;
    for (let v = 0; v <= max; v += step) {
      const t = v / max;
      const ang = ((start + span * t) * Math.PI) / 180;
      const major = v % majorEvery === 0;
      const r1 = major ? 128 : 132;
      const r2 = 138;
      const x1 = 160 + r1 * Math.cos(ang);
      const y1 = 160 + r1 * Math.sin(ang);
      const x2 = 160 + r2 * Math.cos(ang);
      const y2 = 160 + r2 * Math.sin(ang);
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", x1);
      line.setAttribute("y1", y1);
      line.setAttribute("x2", x2);
      line.setAttribute("y2", y2);
      if (major) line.classList.add("major");
      g.appendChild(line);

      if (major && labelDivisor) {
        const tr = 108;
        const tx = 160 + tr * Math.cos(ang);
        const ty = 160 + tr * Math.sin(ang);
        const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
        text.setAttribute("x", tx);
        text.setAttribute("y", ty);
        text.textContent = String(v / labelDivisor);
        g.appendChild(text);
      }
    }
  }

  buildTicks("speedTicks", 260, 20, 40, 1);
  buildTicks("rpmTicks", 8, 1, 1, 1);

  function setArc(el, ratio) {
    const r = Math.min(1, Math.max(0, ratio));
    const filled = ARC_LEN * r;
    el.setAttribute("stroke-dasharray", `${filled} ${CIRC}`);
  }

  function setOn(el, on) {
    el.classList.toggle("on", !!on);
  }

  function unitMode() {
    if (state.overrideUnit === "km") return true;
    if (state.overrideUnit === "mi") return false;
    return state.preferKm;
  }

  function applyTelemetry(d) {
    if (!d) return;
    state.preferKm = d.preferKm !== false;

    const km = unitMode();
    const speed = km ? d.speedKmh : d.speedMph;
    const speedMax = km ? state.maxSpeed : state.maxSpeed * 0.621371;
    const speedShown = Math.round(Math.max(0, speed));

    els.speedValue.textContent = String(speedShown);
    els.speedUnit.textContent = km ? "km/h" : "mph";
    els.unitBtn.textContent = km ? "km/h" : "mph";
    setArc(els.speedArc, speed / speedMax);

    const rpm = Math.max(0, d.rpm || 0);
    if (rpm > state.maxRpm) state.maxRpm = Math.ceil(rpm / 1000) * 1000;
    els.rpmValue.textContent = (rpm / 1000).toFixed(1);
    setArc(els.rpmArc, rpm / state.maxRpm);

    const gear = d.gearLabel || "N";
    if (gear !== state.lastGear) {
      els.gearValue.textContent = gear;
      els.gearValue.classList.remove("pop");
      // reflow for animation restart
      void els.gearValue.offsetWidth;
      els.gearValue.classList.add("pop");
      state.lastGear = gear;
    }

    const fuel = d.fuel ?? 0;
    els.fuelBar.style.width = `${fuel * 100}%`;
    els.fuelVal.textContent = `${Math.round(fuel * 100)}%`;

    const temp = d.engTemp ?? 0;
    const tempPct = Math.min(1, Math.max(0, (temp - 40) / 80));
    els.tempBar.style.width = `${tempPct * 100}%`;
    els.tempVal.textContent = `${Math.round(temp)}°`;

    if (d.showTurbo) {
      els.turboMeter.hidden = false;
      const turbo = Math.max(0, d.turbo || 0);
      els.turboBar.style.width = `${Math.min(1, turbo / 2) * 100}%`;
      els.turboVal.textContent = `${turbo.toFixed(1)}`;
    }

    els.throttleBar.style.width = `${(d.throttle || 0) * 100}%`;
    els.brakeBar.style.width = `${(d.brake || 0) * 100}%`;

    const L = d.lights || {};
    setOn(els.sigL, L.signalL);
    setOn(els.sigR, L.signalR);
    setOn(els.beam, L.fullbeam);
    setOn(els.warnHb, L.handbrake);
    setOn(els.warnAbs, L.abs);
    setOn(els.warnTc, L.tc);
    setOn(els.warnOil, L.oilWarn);
    setOn(els.warnBat, L.battery);
    setOn(els.warnShift, L.shift);

    const src = d.source === "demo" ? "DEMO" : "LIVE";
    els.metaInfo.textContent = `${src} · ${speedShown} ${km ? "km/h" : "mph"} · ${Math.round(rpm)} rpm`;
  }

  function setConnection(connected, demo) {
    state.connected = connected;
    state.demo = demo;
    if (demo) {
      els.connStatus.dataset.state = "demo";
      els.connStatus.textContent = "DEMO";
    } else if (connected) {
      els.connStatus.dataset.state = "live";
      els.connStatus.textContent = "CANLI";
    } else {
      els.connStatus.dataset.state = "lost";
      els.connStatus.textContent = "SİNYAL YOK";
    }
  }

  /* ---- WebSocket ---- */
  let ws;
  let retryMs = 800;

  function connect() {
    const proto = location.protocol === "https:" ? "wss" : "ws";
    ws = new WebSocket(`${proto}://${location.host}`);
    ws.addEventListener("open", () => {
      retryMs = 800;
      els.metaInfo.textContent = "Bağlandı · OutGauge bekleniyor…";
    });
    ws.addEventListener("message", (ev) => {
      let msg;
      try {
        msg = JSON.parse(ev.data);
      } catch {
        return;
      }
      if (msg.type === "hello") {
        setConnection(false, !!msg.demo);
        if (msg.demo) els.metaInfo.textContent = "Demo modu aktif";
        return;
      }
      if (msg.type === "telemetry") {
        setConnection(true, msg.data?.source === "demo");
        applyTelemetry(msg.data);
        return;
      }
      if (msg.type === "status") {
        setConnection(!!msg.connected, !!msg.demo);
      }
    });
    ws.addEventListener("close", () => {
      setConnection(false, false);
      els.metaInfo.textContent = "Yeniden bağlanılıyor…";
      setTimeout(connect, retryMs);
      retryMs = Math.min(5000, retryMs * 1.4);
    });
  }

  /* ---- UI ---- */
  async function enterCluster() {
    els.boot.hidden = true;
    els.cluster.hidden = false;
    try {
      if (document.documentElement.requestFullscreen) {
        await document.documentElement.requestFullscreen();
      }
    } catch {
      /* kullanıcı engellediyse sorun değil */
    }
    try {
      if (screen.orientation?.lock) await screen.orientation.lock("landscape");
    } catch {
      /* bazı tarayıcılarda yok */
    }
    connect();
  }

  els.enterBtn.addEventListener("click", enterCluster);
  els.unitBtn.addEventListener("click", () => {
    const km = unitMode();
    state.overrideUnit = km ? "mi" : "km";
    els.unitBtn.textContent = unitMode() ? "km/h" : "mph";
  });

  // Wake Lock — ekranın kapanmasını engelle
  async function keepAwake() {
    try {
      if ("wakeLock" in navigator) {
        await navigator.wakeLock.request("screen");
        document.addEventListener("visibilitychange", async () => {
          if (document.visibilityState === "visible") {
            try {
              await navigator.wakeLock.request("screen");
            } catch {
              /* ignore */
            }
          }
        });
      }
    } catch {
      /* ignore */
    }
  }
  keepAwake();
})();
