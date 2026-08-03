/**
 * Minimal WebSocket server (RFC 6455) — zero dependencies.
 */
const crypto = require("crypto");
const { EventEmitter } = require("events");

const GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";

class WebSocket extends EventEmitter {
  constructor(socket) {
    super();
    this.socket = socket;
    this.closed = false;
    this._buffer = Buffer.alloc(0);
    socket.on("data", (chunk) => this._onData(chunk));
    socket.on("close", () => this._close());
    socket.on("error", () => this._close());
  }

  send(data) {
    if (this.closed) return;
    const payload = Buffer.from(typeof data === "string" ? data : JSON.stringify(data));
    this.socket.write(frameText(payload));
  }

  close() {
    if (this.closed) return;
    try {
      this.socket.end();
    } catch {
      /* ignore */
    }
    this._close();
  }

  _close() {
    if (this.closed) return;
    this.closed = true;
    this.emit("close");
  }

  _onData(chunk) {
    this._buffer = Buffer.concat([this._buffer, chunk]);
    while (true) {
      const frame = tryParseFrame(this._buffer);
      if (!frame) break;
      this._buffer = this._buffer.subarray(frame.consumed);
      if (frame.opcode === 0x8) {
        this.close();
        return;
      }
      if (frame.opcode === 0x9) {
        // ping → pong
        this.socket.write(frameRaw(0xa, frame.payload));
        continue;
      }
      if (frame.opcode === 0x1 || frame.opcode === 0x2) {
        this.emit("message", frame.payload.toString("utf8"));
      }
    }
  }
}

class WebSocketServer extends EventEmitter {
  constructor(httpServer) {
    super();
    httpServer.on("upgrade", (req, socket, head) => {
      const key = req.headers["sec-websocket-key"];
      if (!key || req.headers.upgrade?.toLowerCase() !== "websocket") {
        socket.destroy();
        return;
      }
      const accept = crypto.createHash("sha1").update(key + GUID).digest("base64");
      socket.write(
        "HTTP/1.1 101 Switching Protocols\r\n" +
          "Upgrade: websocket\r\n" +
          "Connection: Upgrade\r\n" +
          `Sec-WebSocket-Accept: ${accept}\r\n` +
          "\r\n"
      );
      const ws = new WebSocket(socket);
      if (head && head.length) ws._onData(head);
      this.emit("connection", ws, req);
    });
  }
}

function frameText(payload) {
  return frameRaw(0x1, payload);
}

function frameRaw(opcode, payload) {
  const len = payload.length;
  let header;
  if (len < 126) {
    header = Buffer.alloc(2);
    header[0] = 0x80 | opcode;
    header[1] = len;
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x80 | opcode;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x80 | opcode;
    header[1] = 127;
    header.writeUInt32BE(0, 2);
    header.writeUInt32BE(len, 6);
  }
  return Buffer.concat([header, payload]);
}

function tryParseFrame(buf) {
  if (buf.length < 2) return null;
  const second = buf[1];
  const masked = (second & 0x80) !== 0;
  let payloadLen = second & 0x7f;
  let offset = 2;
  if (payloadLen === 126) {
    if (buf.length < 4) return null;
    payloadLen = buf.readUInt16BE(2);
    offset = 4;
  } else if (payloadLen === 127) {
    if (buf.length < 10) return null;
    payloadLen = Number(buf.readBigUInt64BE(2));
    offset = 10;
  }
  const maskLen = masked ? 4 : 0;
  if (buf.length < offset + maskLen + payloadLen) return null;
  let payload = buf.subarray(offset + maskLen, offset + maskLen + payloadLen);
  if (masked) {
    const mask = buf.subarray(offset, offset + 4);
    payload = Buffer.from(payload);
    for (let i = 0; i < payload.length; i++) payload[i] ^= mask[i % 4];
  }
  return {
    opcode: buf[0] & 0x0f,
    payload,
    consumed: offset + maskLen + payloadLen,
  };
}

module.exports = { WebSocketServer, WebSocket };
