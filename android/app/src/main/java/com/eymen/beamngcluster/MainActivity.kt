package com.eymen.beamngcluster

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.os.Bundle
import android.view.View
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
import org.json.JSONArray
import org.json.JSONObject
import java.net.NetworkInterface
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private var listener: UdpTelemetryListener? = null
    private var demoJob: Job? = null
    private var clusterReady = false
    private var pendingJson: String? = null
    private var phoneIp: String = "—"

    private var lastOut: OutGaugeData? = null
    private var lastMotion: MotionSimData? = null
    private val trail = JSONArray()
    private var packetOg = 0
    private var packetMs = 0

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        hideSystemUi()

        phoneIp = localWifiIpv4() ?: "Wi‑Fi yok"
        binding.ipValue.text = phoneIp
        binding.portValue.text = "OutGauge 4444 · MotionSim 4445"

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
        binding.clusterWeb.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                clusterReady = true
                pushStatus("Dinleniyor · $phoneIp · OG:$packetOg MS:$packetMs")
                pendingJson?.let { pushToWeb(it) }
            }
        }
    }

    private fun openCluster(demo: Boolean) {
        binding.setupRoot.visibility = View.GONE
        binding.clusterWeb.visibility = View.VISIBLE
        clusterReady = false
        packetOg = 0
        packetMs = 0
        while (trail.length() > 0) trail.remove(0)
        binding.clusterWeb.loadUrl("file:///android_asset/index.html")

        demoJob?.cancel()
        listener?.stop()

        if (demo) {
            startDemo()
        } else {
            listener = UdpTelemetryListener(
                context = this,
                scope = lifecycleScope,
                onListening = { port, ok ->
                    runOnUiThread {
                        if (ok) pushStatus("Port $port açık · $phoneIp · OG:$packetOg MS:$packetMs")
                    }
                },
                onRaw = { port, _, _ ->
                    if (port == OUTGAUGE_PORT) packetOg++ else packetMs++
                    runOnUiThread {
                        pushStatus("Paket OG:$packetOg MS:$packetMs · $phoneIp")
                    }
                },
                onOutGauge = { data ->
                    lastOut = data
                    pushMerged()
                },
                onMotion = { data ->
                    lastMotion = data
                    appendTrail(data.posX.toDouble(), data.posY.toDouble())
                    pushMerged()
                },
                onError = { msg ->
                    runOnUiThread {
                        pushStatus(msg)
                        Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
                    }
                },
            ).also { it.start(OUTGAUGE_PORT, MOTION_PORT) }
        }
    }

    private fun appendTrail(x: Double, y: Double) {
        val last = if (trail.length() > 0) trail.getJSONObject(trail.length() - 1) else null
        if (last == null ||
            kotlin.math.hypot(x - last.getDouble("x"), y - last.getDouble("y")) > 1.2
        ) {
            trail.put(JSONObject().put("x", x).put("y", y).put("t", System.currentTimeMillis()))
            while (trail.length() > 200) trail.remove(0)
        }
    }

    private fun pushMerged() {
        val og = lastOut
        val mot = lastMotion
        if (og == null && mot == null) return

        val json = JSONObject().apply {
            if (og != null) {
                put("gearLabel", og.gearLabel)
                put("speedKmh", og.speedKmh.toDouble())
                put("speedMph", og.speedMph.toDouble())
                put("preferKm", og.preferKm)
                put("rpm", og.rpm.toDouble())
                put("turbo", og.turbo.toDouble())
                put("engTemp", og.engTemp.toDouble())
                put("fuel", og.fuel.toDouble())
                put("throttle", og.throttle.toDouble())
                put("brake", og.brake.toDouble())
                put("showTurbo", og.showTurbo)
                put("lights", JSONObject().apply {
                    put("shift", og.shift)
                    put("fullbeam", og.fullbeam)
                    put("handbrake", og.handbrake)
                    put("tc", og.tc)
                    put("signalL", og.signalL)
                    put("signalR", og.signalR)
                    put("oilWarn", og.oilWarn)
                    put("battery", og.battery)
                    put("abs", og.abs)
                })
            } else {
                put("gearLabel", "N")
                put("speedKmh", (mot!!.speedMs * 3.6).toDouble())
                put("speedMph", (mot.speedMs * 2.236936).toDouble())
                put("preferKm", true)
                put("rpm", 0)
                put("fuel", 0)
                put("throttle", 0)
                put("brake", 0)
                put("engTemp", 0)
                put("lights", JSONObject())
            }
            put("source", "outgauge")
            if (mot != null) {
                put("map", JSONObject().apply {
                    put("x", mot.posX.toDouble())
                    put("y", mot.posY.toDouble())
                    put("z", mot.posZ.toDouble())
                    put("yaw", mot.yawPos.toDouble())
                    put("velX", mot.velX.toDouble())
                    put("velY", mot.velY.toDouble())
                    put("speedMs", mot.speedMs.toDouble())
                })
                put("trail", trail)
            }
        }.toString()
        runOnUiThread { pushToWeb(json) }
    }

    private fun startDemo() {
        demoJob = lifecycleScope.launch {
            delay(350)
            var t = 0.0
            while (isActive) {
                t += 0.05
                val speedKmh = 40 + 80 * (0.5 + 0.5 * sin(t * 0.35))
                val rpm = 1200 + 4800 * (0.45 + 0.45 * sin(t * 0.7))
                val gearNum = minOf(6, maxOf(1, (speedKmh / 28).toInt() + 1))
                val ang = t * 0.4
                val r = 80 + 20 * sin(t * 0.1)
                val x = cos(ang) * r
                val y = sin(ang) * r
                appendTrail(x, y)
                val json = JSONObject().apply {
                    put("gearLabel", gearNum.toString())
                    put("speedKmh", speedKmh)
                    put("speedMph", speedKmh * 0.621371)
                    put("preferKm", true)
                    put("rpm", rpm)
                    put("turbo", 0.4 + 0.6 * max(0.0, sin(t)))
                    put("engTemp", 88 + 4 * sin(t * 0.2))
                    put("fuel", 0.62)
                    put("throttle", 0.3 + 0.5 * (0.5 + 0.5 * sin(t * 0.7)))
                    put("brake", max(0.0, sin(t * 0.2) - 0.7))
                    put("showTurbo", true)
                    put("source", "demo")
                    put("lights", JSONObject().apply {
                        put("shift", rpm > 5500)
                        put("fullbeam", true)
                        put("handbrake", false)
                        put("tc", false)
                        put("signalL", (t * 2).toInt() % 2 == 0 && sin(t * 0.15) > 0.7)
                        put("signalR", false)
                        put("oilWarn", false)
                        put("battery", false)
                        put("abs", false)
                    })
                    put("map", JSONObject().apply {
                        put("x", x); put("y", y); put("z", 0)
                        put("yaw", ang + Math.PI / 2)
                        put("speedMs", speedKmh / 3.6)
                    })
                    put("trail", trail)
                }.toString()
                val escaped = JSONObject.quote(json)
                binding.clusterWeb.evaluateJavascript(
                    "window.__eymenPush && window.__eymenPush($escaped)",
                    null,
                )
                delay(50)
            }
        }
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

    private fun localWifiIpv4(): String? {
        val list = mutableListOf<Pair<String, String>>()
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return null
        for (intf in interfaces) {
            if (!intf.isUp || intf.isLoopback) continue
            val name = intf.name ?: continue
            for (addr in intf.inetAddresses) {
                val host = addr.hostAddress ?: continue
                if (addr.isLoopbackAddress || host.contains(':') || host.startsWith("169.254.")) continue
                list += name to host
            }
        }
        list.sortByDescending { (name, _) ->
            when {
                name.startsWith("wlan", true) -> 3
                name.startsWith("ap", true) -> 2
                name.startsWith("wifi", true) -> 2
                else -> 0
            }
        }
        return list.firstOrNull()?.second
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

    companion object {
        const val OUTGAUGE_PORT = 4444
        const val MOTION_PORT = 4445
    }
}
