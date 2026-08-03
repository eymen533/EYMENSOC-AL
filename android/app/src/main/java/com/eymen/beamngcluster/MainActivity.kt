package com.eymen.beamngcluster

import android.annotation.SuppressLint
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.net.wifi.WifiManager
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
import org.json.JSONArray
import org.json.JSONObject
import java.net.NetworkInterface
import java.util.concurrent.atomic.AtomicReference
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private var listener: UdpTelemetryListener? = null
    private var demoJob: Job? = null
    private var phoneIp: String = "—"
    private var clusterMode = false

    private var lastOut: OutGaugeData? = null
    private var lastMotion: MotionSimData? = null
    private val trail = JSONArray()
    private var packetOg = 0
    private var packetMs = 0

    /** HTML polls this — more reliable than evaluateJavascript push. */
    private val latestJson = AtomicReference("{}")
    private val statusText = AtomicReference("Dinleniyor")

    @SuppressLint("SetJavaScriptEnabled", "AddJavascriptInterface")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        hideSystemUi()

        refreshIp()
        binding.portValue.text = "OutGauge 4444 · MotionSim 4445"

        binding.btnCopy.setOnClickListener {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("ip", phoneIp))
            Toast.makeText(this, "IP kopyalandı: $phoneIp", Toast.LENGTH_SHORT).show()
        }
        binding.btnStart.setOnClickListener { openCluster(demo = false) }
        binding.btnDemo.setOnClickListener { openCluster(demo = true) }

        binding.clusterWeb.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = WebSettings.LOAD_NO_CACHE
            allowFileAccess = true
            allowContentAccess = true
            @Suppress("DEPRECATION")
            allowFileAccessFromFileURLs = true
            @Suppress("DEPRECATION")
            allowUniversalAccessFromFileURLs = true
        }
        binding.clusterWeb.addJavascriptInterface(NativeBridge(), "EymenNative")
        binding.clusterWeb.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                statusText.set("OG:$packetOg MS:$packetMs")
                rebuildJson()
            }
        }

        startUdpListening()

        lifecycleScope.launch {
            while (isActive) {
                if (!clusterMode) refreshIp()
                delay(2000)
            }
        }
    }

    inner class NativeBridge {
        @JavascriptInterface
        fun getTelemetry(): String = latestJson.get()

        @JavascriptInterface
        fun getStatus(): String = statusText.get()

        @JavascriptInterface
        fun packetCount(): Int = packetOg + packetMs
    }

    private fun refreshIp() {
        val best = bestIpv4()
        phoneIp = best?.second ?: wifiManagerIpv4() ?: "Bağlantı yok"
        binding.ipValue.text = phoneIp
        binding.linkType.text = when {
            best == null -> "Wi‑Fi / USB / Bluetooth bekleniyor"
            isBluetoothIface(best.first) -> "Bluetooth · ${best.first}"
            isUsbIface(best.first) -> "USB · ${best.first}"
            isWifiIface(best.first) -> "Wi‑Fi · ${best.first}"
            else -> "Ağ · ${best.first}"
        }
    }

    private fun bestIpv4(): Pair<String, String>? {
        val list = allIpv4()
        return list.maxByOrNull { (name, _) ->
            when {
                isBluetoothIface(name) -> 6
                isUsbIface(name) -> 5
                isWifiIface(name) -> 3
                else -> 1
            }
        }
    }

    private fun allIpv4(): List<Pair<String, String>> {
        val list = mutableListOf<Pair<String, String>>()
        val interfaces = NetworkInterface.getNetworkInterfaces() ?: return list
        for (intf in interfaces) {
            if (!intf.isUp || intf.isLoopback) continue
            val name = intf.name ?: continue
            for (addr in intf.inetAddresses) {
                val host = addr.hostAddress ?: continue
                if (addr.isLoopbackAddress || host.contains(':') || host.startsWith("169.254.")) continue
                list += name to host
            }
        }
        return list
    }

    private fun isBluetoothIface(name: String) =
        name.contains("bnep", true) || name.contains("bt-pan", true) || name.contains("bt_pan", true)

    private fun isUsbIface(name: String) =
        name.contains("rndis", true) || name.contains("usb", true)

    private fun isWifiIface(name: String) =
        name.startsWith("wlan", true) || name.contains("wlan", true) || name.startsWith("ap", true)

    private fun startUdpListening() {
        listener?.stop()
        packetOg = 0
        packetMs = 0
        updatePacketUi()
        listener = UdpTelemetryListener(
            context = this,
            scope = lifecycleScope,
            onListening = { port, ok ->
                runOnUiThread {
                    if (!ok) {
                        binding.packetStatus.text = "Port $port açılamadı"
                        binding.packetStatus.setTextColor(Color.parseColor("#FF6B4A"))
                    }
                }
            },
            onRaw = { port, size, from ->
                if (port == OUTGAUGE_PORT) packetOg++ else packetMs++
                runOnUiThread { updatePacketUi(from, size) }
            },
            onOutGauge = { data ->
                lastOut = data
                rebuildJson()
            },
            onMotion = { data ->
                lastMotion = data
                appendTrail(data.posX.toDouble(), data.posY.toDouble())
                rebuildJson()
            },
            onError = { msg ->
                runOnUiThread {
                    if (packetOg == 0 && packetMs == 0) binding.packetStatus.text = msg
                }
            },
        ).also { it.start(OUTGAUGE_PORT, MOTION_PORT) }
    }

    private fun updatePacketUi(from: String? = null, size: Int? = null) {
        val total = packetOg + packetMs
        statusText.set("OG:$packetOg MS:$packetMs")
        if (total == 0) {
            binding.packetStatus.setTextColor(Color.parseColor("#7F8FA3"))
            binding.packetStatus.text = "Dinleniyor… paket: 0\nCtrl+R · aynı Wi‑Fi"
        } else {
            binding.packetStatus.setTextColor(Color.parseColor("#5DDEA6"))
            val extra = if (from != null) " · $from ${size}b" else ""
            binding.packetStatus.text =
                "SİNYAL VAR · OG:$packetOg MS:$packetMs$extra\nŞimdi Kadranı Başlat"
        }
    }

    private fun openCluster(demo: Boolean) {
        clusterMode = true
        binding.setupRoot.visibility = View.GONE
        binding.clusterWeb.visibility = View.VISIBLE
        while (trail.length() > 0) trail.remove(0)
        rebuildJson()
        binding.clusterWeb.loadUrl("file:///android_asset/index.html")

        demoJob?.cancel()
        if (demo) {
            listener?.stop()
            listener = null
            startDemo()
        } else if (listener == null) {
            startUdpListening()
        }
    }

    private fun appendTrail(x: Double, y: Double) {
        val last = if (trail.length() > 0) trail.getJSONObject(trail.length() - 1) else null
        if (last == null ||
            kotlin.math.hypot(x - last.getDouble("x"), y - last.getDouble("y")) > 1.5
        ) {
            trail.put(JSONObject().put("x", x).put("y", y).put("t", System.currentTimeMillis()))
            while (trail.length() > 60) trail.remove(0)
        }
    }

    private fun rebuildJson() {
        val og = lastOut
        val mot = lastMotion
        if (og == null && mot == null) {
            latestJson.set("""{"source":"wait","gearLabel":"N","speedKmh":0,"rpm":0,"fuel":0,"throttle":0,"brake":0,"engTemp":0,"preferKm":true,"lights":{}}""")
            return
        }
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
                    put("speedMs", mot.speedMs.toDouble())
                })
                put("trail", trail)
            }
        }
        latestJson.set(json.toString())
    }

    private fun startDemo() {
        demoJob = lifecycleScope.launch {
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
                lastOut = OutGaugeData(
                    gearLabel = gearNum.toString(),
                    speedKmh = speedKmh.toFloat(),
                    speedMph = (speedKmh * 0.621371).toFloat(),
                    preferKm = true,
                    rpm = rpm.toFloat(),
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
                    signalL = (t * 2).toInt() % 2 == 0 && sin(t * 0.15) > 0.7,
                    signalR = false,
                    oilWarn = false,
                    battery = false,
                    abs = false,
                    source = "demo",
                )
                lastMotion = MotionSimData(
                    posX = x.toFloat(),
                    posY = y.toFloat(),
                    posZ = 0f,
                    velX = 0f,
                    velY = 0f,
                    velZ = 0f,
                    yawPos = (ang + Math.PI / 2).toFloat(),
                    speedMs = (speedKmh / 3.6).toFloat(),
                )
                packetOg++
                rebuildJson()
                statusText.set("DEMO")
                delay(50)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun wifiManagerIpv4(): String? {
        return try {
            val wm = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            val ip = wm.connectionInfo?.ipAddress ?: return null
            if (ip == 0) return null
            String.format(
                "%d.%d.%d.%d",
                ip and 0xff,
                ip shr 8 and 0xff,
                ip shr 16 and 0xff,
                ip shr 24 and 0xff,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun hideSystemUi() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun onResume() {
        super.onResume()
        refreshIp()
        if (!clusterMode && listener == null) startUdpListening()
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
            clusterMode = false
            binding.clusterWeb.visibility = View.GONE
            binding.setupRoot.visibility = View.VISIBLE
            refreshIp()
            if (listener == null) startUdpListening()
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
