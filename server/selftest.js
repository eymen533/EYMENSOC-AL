/**
 * Quick self-check for OutGauge binary layout packing/parsing.
 * Run: node server/selftest.js
 */
const assert = require("assert");
const { parseOutGauge } = require("./outgauge");

function packOutGauge(fields) {
  const buf = Buffer.alloc(96);
  let o = 0;
  buf.writeUInt32LE(fields.time ?? 0, o); o += 4;
  buf.write(fields.car ?? "beam", o, 4, "ascii"); o += 4;
  buf.writeUInt16LE(fields.flags ?? 16384, o); o += 2;
  buf.writeInt8(fields.gear ?? 3, o); o += 1; // 3 => gear 2
  buf.writeUInt8(fields.plid ?? 0, o); o += 1;
  buf.writeFloatLE(fields.speed ?? 27.7778, o); o += 4; // ~100 km/h
  buf.writeFloatLE(fields.rpm ?? 3200, o); o += 4;
  buf.writeFloatLE(fields.turbo ?? 0.8, o); o += 4;
  buf.writeFloatLE(fields.engTemp ?? 90, o); o += 4;
  buf.writeFloatLE(fields.fuel ?? 0.5, o); o += 4;
  buf.writeFloatLE(fields.oilPressure ?? 0, o); o += 4;
  buf.writeFloatLE(fields.oilTemp ?? 95, o); o += 4;
  buf.writeUInt32LE(fields.dashLights ?? 0xffff, o); o += 4;
  buf.writeUInt32LE(fields.showLights ?? (1 << 1), o); o += 4; // fullbeam
  buf.writeFloatLE(fields.throttle ?? 0.4, o); o += 4;
  buf.writeFloatLE(fields.brake ?? 0.1, o); o += 4;
  buf.writeFloatLE(fields.clutch ?? 0, o); o += 4;
  buf.write("", o, 16, "ascii"); o += 16;
  buf.write("", o, 16, "ascii"); o += 16;
  buf.writeInt32LE(fields.id ?? 0, o);
  return buf;
}

const parsed = parseOutGauge(packOutGauge({}));
assert.ok(parsed, "parse failed");
assert.strictEqual(parsed.car, "beam");
assert.strictEqual(parsed.gearLabel, "2");
assert.ok(Math.abs(parsed.speedKmh - 100) < 0.5, `speed ${parsed.speedKmh}`);
assert.ok(Math.abs(parsed.rpm - 3200) < 0.01);
assert.strictEqual(parsed.lights.fullbeam, true);
assert.strictEqual(parsed.preferKm, true);
assert.strictEqual(parseOutGauge(Buffer.alloc(10)), null);

console.log("selftest OK");
