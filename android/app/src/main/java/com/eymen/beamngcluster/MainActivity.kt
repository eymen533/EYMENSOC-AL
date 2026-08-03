package com.eymen.beamngcluster

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.os.Bundle
import android.view.View
import android.webkit.JavascriptInterface
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.lifecycleScope
import com.eymen.beamngcluster.databinding.ActivityMainBinding
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.net.NetworkInterface
import kotlin.math.max
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private var listener: OutGaugeListener? = null
    private var demoJob: Job? = null
    private var clusterReady = false
    private var pendingJson: String? = null
    private var packetCount = 0
    private var phoneIp: String = "—"

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        hideSystemUi()

        val ips = localIpv4List()
        phoneIp = ips.firstOrNull()?.second ?: "Wi‑Fi yok"
        binding.ipValue.text = phoneIp
        binding.portValue.text = "Port $OUTGAUGE_PORT"
        if (ips.size > 1) {
            binding.btNote.text = getString(R.string.multi_ip_note, ips.joinToString(" · ") { "${it.first}:${it.second}" })
        }

        binding.btnCopy.setOnClickListener {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("ip", phoneIp))
            Toast.makeText(this, "IP kopyalandı", Toast.LENGTH_SHORT).show()
        }

        binding.btnStart.setOnClickListener { openCluster(demo = false) }
        binding.btnDemo.setOnClickListener { openCluster(demo = true) }

        binding.clusterWeb.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = WebSettings.LOAD_NO_CACHE
            allowFileAccess = true
        }
        binding.clusterWeb.addJavascriptInterface(JsBridge(), "EymenAndroid")
        binding.clusterWeb.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                clusterReady = true
                pushStatus("Dinleniyor · $phoneIp:$OUTGAUGE_PORT · paket: $packetCount")
                pendingJson?.let { pushToWeb(it) }
            }
        }
    }

    private fun openCluster(demo: Boolean) {
        binding.setupRoot.visibility = View.GONE
        binding.clusterWeb.visibility = View.VISIBLE
        clusterReady = false
        packetCount = 0
        binding.clusterWeb.loadUrl("file:///android_asset/index.html")

        demoJob?.cancel()
        listener?.stop()

        if (demo) {
            startDemo()
        } else {
            listener = OutGaugeListener(
                context = this,
                port = OUTGAUGE_PORT,
                scope = lifecycleScope,
                onListening = { ok ->
                    runOnUiThread {
                        if (ok) {
                            pushStatus("Dinleniyor · $phoneIp:$OUTGAUGE_PORT · paket: 0")
                        }
                    }
                },
                onRawPacket = { size, from ->
                    packetCount += 1
                    runOnUiThread {
                        pushStatus("Paket #$packetCount · $size byte · $from")
                    }
                },
                onPacket = { data -> pushTelemetry(data) },
                onError = { msg ->
                    runOnUiThread {
                        pushStatus(msg)
                        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
                    }
                },
            ).also { it.start() }
        }
    }

    private fun startDemo() {
        demoJob = lifecycleScope.launch {
            var t = 0.0
            while (isActive) {
                t += 0.05
                val speedKmh = (40 + 80 * (0.5 + 0.5 * sin(t * 0.35))).toFloat()
                val rpm = (1200 + 4800 * (0.45 + 0.45 * sin(t * 0.7))).toFloat()
                val gearNum = minOf(6, maxOf(1, (speedKmh / 28).toInt() + 1))
                val blink = (t * 2).toInt() % 2 == 0
                pushTelemetry(
                    OutGaugeData(
                        gearLabel = gearNum.toString(),
                        speedKmh = speedKmh,
                        speedMph = speedKmh * 0.621371f,
                        preferKm = true,
                        rpm = rpm,
                        turbo = (0.4 + 0.6 * max(0.0, sin(t))).toFloat(),
                        engTemp = (88 + 4 * sin(t * 0.2)).toFloat(),
                        fuel = 0.62f,
                        throttle = (0.3 + 0.5 * (0.5 + 0.5 * sin(t * 0.7))).toFloat(),
                        brake = max(0.0, sin(t * 0.2) - 0.7).toFloat(),
                        clutch = 0f,
                        showTurbo = true,
                        shift = rpm > 5500,
                        fullbeam = true,
                        handbrake = false,
                        tc = false,
                        signalL = blink && sin(t * 0.15) > 0.7,
                        signalR = false,
                        oilWarn = false,
                        battery = false,
                        abs = false,
                        source = "demo",
                    )
                )
                delay(50)
            }
        }
    }

    private fun pushTelemetry(data: OutGaugeData) {
        val json = JSONObject().apply {
            put("gearLabel", data.gearLabel)
            put("speedKmh", data.speedKmh.toDouble())
            put("speedMph", data.speedMph.toDouble())
            put("preferKm", data.preferKm)
            put("rpm", data.rpm.toDouble())
            put("turbo", data.turbo.toDouble())
            put("engTemp", data.engTemp.toDouble())
            put("fuel", data.fuel.toDouble())
            put("throttle", data.throttle.toDouble())
            put("brake", data.brake.toDouble())
            put("showTurbo", data.showTurbo)
            put("source", data.source)
            put("lights", JSONObject().apply {
                put("shift", data.shift)
                put("fullbeam", data.fullbeam)
                put("handbrake", data.handbrake)
                put("tc", data.tc)
                put("signalL", data.signalL)
                put("signalR", data.signalR)
                put("oilWarn", data.oilWarn)
                put("battery", data.battery)
                put("abs", data.abs)
            })
        }.toString()
        runOnUiThread { pushToWeb(json) }
    }

    private fun pushStatus(text: String) {
        if (!clusterReady) return
        val escaped = JSONObject.quote(text)
        binding.clusterWeb.evaluateJavascript(
            "window.__eymenStatus && window.__eymenStatus($escaped)",
            null,
        )
    }

    private fun pushToWeb(json: String) {
        if (!clusterReady) {
            pendingJson = json
            return
        }
        val escaped = JSONObject.quote(json)
        binding.clusterWeb.evaluateJavascript("window.__eymenPush && window.__eymenPush($escaped)", null)
    }

    private fun hideSystemUi() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    /** Prefer wlan* Wi‑Fi addresses first. */
    private fun localIpv4List(): List<Pair<String, String>> {
        val result = mutableListOf<Pair<String, String>>()
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return result
        for (intf in interfaces) {
            if (!intf.isUp || intf.isLoopback) continue
            val name = intf.name ?: continue
            for (addr in intf.inetAddresses) {
                if (addr.isLoopbackAddress) continue
                val host = addr.hostAddress ?: continue
                if (host.contains(':') || host.startsWith("169.254.")) continue
                result += name to host
            }
        }
        return result.sortedByDescending { (name, _) ->
            when {
                name.startsWith("wlan", ignoreCase = true) -> 3
                name.startsWith("wifi", ignoreCase = true) -> 2
                name.startsWith("eth", ignoreCase = true) -> 1
                else -> 0
            }
        }
    }

    override fun onDestroy() {
        demoJob?.cancel()
        listener?.stop()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (binding.clusterWeb.visibility == View.VISIBLE) {
            demoJob?.cancel()
            listener?.stop()
            binding.clusterWeb.visibility = View.GONE
            binding.setupRoot.visibility = View.VISIBLE
            clusterReady = false
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    inner class JsBridge {
        @JavascriptInterface
        fun ready() {
            // no-op
        }
    }

    companion object {
        const val OUTGAUGE_PORT = 4444
    }
}
