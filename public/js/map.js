(() => {
  "use strict";

  const canvas = document.getElementById("navMap");
  const meta = document.getElementById("navMeta");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  function resize() {
    const rect = canvas.getBoundingClientRect();
    const dpr = Math.min(2, window.devicePixelRatio || 1);
    canvas.width = Math.max(280, Math.floor(rect.width * dpr));
    canvas.height = Math.max(140, Math.floor(rect.height * dpr || canvas.width * 0.52));
  }
  resize();
  window.addEventListener("resize", resize);

  function update(d) {
    const map = d.map;
    const trail = d.trail || [];
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    // grid
    ctx.strokeStyle = "rgba(94,231,255,0.08)";
    ctx.lineWidth = 1;
    const step = Math.max(18, Math.floor(w / 16));
    for (let x = 0; x < w; x += step) {
      ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
    }
    for (let y = 0; y < h; y += step) {
      ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
    }

    if (!map || map.x == null) {
      ctx.fillStyle = "rgba(111,138,163,0.7)";
      ctx.font = `${Math.floor(h * 0.08)}px monospace`;
      ctx.textAlign = "center";
      ctx.fillText("MotionSim bekleniyor…", w / 2, h / 2);
      if (meta) meta.textContent = "harita yok · MotionSim aç";
      return;
    }

    // scale around car
    const pts = trail.length ? trail : [{ x: map.x, y: map.y }];
    let minX = map.x, maxX = map.x, minY = map.y, maxY = map.y;
    for (const p of pts) {
      minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
    }
    // include projected route ahead
    const yaw = map.yaw || 0;
    const ahead = 60 + (map.speedMs || 0) * 4;
    const route = [];
    for (let i = 1; i <= 8; i++) {
      const dist = (ahead * i) / 8;
      route.push({
        x: map.x + Math.sin(yaw) * dist,
        y: map.y + Math.cos(yaw) * dist,
      });
    }
    for (const p of route) {
      minX = Math.min(minX, p.x); maxX = Math.max(maxX, p.x);
      minY = Math.min(minY, p.y); maxY = Math.max(maxY, p.y);
    }

    const pad = 28;
    const span = Math.max(40, maxX - minX, maxY - minY) * 1.25;
    const cx = (minX + maxX) / 2;
    const cy = (minY + maxY) / 2;
    const scale = Math.min((w - pad * 2) / span, (h - pad * 2) / span);

    const tx = (x) => w / 2 + (x - cx) * scale;
    // BeamNG Y often forward; flip canvas Y for screen
    const ty = (y) => h / 2 - (y - cy) * scale;

    // trail
    if (pts.length > 1) {
      ctx.beginPath();
      ctx.strokeStyle = "rgba(94,231,255,0.45)";
      ctx.lineWidth = 2;
      ctx.moveTo(tx(pts[0].x), ty(pts[0].y));
      for (let i = 1; i < pts.length; i++) ctx.lineTo(tx(pts[i].x), ty(pts[i].y));
      ctx.stroke();
    }

    // projected route (heading-based guidance ribbon)
    ctx.beginPath();
    ctx.strokeStyle = "rgba(61,255,176,0.75)";
    ctx.setLineDash([8, 6]);
    ctx.lineWidth = 2.5;
    ctx.moveTo(tx(map.x), ty(map.y));
    for (const p of route) ctx.lineTo(tx(p.x), ty(p.y));
    ctx.stroke();
    ctx.setLineDash([]);

    // destination diamond at end of route
    const dest = route[route.length - 1];
    ctx.fillStyle = "#3dffb0";
    ctx.beginPath();
    const dx = tx(dest.x), dy = ty(dest.y);
    ctx.moveTo(dx, dy - 7); ctx.lineTo(dx + 7, dy); ctx.lineTo(dx, dy + 7); ctx.lineTo(dx - 7, dy);
    ctx.closePath(); ctx.fill();

    // car wedge
    const x = tx(map.x), y = ty(map.y);
    ctx.save();
    ctx.translate(x, y);
    // screen angle: yaw in world → canvas
    ctx.rotate(-yaw);
    ctx.fillStyle = "#5ee7ff";
    ctx.strokeStyle = "#e9f7ff";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(0, -10);
    ctx.lineTo(7, 9);
    ctx.lineTo(0, 5);
    ctx.lineTo(-7, 9);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();
    ctx.restore();

    // ring
    ctx.strokeStyle = "rgba(94,231,255,0.35)";
    ctx.beginPath();
    ctx.arc(x, y, 14, 0, Math.PI * 2);
    ctx.stroke();

    const spd = (map.speedMs || 0) * 3.6;
    if (meta) {
      meta.textContent = `${spd.toFixed(0)} km/h · rota ${ahead.toFixed(0)} m`;
    }
  }

  window.EymenMap = { update, resize };
})();
