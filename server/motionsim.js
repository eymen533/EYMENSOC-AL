/**
 * BeamNG MotionSim UDP parser (BNG1).
 * @see https://documentation.beamng.com/modding/protocols/
 */

const HEADER = "BNG1";
const SIZE = 88; // 4 + 21*float

function parseMotionSim(buf) {
  if (!buf || buf.length < SIZE) return null;
  const magic = buf.toString("ascii", 0, 4);
  if (magic !== HEADER) return null;

  let o = 4;
  const f = () => {
    const v = buf.readFloatLE(o);
    o += 4;
    return v;
  };

  const posX = f(),
    posY = f(),
    posZ = f();
  const velX = f(),
    velY = f(),
    velZ = f();
  const accX = f(),
    accY = f(),
    accZ = f();
  const upX = f(),
    upY = f(),
    upZ = f();
  const rollPos = f(),
    pitchPos = f(),
    yawPos = f();
  const rollVel = f(),
    pitchVel = f(),
    yawVel = f();
  const rollAcc = f(),
    pitchAcc = f(),
    yawAcc = f();

  const speedMs = Math.sqrt(velX * velX + velY * velY + velZ * velZ);

  return {
    posX,
    posY,
    posZ,
    velX,
    velY,
    velZ,
    accX,
    accY,
    accZ,
    upX,
    upY,
    upZ,
    rollPos,
    pitchPos,
    yawPos,
    rollVel,
    pitchVel,
    yawVel,
    rollAcc,
    pitchAcc,
    yawAcc,
    speedMs,
  };
}

module.exports = { parseMotionSim, SIZE, HEADER };
