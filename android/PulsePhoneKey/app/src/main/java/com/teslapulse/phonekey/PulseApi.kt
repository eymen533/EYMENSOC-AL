package com.teslapulse.phonekey

import android.content.Context
import android.webkit.CookieManager
import org.json.JSONObject
import java.io.BufferedReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

object PulseApi {
    private val io = Executors.newCachedThreadPool()

    data class Result(val ok: Boolean, val body: JSONObject?, val error: String?, val code: Int)

    fun unlockAsync(context: Context, pin: String, cb: (Result) -> Unit) {
        io.execute {
            val r = postJson(context, "/api/auth/unlock", JSONObject().put("pin", pin))
            val unlocked = r.code in 200..299 && r.body?.optBoolean("unlocked", false) == true
            cb(r.copy(ok = unlocked, error = r.error ?: r.body?.optString("error")))
        }
    }

    fun hudPairAsync(context: Context, vin: String, cb: (Result) -> Unit) {
        io.execute {
            postJson(context, "/api/ble/vin", JSONObject().put("vin", vin))
            postJson(context, "/api/ble/card", JSONObject())
            val r = postJson(
                context,
                "/api/ble/pair",
                JSONObject()
                    .put("vin", vin)
                    .put("card_tapped", true)
                    .put("source", "web"),
            )
            cb(r.copy(ok = r.code in 200..299 && r.body?.optBoolean("ok", true) != false))
        }
    }

    private fun postJson(context: Context, path: String, body: JSONObject): Result {
        return try {
            val base = AppPrefs.serverUrl(context)
            val url = URL(base + path)
            val conn = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = 15000
                readTimeout = 20000
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
                setRequestProperty("Accept", "application/json")
                instanceFollowRedirects = false
                val cookie = CookieManager.getInstance().getCookie(base)
                if (!cookie.isNullOrBlank()) setRequestProperty("Cookie", cookie)
            }
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { it.write(body.toString()) }
            val code = conn.responseCode
            val stream = if (code in 200..299) conn.inputStream else conn.errorStream
            val text = stream?.bufferedReader()?.use(BufferedReader::readText).orEmpty()
            conn.headerFields.forEach { (k, values) ->
                if (k != null && k.equals("Set-Cookie", ignoreCase = true)) {
                    values.forEach { raw ->
                        CookieManager.getInstance().setCookie(base, raw.substringBefore(";"))
                    }
                }
            }
            CookieManager.getInstance().flush()
            val json = if (text.isNotBlank()) JSONObject(text) else null
            Result(
                ok = code in 200..299,
                body = json,
                error = json?.optString("error")?.ifBlank { null },
                code = code,
            )
        } catch (e: Exception) {
            Result(false, null, e.message ?: "network", -1)
        }
    }
}
