package com.eymen.beamngcluster

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Color
import android.net.wifi.WifiManager
import android.os.Bundle
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.DecelerateInterpolator
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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
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
    private var msgPanelOpen = false

    @Volatile private var lastOut: OutGaugeData? = null
    @Volatile private var lastMotion: MotionSimData? = null
    @Volatile private var lastPacketWall = 0L

    private val trail = ArrayList<MapView.Pt>(80)
    private var packetOg = 0
    private var packetMs = 0

    private var prevEngineOn: Boolean? = null
    private var prevGear: String? = null
    private var prevSignalL = false
    private var prevSignalR = false
    private var prevAbs = false
    private var prevTc = false
    private var prevShift = false
    private var prevHandbrake = false
    private var prevOil = false
    private var prevBattery = false
    private var prevBeam = false
    private var ignitionFxPlaying = false
    private var toastUntil = 0L
    private val msgLines = ArrayDeque<String>(40)
    private val timeFmt = SimpleDateFormat("HH:mm:ss", Locale.US)
    private var brandPulseStarted = false

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
        resetFxState()
        pushMsg("Kadran açıldı")
        showToast("EYMEN CLUSTER ONLINE", 1800)
        startBrandPulse()

        binding.btnMsg.setOnClickListener { toggleMsgPanel() }
        binding.msgPanel.visibility = View.GONE
        msgPanelOpen = false

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

    private fun resetFxState() {
        prevEngineOn = null
        prevGear = null
        prevSignalL = false
        prevSignalR = false
        prevAbs = false
        prevTc = false
        prevShift = false
        prevHandbrake = false
        prevOil = false
        prevBattery = false
        prevBeam = false
        ignitionFxPlaying = false
        toastUntil = 0L
        msgLines.clear()
        binding.ignitionFx.visibility = View.GONE
        binding.ignitionFx.alpha = 0f
        binding.glowL.alpha = 0f
        binding.glowR.alpha = 0f
        binding.glowShift.alpha = 0f
        binding.toastLine.text = ""
        binding.clusterBody.alpha = 1f
    }

    private fun toggleMsgPanel() {
        msgPanelOpen = !msgPanelOpen
        binding.msgPanel.visibility = if (msgPanelOpen) View.VISIBLE else View.GONE
        if (msgPanelOpen) {
            binding.msgPanel.translationX = 120f
            binding.msgPanel.alpha = 0f
            binding.msgPanel.animate().translationX(0f).alpha(1f).setDuration(220).start()
            refreshMsgLog()
            pushMsg("Sinyal paneli açıldı")
        }
    }

    private fun pushMsg(text: String) {
        val line = "${timeFmt.format(Date())}  $text"
        msgLines.addFirst(line)
        while (msgLines.size > 36) msgLines.removeLast()
        if (msgPanelOpen) refreshMsgLog()
    }

    private fun refreshMsgLog() {
        binding.msgLog.text = if (msgLines.isEmpty()) "—" else msgLines.joinToString("\n")
    }

    private fun showToast(text: String, ms: Long = 1400) {
        binding.toastLine.text = text
        binding.toastLine.alpha = 0f
        binding.toastLine.animate().alpha(1f).setDuration(160).start()
        toastUntil = System.currentTimeMillis() + ms
    }

    private fun startBrandPulse() {
        if (brandPulseStarted) return
        brandPulseStarted = true
        val a = ObjectAnimator.ofFloat(binding.clusterBrand, View.ALPHA, 0.45f, 1f).apply {
            duration = 1200
            repeatMode = ObjectAnimator.REVERSE
            repeatCount = ObjectAnimator.INFINITE
            interpolator = AccelerateDecelerateInterpolator()
        }
        a.start()
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
        val engineOn = rpm > 200f
        val gear = og?.gearLabel ?: "N"

        // Ignition on/off transitions
        val was = prevEngineOn
        if (was != null && was && !engineOn) {
            pushMsg("IGNITION OFF")
            showToast("IGNITION OFF", 2000)
            playIgnitionOffFx()
        } else if (was != null && !was && engineOn) {
            pushMsg("IGNITION ON · motor çalıştı")
            showToast("IGNITION ON", 1500)
            playIgnitionOnFx()
        }
        prevEngineOn = engineOn

        if (gear != prevGear && prevGear != null) {
            pushMsg("Vites $prevGear → $gear")
            pulseGear()
            showToast("GEAR $gear", 900)
        }
        prevGear = gear

        trackFlag("◀ SOL SİNYAL", og?.signalL == true, prevSignalL) { prevSignalL = it }
        trackFlag("SAĞ SİNYAL ▶", og?.signalR == true, prevSignalR) { prevSignalR = it }
        trackFlag("ABS", og?.abs == true, prevAbs) { prevAbs = it }
        trackFlag("TC", og?.tc == true, prevTc) { prevTc = it }
        trackFlag("SHIFT LIGHT", og?.shift == true, prevShift) { prevShift = it }
        trackFlag("EL FRENİ", og?.handbrake == true, prevHandbrake) { prevHandbrake = it }
        trackFlag("YAĞ UYARISI", og?.oilWarn == true, prevOil) { prevOil = it }
        trackFlag("AKÜ", og?.battery == true, prevBattery) { prevBattery = it }
        trackFlag("UZUN FAR", og?.fullbeam == true, prevBeam) { prevBeam = it }

        // Dim gauges while ignition off (unless overlay animating)
        if (!ignitionFxPlaying) {
            binding.clusterBody.alpha = if (engineOn) 1f else 0.35f
            binding.ignitionFx.visibility = if (!engineOn) View.VISIBLE else View.GONE
            if (!engineOn) {
                binding.ignitionFx.alpha = 0.85f
                binding.ignitionTitle.text = "IGNITION OFF"
                binding.ignitionSub.text = "ENGINE STOPPED"
                binding.ignitionBar.progress = 0
            } else if (binding.ignitionFx.visibility == View.VISIBLE && engineOn) {
                binding.ignitionFx.visibility = View.GONE
            }
        }

        binding.speedValue.text = speed.toInt().toString()
        binding.rpmValue.text = String.format("%.1f", rpm / 1000f)
        binding.gearValue.text = gear

        // Speed color / RPM redline pulse
        val redline = rpm >= 5800f
        val blink = ((System.currentTimeMillis() / 180) % 2 == 0L)
        binding.rpmValue.setTextColor(
            Color.parseColor(if (redline && blink) "#FF6B4A" else if (redline) "#FFC14D" else "#EEF3F8"),
        )
        binding.speedValue.setTextColor(
            Color.parseColor(when {
                speed > 160 -> "#FF6B4A"
                speed > 100 -> "#5EE7FF"
                else -> "#EEF3F8"
            }),
        )
        binding.rpmArc.progress = (minOf(1f, rpm / 7000f) * 1000).toInt()
        binding.rpmArc.progressTintList = android.content.res.ColorStateList.valueOf(
            Color.parseColor(if (redline) "#FF6B4A" else "#5EE7FF"),
        )

        binding.throttleBar.progress = ((og?.throttle ?: 0f) * 1000).toInt()
        binding.brakeBar.progress = ((og?.brake ?: 0f) * 1000).toInt()
        binding.fuelBar.progress = ((og?.fuel ?: 0f) * 1000).toInt()
        binding.fuelVal.text = "${((og?.fuel ?: 0f) * 100).toInt()}%"
        val temp = og?.engTemp ?: 0f
        binding.tempBar.progress = (max(0f, minOf(1f, (temp - 40f) / 80f)) * 1000).toInt()
        binding.tempVal.text = "${temp.toInt()}°"

        val sigL = og?.signalL == true
        val sigR = og?.signalR == true
        setIcon(binding.icoL, sigL && blink, ok = true)
        setIcon(binding.icoR, sigR && blink, ok = true)
        setIcon(binding.icoBeam, og?.fullbeam == true, ok = true)
        setIcon(binding.icoP, og?.handbrake == true, warn = true)
        setIcon(binding.icoAbs, og?.abs == true && blink, warn = true)
        setIcon(binding.icoTc, og?.tc == true && blink, warn = true)
        setIcon(binding.icoShift, og?.shift == true && blink, hot = true)
        setIcon(binding.icoIgn, engineOn, ok = true)

        // Edge glow FX
        binding.glowL.alpha = if (sigL && blink) 0.95f else if (sigL) 0.35f else 0f
        binding.glowR.alpha = if (sigR && blink) 0.95f else if (sigR) 0.35f else 0f
        binding.glowShift.alpha = if (og?.shift == true && blink) 0.85f else 0f

        if (System.currentTimeMillis() > toastUntil && binding.toastLine.alpha > 0.9f) {
            binding.toastLine.animate().alpha(0f).setDuration(280).start()
        }

        if (mot != null) {
            binding.mapView.update(mot.posX, mot.posY, mot.yawPos, mot.speedMs, trail.toList())
        }
        val ign = if (engineOn) "IGN ON" else "IGN OFF"
        binding.clusterMeta.text = "$ign · OG:$packetOg MS:$packetMs · ${speed.toInt()} km/h"
    }

    private fun trackFlag(label: String, now: Boolean, prev: Boolean, store: (Boolean) -> Unit) {
        if (now && !prev) {
            pushMsg("$label AKTİF")
            showToast(label, 1100)
        } else if (!now && prev) {
            pushMsg("$label KAPANDI")
        }
        store(now)
    }

    private fun pulseGear() {
        binding.gearValue.animate().cancel()
        binding.gearValue.scaleX = 1.35f
        binding.gearValue.scaleY = 1.35f
        binding.gearValue.animate()
            .scaleX(1f).scaleY(1f)
            .setDuration(280)
            .setInterpolator(DecelerateInterpolator())
            .start()
    }

    private fun playIgnitionOffFx() {
        if (ignitionFxPlaying) return
        ignitionFxPlaying = true
        val fx = binding.ignitionFx
        fx.visibility = View.VISIBLE
        fx.alpha = 0f
        binding.ignitionTitle.text = "IGNITION OFF"
        binding.ignitionSub.text = "SYSTEM POWER DOWN"
        binding.ignitionBar.progress = 1000
        binding.clusterBody.animate().alpha(0.2f).setDuration(400).start()

        fx.animate().alpha(1f).setDuration(350).withEndAction {
            ObjectAnimator.ofInt(binding.ignitionBar, "progress", 1000, 0).apply {
                duration = 1600
                start()
            }
            binding.ignitionTitle.animate()
                .scaleX(1.08f).scaleY(1.08f)
                .setDuration(500)
                .withEndAction {
                    binding.ignitionTitle.animate().scaleX(1f).scaleY(1f).setDuration(400).start()
                    ignitionFxPlaying = false
                }.start()
        }.start()

        // Screen flash
        val flash = ObjectAnimator.ofFloat(binding.clusterRoot, View.ALPHA, 1f, 0.4f, 1f)
        flash.duration = 420
        flash.start()
    }

    private fun playIgnitionOnFx() {
        ignitionFxPlaying = true
        binding.ignitionFx.visibility = View.VISIBLE
        binding.ignitionFx.alpha = 1f
        binding.ignitionTitle.text = "IGNITION ON"
        binding.ignitionTitle.setTextColor(Color.parseColor("#5DDEA6"))
        binding.ignitionSub.text = "SYSTEM BOOT"
        binding.ignitionBar.progress = 0
        ObjectAnimator.ofInt(binding.ignitionBar, "progress", 0, 1000).apply {
            duration = 700
            start()
        }
        binding.clusterBody.animate().alpha(1f).setDuration(500).start()
        binding.ignitionFx.animate().alpha(0f).setDuration(800).withEndAction {
            binding.ignitionFx.visibility = View.GONE
            binding.ignitionTitle.setTextColor(Color.parseColor("#FF6B4A"))
            ignitionFxPlaying = false
        }.start()

        val set = AnimatorSet()
        set.playTogether(
            ObjectAnimator.ofFloat(binding.speedValue, View.ALPHA, 0f, 1f),
            ObjectAnimator.ofFloat(binding.rpmValue, View.ALPHA, 0f, 1f),
            ObjectAnimator.ofFloat(binding.gearValue, View.ALPHA, 0f, 1f),
        )
        set.duration = 600
        set.start()
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
        tv.alpha = if (on) 1f else 0.55f
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
            var cycle = 0
            while (isActive) {
                t += 0.05
                cycle++
                // Every ~18s: ignition off for ~3.5s
                val ignOff = (cycle % 360) in 300..370
                val speedKmh = if (ignOff) 0.0 else 40 + 80 * (0.5 + 0.5 * sin(t * 0.35))
                val rpm = if (ignOff) 0.0 else 1200 + 4800 * (0.45 + 0.45 * sin(t * 0.7))
                val gearNum = if (ignOff) 0 else minOf(6, maxOf(1, (speedKmh / 28).toInt() + 1))
                val ang = t * 0.4
                val r = 80 + 20 * sin(t * 0.1)
                val x = cos(ang) * r
                val y = sin(ang) * r
                val phase = (t * 0.12).toInt() % 6
                lastOut = OutGaugeData(
                    gearLabel = if (gearNum == 0) "N" else gearNum.toString(),
                    speedKmh = speedKmh.toFloat(),
                    speedMph = (speedKmh * 0.621371).toFloat(),
                    preferKm = true,
                    rpm = rpm.toFloat(),
                    turbo = if (ignOff) 0f else (0.4 + 0.6 * max(0.0, sin(t))).toFloat(),
                    engTemp = (88 + 4 * sin(t * 0.2)).toFloat(),
                    fuel = 0.62f,
                    throttle = if (ignOff) 0f else (0.3 + 0.5 * (0.5 + 0.5 * sin(t * 0.7))).toFloat(),
                    brake = if (ignOff) 0f else max(0.0, sin(t * 0.2) - 0.7).toFloat(),
                    clutch = 0f,
                    showTurbo = true,
                    shift = !ignOff && rpm > 5500,
                    fullbeam = !ignOff && phase != 4,
                    handbrake = ignOff || phase == 3,
                    tc = !ignOff && phase == 1,
                    signalL = !ignOff && (phase == 0 || phase == 5) && ((t * 2).toInt() % 2 == 0),
                    signalR = !ignOff && phase == 2 && ((t * 2).toInt() % 2 == 0),
                    oilWarn = phase == 4,
                    battery = ignOff,
                    abs = !ignOff && phase == 1 && sin(t) > 0.6,
                    source = "demo",
                )
                lastMotion = MotionSimData(
                    x.toFloat(), y.toFloat(), 0f, 0f, 0f, 0f,
                    (ang + Math.PI / 2).toFloat(), (speedKmh / 3.6).toFloat(),
                )
                if (!ignOff) appendTrail(x.toFloat(), y.toFloat())
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
        if (msgPanelOpen) {
            msgPanelOpen = false
            binding.msgPanel.visibility = View.GONE
            return
        }
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
