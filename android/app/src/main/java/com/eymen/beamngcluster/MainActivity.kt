package com.eymen.beamngcluster

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.View
import android.widget.TextView
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
import java.net.NetworkInterface
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private var listener: UdpTelemetryListener? = null
    private var demoJob: Job? = null
    private var uiJob: Job? = null
    private var phoneIp: String = "—"
    private var clusterMode = false

    @Volatile private var lastOut: OutGaugeData? = null
    @Volatile private var lastMotion: MotionSimData? = null
    @Volatile private var lastPacketWall = 0L

    private val trail = ArrayList<MapView.Pt>(80)
    private var packetOg = 0
    private var packetMs = 0

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

        startUdpListening()
        lifecycleScope.launch {
            while (isActive) {
                if (!clusterMode) refreshIp()
                delay(2000)
            }
        }
    }

    private fun openCluster(demo: Boolean) {
        clusterMode = true
        binding.setupRoot.visibility = View.GONE
        binding.clusterRoot.visibility = View.VISIBLE
        trail.clear()
        binding.mapView.clear()

        demoJob?.cancel()
        uiJob?.cancel()

        if (demo) {
            listener?.stop()
            listener = null
            lastOut = null
            lastMotion = null
            startDemo()
        } else if (listener == null) {
            startUdpListening()
        }

        uiJob = lifecycleScope.launch {
            while (isActive && clusterMode) {
                renderCluster()
                delay(33)
            }
        }
    }

    private fun renderCluster() {
        val og = lastOut
        val mot = lastMotion
        if (og == null && mot == null) {
            binding.clusterStatus.text = "BEKLENİYOR"
            binding.clusterStatus.setTextColor(Color.parseColor("#7F8FA3"))
            binding.clusterMeta.text = "OG:$packetOg MS:$packetMs"
            return
        }

        val ageOk = System.currentTimeMillis() - lastPacketWall < 2000
        if (ageOk || og?.source == "demo") {
            binding.clusterStatus.text = if (og?.source == "demo") "DEMO" else "CANLI"
            binding.clusterStatus.setTextColor(Color.parseColor("#5DDEA6"))
        } else {
            binding.clusterStatus.text = "SİNYAL YOK"
            binding.clusterStatus.setTextColor(Color.parseColor("#FF6B4A"))
        }

        val speed = og?.speedKmh ?: ((mot?.speedMs ?: 0f) * 3.6f)
        val rpm = og?.rpm ?: 0f
        binding.speedValue.text = speed.toInt().toString()
        binding.rpmValue.text = String.format("%.1f", rpm / 1000f)
        binding.gearValue.text = og?.gearLabel ?: "N"

        binding.throttleBar.progress = ((og?.throttle ?: 0f) * 1000).toInt()
        binding.brakeBar.progress = ((og?.brake ?: 0f) * 1000).toInt()
        binding.fuelBar.progress = ((og?.fuel ?: 0f) * 1000).toInt()
        binding.fuelVal.text = "${((og?.fuel ?: 0f) * 100).toInt()}%"
        val temp = og?.engTemp ?: 0f
        binding.tempBar.progress = (max(0f, minOf(1f, (temp - 40f) / 80f)) * 1000).toInt()
        binding.tempVal.text = "${temp.toInt()}°"

        setIcon(binding.icoL, og?.signalL == true, ok = true)
        setIcon(binding.icoR, og?.signalR == true, ok = true)
        setIcon(binding.icoBeam, og?.fullbeam == true, ok = true)
        setIcon(binding.icoP, og?.handbrake == true, warn = true)
        setIcon(binding.icoAbs, og?.abs == true, warn = true)
        setIcon(binding.icoTc, og?.tc == true, warn = true)
        setIcon(binding.icoShift, og?.shift == true, hot = true)

        if (mot != null) {
            binding.mapView.update(mot.posX, mot.posY, mot.yawPos, mot.speedMs, trail.toList())
        }
        binding.clusterMeta.text = "OG:$packetOg MS:$packetMs · ${speed.toInt()} km/h"
    }

    private fun setIcon(
        tv: TextView,
        on: Boolean,
        ok: Boolean = false,
        warn: Boolean = false,
        hot: Boolean = false,
    ) {
        val color = when {
            !on -> "#557F8FA3"
            hot -> "#FF6B4A"
            warn -> "#FFC14D"
            ok -> "#5DDEA6"
            else -> "#5EE7FF"
        }
        tv.setTextColor(Color.parseColor(color))
    }

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
                lastPacketWall = System.currentTimeMillis()
                runOnUiThread { updatePacketUi(from, size) }
            },
            onOutGauge = { data ->
                lastOut = data
                lastPacketWall = System.currentTimeMillis()
            },
            onMotion = { data ->
                lastMotion = data
                lastPacketWall = System.currentTimeMillis()
                appendTrail(data.posX, data.posY)
            },
            onError = { msg ->
                runOnUiThread {
                    if (packetOg == 0 && packetMs == 0) binding.packetStatus.text = msg
                }
            },
        ).also { it.start(OUTGAUGE_PORT, MOTION_PORT) }
    }

    private fun appendTrail(x: Float, y: Float) {
        val last = trail.lastOrNull()
        if (last == null || kotlin.math.hypot((x - last.x).toDouble(), (y - last.y).toDouble()) > 1.5) {
            trail += MapView.Pt(x, y)
            while (trail.size > 80) trail.removeAt(0)
        }
    }

    private fun updatePacketUi(from: String? = null, size: Int? = null) {
        val total = packetOg + packetMs
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
                    x.toFloat(), y.toFloat(), 0f, 0f, 0f, 0f,
                    (ang + Math.PI / 2).toFloat(), (speedKmh / 3.6).toFloat(),
                )
                appendTrail(x.toFloat(), y.toFloat())
                packetOg++
                lastPacketWall = System.currentTimeMillis()
                delay(50)
            }
        }
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

    private fun bestIpv4(): Pair<String, String>? =
        allIpv4().maxByOrNull { (name, _) ->
            when {
                isBluetoothIface(name) -> 6
                isUsbIface(name) -> 5
                isWifiIface(name) -> 3
                else -> 1
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

    @Suppress("DEPRECATION")
    private fun wifiManagerIpv4(): String? {
        return try {
            val wm = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
            val ip = wm.connectionInfo?.ipAddress ?: return null
            if (ip == 0) null else String.format(
                "%d.%d.%d.%d",
                ip and 0xff, ip shr 8 and 0xff, ip shr 16 and 0xff, ip shr 24 and 0xff,
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun hideSystemUi() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let {
            it.hide(WindowInsetsCompat.Type.systemBars())
            it.systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun onResume() {
        super.onResume()
        refreshIp()
        if (!clusterMode && listener == null) startUdpListening()
    }

    override fun onDestroy() {
        demoJob?.cancel()
        uiJob?.cancel()
        listener?.stop()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (binding.clusterRoot.visibility == View.VISIBLE) {
            demoJob?.cancel()
            uiJob?.cancel()
            clusterMode = false
            binding.clusterRoot.visibility = View.GONE
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
