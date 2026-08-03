#!/usr/bin/env node
/**
 * BeamNG.drive OutGauge → WebSocket bridge + static digital cluster UI.
 *
 * Usage:
 *   npm start              # listen UDP 4444, serve UI on :8080
 *   npm run demo           # animated demo telemetry (no BeamNG needed)
 *   UDP_PORT=4444 HTTP_PORT=8080 npm start
 */

const dgram = require("dgram");
const http = require("http");
const fs = require("fs");
const path = require("path");
const { WebSocketServer } = require("./ws");
const { parseOutGauge } = require("./outgauge");

const UDP_PORT = Number(process.env.UDP_PORT || 4444);
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
  ".ico": "image/x-icon",
  ".webmanifest": "application/manifest+json",
};

const clients = new Set();
let lastTelemetry = null;
let packetCount = 0;
let lastPacketAt = 0;

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

function pushTelemetry(data, source) {
  lastTelemetry = { ...data, source, receivedAt: Date.now() };
  lastPacketAt = Date.now();
  packetCount += 1;
  broadcast({ type: "telemetry", data: lastTelemetry });
}

/* ---------- HTTP ---------- */
const server = http.createServer((req, res) => {
  if (req.url === "/api/status") {
    res.writeHead(200, { "Content-Type": "application/json", "Access-Control-Allow-Origin": "*" });
    res.end(
      JSON.stringify({
        ok: true,
        demo: DEMO,
        udpPort: UDP_PORT,
        httpPort: HTTP_PORT,
        clients: clients.size,
        packetCount,
        lastPacketAt,
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

/* ---------- WebSocket (same HTTP server) ---------- */
const wss = new WebSocketServer(server);
wss.on("connection", (ws) => {
  clients.add(ws);
  ws.send(
    JSON.stringify({
      type: "hello",
      demo: DEMO,
      udpPort: UDP_PORT,
      packetCount,
    })
  );
  if (lastTelemetry) {
    ws.send(JSON.stringify({ type: "telemetry", data: lastTelemetry }));
  }
  ws.on("close", () => clients.delete(ws));
});

/* ---------- OutGauge UDP ---------- */
const udp = dgram.createSocket("udp4");
udp.on("message", (msg) => {
  const parsed = parseOutGauge(msg);
  if (parsed) pushTelemetry(parsed, "outgauge");
});
udp.on("error", (err) => {
  console.error("[udp]", err.message);
});

/* ---------- Demo driver ---------- */
function startDemo() {
  let t = 0;
  setInterval(() => {
    t += 0.05;
    const speedKmh = 40 + 80 * (0.5 + 0.5 * Math.sin(t * 0.35));
    const rpm = 1200 + 4800 * (0.45 + 0.45 * Math.sin(t * 0.7));
    const gearNum = Math.min(6, Math.max(1, Math.floor(speedKmh / 28) + 1));
    const blink = Math.floor(t * 2) % 2 === 0;
    pushTelemetry(
      {
        time: Date.now() % 1e9,
        car: "demo",
        flags: OG_KM_FLAG,
        gear: gearNum + 1,
        gearLabel: String(gearNum),
        plid: 0,
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
        dashLights: 0xffff,
        showLights: 0,
        throttle: 0.3 + 0.5 * (0.5 + 0.5 * Math.sin(t * 0.7)),
        brake: Math.max(0, Math.sin(t * 0.2) - 0.7),
        clutch: 0,
        display1: "",
        display2: "",
        id: 0,
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
      },
      "demo"
    );
  }, 50);
}

const OG_KM_FLAG = 16384;

function localIPs() {
  const os = require("os");
  const nets = os.networkInterfaces();
  const result = [];
  for (const name of Object.keys(nets)) {
    for (const net of nets[name] || []) {
      if (net.family === "IPv4" && !net.internal) result.push(net.address);
    }
  }
  return result;
}

server.listen(HTTP_PORT, "0.0.0.0", () => {
  const ips = localIPs();
  console.log("");
  console.log("  EYMEN BeamNG Digital Cluster");
  console.log("  -----------------------------");
  console.log(`  Mod:      ${DEMO ? "DEMO (simülasyon)" : "OutGauge UDP"}`);
  console.log(`  Kadran:   http://localhost:${HTTP_PORT}`);
  for (const ip of ips) {
    console.log(`  Android:  http://${ip}:${HTTP_PORT}`);
  }
  if (!DEMO) {
    console.log(`  UDP:      ${UDP_PORT}  ← BeamNG OutGauge hedefi`);
    console.log("");
    console.log("  BeamNG: Options > Other > Protocols");
    console.log(`  OutGauge IP = bu PC'nin IP'si (veya Android IP'si değil — bridge bu PC'de)`);
    console.log(`  OutGauge Port = ${UDP_PORT}`);
  }
  console.log("");
});

if (DEMO) {
  startDemo();
} else {
  udp.bind(UDP_PORT, "0.0.0.0", () => {
    console.log(`[udp] Listening on 0.0.0.0:${UDP_PORT}`);
  });
}

// Keepalive: tell UI if stream went silent
setInterval(() => {
  broadcast({
    type: "status",
    demo: DEMO,
    packetCount,
    lastPacketAt,
    connected: DEMO || (lastPacketAt > 0 && Date.now() - lastPacketAt < 2000),
    clients: clients.size,
  });
}, 1000);
