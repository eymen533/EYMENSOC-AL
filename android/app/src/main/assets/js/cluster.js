(() => {
  "use strict";

  const CIRC = 2 * Math.PI * 118;
  const SWEEP = 270 / 360;
  const ARC_LEN = CIRC * SWEEP;

  const els = {
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
    overrideUnit: null,
    maxSpeed: 260,
    maxRpm: 8000,
    lastGear: null,
    lastSeen: 0,
  };

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
      const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
      line.setAttribute("x1", 160 + r1 * Math.cos(ang));
      line.setAttribute("y1", 160 + r1 * Math.sin(ang));
      line.setAttribute("x2", 160 + r2 * Math.cos(ang));
      line.setAttribute("y2", 160 + r2 * Math.sin(ang));
      if (major) line.classList.add("major");
      g.appendChild(line);
      if (major && labelDivisor) {
        const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
        text.setAttribute("x", 160 + 108 * Math.cos(ang));
        text.setAttribute("y", 160 + 108 * Math.sin(ang));
        text.textContent = String(v / labelDivisor);
        g.appendChild(text);
      }
    }
  }

  buildTicks("speedTicks", 260, 20, 40, 1);
  buildTicks("rpmTicks", 8, 1, 1, 1);

  function setArc(el, ratio) {
    const r = Math.min(1, Math.max(0, ratio));
    el.setAttribute("stroke-dasharray", `${ARC_LEN * r} ${CIRC}`);
  }

  function setOn(el, on) {
    el.classList.toggle("on", !!on);
  }

  function unitMode() {
    if (state.overrideUnit === "km") return true;
    if (state.overrideUnit === "mi") return false;
    return state.preferKm;
  }

  function setConnection(connected, demo) {
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

  function applyTelemetry(d) {
    if (!d) return;
    state.preferKm = d.preferKm !== false;
    state.lastSeen = Date.now();
    setConnection(true, d.source === "demo");

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
      void els.gearValue.offsetWidth;
      els.gearValue.classList.add("pop");
      state.lastGear = gear;
    }

    const fuel = d.fuel ?? 0;
    els.fuelBar.style.width = `${fuel * 100}%`;
    els.fuelVal.textContent = `${Math.round(fuel * 100)}%`;

    const temp = d.engTemp ?? 0;
    els.tempBar.style.width = `${Math.min(1, Math.max(0, (temp - 40) / 80)) * 100}%`;
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

  // Android native pushes JSON string here
  window.__eymenPush = function (raw) {
    try {
      const d = typeof raw === "string" ? JSON.parse(raw) : raw;
      applyTelemetry(d);
    } catch (e) {
      /* ignore bad payloads */
    }
  };

  els.unitBtn.addEventListener("click", () => {
    state.overrideUnit = unitMode() ? "mi" : "km";
    els.unitBtn.textContent = unitMode() ? "km/h" : "mph";
  });

  setInterval(() => {
    if (state.lastSeen && Date.now() - state.lastSeen > 2000) {
      setConnection(false, false);
      els.metaInfo.textContent = "Sinyal yok · BeamNG OutGauge IP’sini kontrol et";
    }
  }, 1000);

  try {
    if (window.EymenAndroid && EymenAndroid.ready) EymenAndroid.ready();
  } catch (e) {
    /* web preview */
  }
})();
