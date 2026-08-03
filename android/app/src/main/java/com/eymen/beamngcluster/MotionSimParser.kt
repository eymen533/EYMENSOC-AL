package com.eymen.beamngcluster

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.sqrt

data class MotionSimData(
    val posX: Float,
    val posY: Float,
    val posZ: Float,
    val velX: Float,
    val velY: Float,
    val velZ: Float,
    val yawPos: Float,
    val speedMs: Float,
)

object MotionSimParser {
    private const val SIZE = 88

    fun parse(bytes: ByteArray): MotionSimData? {
        if (bytes.size < SIZE) return null
        if (bytes[0] != 'B'.code.toByte() || bytes[1] != 'N'.code.toByte() ||
            bytes[2] != 'G'.code.toByte() || bytes[3] != '1'.code.toByte()
        ) return null

        val buf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        buf.position(4)
        fun f() = buf.float
        val posX = f(); val posY = f(); val posZ = f()
        val velX = f(); val velY = f(); val velZ = f()
        repeat(6) { f() } // accXYZ + upXYZ
        f(); f() // roll, pitch
        val yawPos = f()
        val speedMs = sqrt(velX * velX + velY * velY + velZ * velZ)
        return MotionSimData(posX, posY, posZ, velX, velY, velZ, yawPos, speedMs)
    }
}
