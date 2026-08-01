package com.teslapulse.phonekey

import android.content.Context
import android.util.Base64
import org.bouncycastle.jce.ECNamedCurveTable
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.jce.spec.ECNamedCurveSpec
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.Security
import java.security.interfaces.ECPrivateKey
import java.security.interfaces.ECPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.ECPoint
import java.security.spec.ECPrivateKeySpec
import java.security.spec.ECPublicKeySpec

object PulseKeyStore {
    private const val PREFS = "pulse_phone_key"
    private const val KEY_D = "ec_d_b64"

    init {
        if (Security.getProvider(BouncyCastleProvider.PROVIDER_NAME) == null) {
            Security.insertProviderAt(BouncyCastleProvider(), 1)
        }
    }

    fun loadOrCreatePublicUncompressed(context: Context): ByteArray {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val existing = prefs.getString(KEY_D, null)
        val privateKey: ECPrivateKey = if (existing != null) {
            decodePrivate(Base64.decode(existing, Base64.NO_WRAP))
        } else {
            val kp = KeyPairGenerator.getInstance("EC").apply {
                initialize(ECGenParameterSpec("secp256r1"))
            }.generateKeyPair()
            val priv = kp.private as ECPrivateKey
            prefs.edit()
                .putString(KEY_D, Base64.encodeToString(priv.s.toByteArray(), Base64.NO_WRAP))
                .apply()
            priv
        }
        return publicUncompressed(privateKey)
    }

    private fun curveSpec(): ECNamedCurveSpec {
        val params = ECNamedCurveTable.getParameterSpec("secp256r1")
        return ECNamedCurveSpec("secp256r1", params.curve, params.g, params.n, params.h, params.seed)
    }

    private fun decodePrivate(dBytes: ByteArray): ECPrivateKey {
        val d = java.math.BigInteger(1, dBytes)
        val spec = ECPrivateKeySpec(d, curveSpec())
        return KeyFactory.getInstance("EC").generatePrivate(spec) as ECPrivateKey
    }

    private fun publicUncompressed(privateKey: ECPrivateKey): ByteArray {
        val params = ECNamedCurveTable.getParameterSpec("secp256r1")
        val q = params.g.multiply(privateKey.s).normalize()
        val x = q.affineXCoord.toBigInteger()
        val y = q.affineYCoord.toBigInteger()
        val pubSpec = ECPublicKeySpec(ECPoint(x, y), curveSpec())
        val pub = KeyFactory.getInstance("EC").generatePublic(pubSpec) as ECPublicKey
        val xb = toFixed(pub.w.affineX, 32)
        val yb = toFixed(pub.w.affineY, 32)
        return byteArrayOf(0x04) + xb + yb
    }

    private fun toFixed(n: java.math.BigInteger, size: Int): ByteArray {
        var b = n.toByteArray()
        if (b.size == size) return b
        if (b.size == size + 1 && b[0] == 0.toByte()) return b.copyOfRange(1, b.size)
        if (b.size > size) return b.copyOfRange(b.size - size, b.size)
        return ByteArray(size - b.size) + b
    }
}
