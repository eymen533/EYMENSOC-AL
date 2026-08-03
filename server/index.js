#!/usr/bin/env node
/**
 * EYMEN BeamNG Cluster Bridge
 *
 * BeamNG → 127.0.0.1 (OutGauge 4444 + MotionSim 4445)
 * Telefon → PC_IP:8080 (WebSocket + kadran UI)
 *
 * Çift tık: EYMEN-Cluster-Baslat.bat
 */

const dgram = require("dgram");
const http = require("http");
const fs = require("fs");
const path = require("path");
const os = require("os");
const { WebSocketServer } = require("./ws");
const { parseOutGauge } = require("./outgauge");
const { parseMotionSim } = require("./motionsim");

const OUTGAUGE_PORT = Number(process.env.OUTGAUGE_PORT || 4444);
const MOTIONSIM_PORT = Number(process.env.MOTIONSIM_PORT || 4445);
const HTTP_PORT = Number(process.env.HTTP_PORT || 8080);
const DEMO = process.argv.includes("--demo") || process.env.DEMO === "1";
const PUBLIC = path.join(__dirname, "..", "public");

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".webmanifest": "application/manifest+json",
};

const clients = new Set();
let state = {
  outgauge: null,
  motion: null,
  trail: [],
};
let packetOut = 0;
let packetMot = 0;
let lastPacketAt = 0;

function localIPs() {
  const nets = os.networkInterfaces();
  const result = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === "IPv4" && !net.internal) result.push(net.address);
    }
  }
  return result;
}

function broadcast(obj) {
  const raw = JSON.stringify(obj);
  for (const ws of clients) {
    try {
      ws.send(raw);
    } catch {
      clients.delete(ws);
    }
  }
}

function emit() {
  lastPacketAt = Date.now();
  const og = state.outgauge || {};
  const mot = state.motion || {};
  const merged = {
    ...og,
    source: DEMO ? "demo" : "live",
    receivedAt: Date.now(),
    map: mot.posX != null
      ? {
          x: mot.posX,
          y: mot.posY,
          z: mot.posZ,
          yaw: mot.yawPos || 0,
          velX: mot.velX || 0,
          velY: mot.velY || 0,
          speedMs: mot.speedMs || og.speedMs || 0,
        }
      : null,
    trail: state.trail.slice(-200),
  };
  broadcast({ type: "telemetry", data: merged });
}

function pushOutgauge(data) {
  state.outgauge = data;
  packetOut += 1;
  emit();
}

function pushMotion(data) {
  state.motion = data;
  packetMot += 1;
  const last = state.trail[state.trail.length - 1];
  if (!last || Math.hypot(data.posX - last.x, data.posY - last.y) > 1.5) {
    state.trail.push({ x: data.posX, y: data.posY, t: Date.now() });
    if (state.trail.length > 400) state.trail.splice(0, state.trail.length - 400);
  }
  emit();
}

const server = http.createServer((req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  if (req.url === "/api/status") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(
      JSON.stringify({
        ok: true,
        demo: DEMO,
        outgaugePort: OUTGAUGE_PORT,
        motionSimPort: MOTIONSIM_PORT,
        httpPort: HTTP_PORT,
        clients: clients.size,
        packetOut,
        packetMot,
        lastPacketAt,
        ips: localIPs(),
        connected: DEMO || Date.now() - lastPacketAt < 2000,
      })
    );
    return;
  }

  let urlPath = decodeURIComponent((req.url || "/").split("?")[0]);
  if (urlPath === "/") urlPath = "/index.html";
  const filePath = path.normalize(path.join(PUBLIC, urlPath));
  if (!filePath.startsWith(PUBLIC)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404);
      res.end("Not found");
      return;
    }
    const ext = path.extname(filePath);
    res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream" });
    res.end(data);
  });
});

const wss = new WebSocketServer(server);
wss.on("connection", (ws) => {
  clients.add(ws);
  ws.send(
    JSON.stringify({
      type: "hello",
      demo: DEMO,
      ips: localIPs(),
      outgaugePort: OUTGAUGE_PORT,
      motionSimPort: MOTIONSIM_PORT,
    })
  );
  if (state.outgauge || state.motion) emit();
  ws.on("close", () => clients.delete(ws));
});

