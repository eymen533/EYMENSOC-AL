package com.teslapulse.phonekey

import java.security.MessageDigest

/** Tesla VCSEC add-key-request (same as tesla-control add-key-request). */
object VcsecPayload {
    const val SERVICE_UUID = "00000211-b2d1-43f0-9b88-960cebf8b91e"
    const val WRITE_UUID = "00000212-b2d1-43f0-9b88-960cebf8b91e"
    const val READ_UUID = "00000213-b2d1-43f0-9b88-960cebf8b91e"

    private const val ROLE_OWNER = 2L
    private const val FORM_ANDROID = 7L
    private const val SIG_PRESENT_KEY = 2L

    fun bleLocalName(vin: String): String {
        val digest = MessageDigest.getInstance("SHA-1")
            .digest(vin.uppercase().toByteArray(Charsets.UTF_8))
        val hex = digest.take(8).joinToString("") { b -> "%02x".format(b) }
        return "S${hex}C"
    }

    fun bleNames(vin: String): List<String> {
        val v = vin.uppercase()
        val tail = v.takeLast(6)
        return listOf(bleLocalName(v), "Tesla $tail", "Tesla$tail")
    }

    fun addKeyRequest(publicKeyUncompressed: ByteArray): ByteArray {
        require(publicKeyUncompressed.size == 65 && publicKeyUncompressed[0] == 0x04.toByte()) {
            "Public key must be X9.62 uncompressed (65 bytes)"
        }
        val publicKey = fieldBytes(1, publicKeyUncompressed)
        val permissionChange = fieldBytes(1, publicKey) + fieldVarint(4, ROLE_OWNER)
        val metadata = fieldVarint(1, FORM_ANDROID)
        val whitelistOp = fieldBytes(5, permissionChange) + fieldBytes(6, metadata)
        val unsigned = fieldBytes(16, whitelistOp)
        val signed = fieldBytes(2, unsigned) + fieldVarint(3, SIG_PRESENT_KEY)
        val envelope = fieldBytes(1, signed)
        return prependLength(envelope)
    }

    private fun prependLength(message: ByteArray): ByteArray {
        return byteArrayOf(
            (message.size shr 8).toByte(),
            (message.size and 0xFF).toByte(),
        ) + message
    }

    private fun fieldVarint(number: Long, value: Long): ByteArray =
        tag(number, 0) + encodeVarint(value)

    private fun fieldBytes(number: Long, data: ByteArray): ByteArray =
        tag(number, 2) + encodeVarint(data.size.toLong()) + data

    private fun tag(number: Long, wire: Long): ByteArray =
        encodeVarint((number shl 3) or wire)

    private fun encodeVarint(value: Long): ByteArray {
        var v = value
        val out = ArrayList<Byte>(10)
        while (true) {
            var b = (v and 0x7F).toInt()
            v = v ushr 7
            if (v != 0L) b = b or 0x80
            out.add(b.toByte())
            if (v == 0L) break
        }
        return out.toByteArray()
    }
}
