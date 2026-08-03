/**
 * Live for Speed / BeamNG.drive OutGauge UDP packet parser.
 * @see https://documentation.beamng.com/modding/protocols/
 */

const OG_TURBO = 8192;
const OG_KM = 16384;
const OG_BAR = 32768;

const DL = {
  SHIFT: 1 << 0,
  FULLBEAM: 1 << 1,
  HANDBRAKE: 1 << 2,
  PITSPEED: 1 << 3,
  TC: 1 << 4,
  SIGNAL_L: 1 << 5,
  SIGNAL_R: 1 << 6,
  SIGNAL_ANY: 1 << 7,
  OILWARN: 1 << 8,
  BATTERY: 1 << 9,
  ABS: 1 << 10,
};

/** Minimum packet size without optional id field */
const MIN_SIZE = 92;

/**
 * @param {Buffer} buf
 * @returns {object|null}
 */
function parseOutGauge(buf) {
  if (!buf || buf.length < MIN_SIZE) return null;

  let offset = 0;
  const time = buf.readUInt32LE(offset); offset += 4;
  const car = buf.toString("ascii", offset, offset + 4).replace(/\0/g, ""); offset += 4;
  const flags = buf.readUInt16LE(offset); offset += 2;
  const gearRaw = buf.readInt8(offset); offset += 1;
  const plid = buf.readUInt8(offset); offset += 1;
  const speed = buf.readFloatLE(offset); offset += 4;
  const rpm = buf.readFloatLE(offset); offset += 4;
  const turbo = buf.readFloatLE(offset); offset += 4;
  const engTemp = buf.readFloatLE(offset); offset += 4;
  const fuel = buf.readFloatLE(offset); offset += 4;
  const oilPressure = buf.readFloatLE(offset); offset += 4;
  const oilTemp = buf.readFloatLE(offset); offset += 4;
  const dashLights = buf.readUInt32LE(offset); offset += 4;
  const showLights = buf.readUInt32LE(offset); offset += 4;
  const throttle = buf.readFloatLE(offset); offset += 4;
  const brake = buf.readFloatLE(offset); offset += 4;
  const clutch = buf.readFloatLE(offset); offset += 4;
  const display1 = buf.toString("ascii", offset, offset + 16).replace(/\0/g, ""); offset += 16;
  const display2 = buf.toString("ascii", offset, offset + 16).replace(/\0/g, ""); offset += 16;
  const id = buf.length >= offset + 4 ? buf.readInt32LE(offset) : 0;

  const preferKm = (flags & OG_KM) !== 0;
  const speedMs = Math.max(0, speed);
  const speedKmh = speedMs * 3.6;
  const speedMph = speedMs * 2.23693629;

  let gearLabel;
  if (gearRaw <= 0) gearLabel = "R";
  else if (gearRaw === 1) gearLabel = "N";
  else gearLabel = String(gearRaw - 1);

  return {
    time,
    car,
    flags,
    gear: gearRaw,
    gearLabel,
    plid,
    speedMs,
    speedKmh,
    speedMph,
    preferKm,
    rpm: Math.max(0, rpm),
    turbo,
    engTemp,
    fuel: clamp01(fuel),
    oilPressure,
    oilTemp,
    dashLights,
    showLights,
    throttle: clamp01(throttle),
    brake: clamp01(brake),
    clutch: clamp01(clutch),
    display1,
    display2,
    id,
    lights: {
      shift: bit(showLights, DL.SHIFT),
      fullbeam: bit(showLights, DL.FULLBEAM),
      handbrake: bit(showLights, DL.HANDBRAKE),
      tc: bit(showLights, DL.TC),
      signalL: bit(showLights, DL.SIGNAL_L),
      signalR: bit(showLights, DL.SIGNAL_R),
      oilWarn: bit(showLights, DL.OILWARN),
      battery: bit(showLights, DL.BATTERY),
      abs: bit(showLights, DL.ABS),
    },
    showTurbo: (flags & OG_TURBO) !== 0,
    preferBar: (flags & OG_BAR) !== 0,
  };
}

function clamp01(v) {
  if (!Number.isFinite(v)) return 0;
  return Math.min(1, Math.max(0, v));
}

function bit(value, mask) {
  return (value & mask) !== 0;
}

module.exports = { parseOutGauge, DL, OG_KM, OG_TURBO, OG_BAR };
