package com.eymen.beamngcluster

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min

data class OutGaugeData(
    val gearLabel: String,
    val speedKmh: Float,
    val speedMph: Float,
    val preferKm: Boolean,
    val rpm: Float,
    val turbo: Float,
    val engTemp: Float,
    val fuel: Float,
    val throttle: Float,
    val brake: Float,
    val clutch: Float,
    val showTurbo: Boolean,
    val shift: Boolean,
    val fullbeam: Boolean,
    val handbrake: Boolean,
    val tc: Boolean,
    val signalL: Boolean,
    val signalR: Boolean,
    val oilWarn: Boolean,
    val battery: Boolean,
    val abs: Boolean,
    val source: String = "outgauge",
)

object OutGaugeParser {
    private const val OG_TURBO = 8192
    private const val OG_KM = 16384
    private const val MIN_SIZE = 64

    private const val DL_SHIFT = 1
    private const val DL_FULLBEAM = 1 shl 1
    private const val DL_HANDBRAKE = 1 shl 2
    private const val DL_TC = 1 shl 4
    private const val DL_SIGNAL_L = 1 shl 5
    private const val DL_SIGNAL_R = 1 shl 6
    private const val DL_OILWARN = 1 shl 8
    private const val DL_BATTERY = 1 shl 9
    private const val DL_ABS = 1 shl 10

    fun parse(bytes: ByteArray): OutGaugeData? {
        if (bytes.size < MIN_SIZE) return null
        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        buf.int // time
        val carBytes = ByteArray(4)
        buf.get(carBytes)
        val flags = buf.short.toInt() and 0xffff
        val gearRaw = buf.get().toInt()
        buf.get() // plid
        val speed = buf.float
        val rpm = buf.float
        val turbo = buf.float
        val engTemp = buf.float
        val fuel = buf.float
        buf.float // oilPressure
        buf.float // oilTemp
        buf.int // dashLights
        val showLights = buf.int
        val throttle = buf.float
        val brake = buf.float
        val clutch = buf.float

        val preferKm = flags and OG_KM != 0
        val speedMs = max(0f, speed)
        val gearLabel = when {
            gearRaw <= 0 -> "R"
            gearRaw == 1 -> "N"
            else -> (gearRaw - 1).toString()
        }

        fun bit(mask: Int) = showLights and mask != 0

        return OutGaugeData(
            gearLabel = gearLabel,
            speedKmh = speedMs * 3.6f,
            speedMph = speedMs * 2.2369363f,
            preferKm = preferKm,
            rpm = max(0f, rpm),
            turbo = turbo,
            engTemp = engTemp,
            fuel = clamp01(fuel),
            throttle = clamp01(throttle),
            brake = clamp01(brake),
            clutch = clamp01(clutch),
            showTurbo = flags and OG_TURBO != 0,
            shift = bit(DL_SHIFT),
            fullbeam = bit(DL_FULLBEAM),
            handbrake = bit(DL_HANDBRAKE),
            tc = bit(DL_TC),
            signalL = bit(DL_SIGNAL_L),
            signalR = bit(DL_SIGNAL_R),
            oilWarn = bit(DL_OILWARN),
            battery = bit(DL_BATTERY),
            abs = bit(DL_ABS),
            source = "outgauge",
        )
    }

    private fun clamp01(v: Float): Float = min(1f, max(0f, v))
}