function bindUdp(port, label, handler) {
  const udp = dgram.createSocket("udp4");
  udp.on("message", handler);
  udp.on("error", (err) => console.error(`[${label}]`, err.message));
  udp.bind(port, "0.0.0.0", () => console.log(`[${label}] UDP ${port}`));
  return udp;
}

function startDemo() {
  let t = 0;
  const OG_KM = 16384;
  setInterval(() => {
    t += 0.05;
    const speedKmh = 40 + 80 * (0.5 + 0.5 * Math.sin(t * 0.35));
    const rpm = 1200 + 4800 * (0.45 + 0.45 * Math.sin(t * 0.7));
    const gearNum = Math.min(6, Math.max(1, Math.floor(speedKmh / 28) + 1));
    const blink = Math.floor(t * 2) % 2 === 0;
    const ang = t * 0.4;
    const r = 80 + 20 * Math.sin(t * 0.1);
    pushOutgauge({
      time: Date.now() % 1e9,
      car: "demo",
      flags: OG_KM,
      gear: gearNum + 1,
      gearLabel: String(gearNum),
      speedMs: speedKmh / 3.6,
      speedKmh,
      speedMph: speedKmh * 0.621371,
      preferKm: true,
      rpm,
      turbo: 0.4 + 0.6 * Math.max(0, Math.sin(t)),
      engTemp: 88 + 4 * Math.sin(t * 0.2),
      fuel: 0.62,
      oilPressure: 3.2,
      oilTemp: 95,
      throttle: 0.3 + 0.5 * (0.5 + 0.5 * Math.sin(t * 0.7)),
      brake: Math.max(0, Math.sin(t * 0.2) - 0.7),
      clutch: 0,
      lights: {
        shift: rpm > 5500,
        fullbeam: true,
        handbrake: false,
        tc: false,
        signalL: blink && Math.sin(t * 0.15) > 0.7,
        signalR: false,
        oilWarn: false,
        battery: false,
        abs: false,
      },
      showTurbo: true,
      preferBar: true,
    });
    pushMotion({
      posX: Math.cos(ang) * r,
      posY: Math.sin(ang) * r,
      posZ: 0,
      velX: -Math.sin(ang) * (speedKmh / 3.6),
      velY: Math.cos(ang) * (speedKmh / 3.6),
      velZ: 0,
      accX: 0,
      accY: 0,
      accZ: 0,
      upX: 0,
      upY: 0,
      upZ: 1,
      rollPos: 0,
      pitchPos: 0,
      yawPos: ang + Math.PI / 2,
      rollVel: 0,
      pitchVel: 0,
      yawVel: 0.4,
      rollAcc: 0,
      pitchAcc: 0,
      yawAcc: 0,
      speedMs: speedKmh / 3.6,
    });
  }, 50);
}

server.listen(HTTP_PORT, "0.0.0.0", () => {
  const ips = localIPs();
  console.log("");
  console.log("  ========================================");
  console.log("   EYMEN BeamNG Digital Cluster Bridge");
  console.log("  ========================================");
  console.log(`   Mod: ${DEMO ? "DEMO" : "LIVE"}`);
  console.log(`   Telefon adresi (PC IP):`);
  for (const ip of ips) console.log(`      →  http://${ip}:${HTTP_PORT}`);
  console.log("");
  if (!DEMO) {
    console.log("   BeamNG ayarları (localhost!):");
    console.log(`      OutGauge  → 127.0.0.1  port ${OUTGAUGE_PORT}`);
    console.log(`      MotionSim → 127.0.0.1  port ${MOTIONSIM_PORT}`);
    console.log("   Sonra Ctrl+R ile aracı yenile.");
  }
  console.log("  ========================================");
  console.log("");
});

if (DEMO) {
  startDemo();
} else {
  bindUdp(OUTGAUGE_PORT, "outgauge", (msg) => {
    const p = parseOutGauge(msg);
    if (p) pushOutgauge(p);
  });
  bindUdp(MOTIONSIM_PORT, "motionsim", (msg) => {
    const p = parseMotionSim(msg);
    if (p) pushMotion(p);
  });
}

setInterval(() => {
  broadcast({
    type: "status",
    demo: DEMO,
    packetOut,
    packetMot,
    lastPacketAt,
    connected: DEMO || (lastPacketAt > 0 && Date.now() - lastPacketAt < 2000),
    clients: clients.size,
    ips: localIPs(),
  });
}, 1000);
