package com.eymen.beamngcluster

import android.content.Context
import android.net.wifi.WifiManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress

/** Listens for BeamNG UDP on the phone — no PC helper app. */
class UdpTelemetryListener(
    private val context: Context,
    private val scope: CoroutineScope,
    private val onListening: (port: Int, ok: Boolean) -> Unit = { _, _ -> },
    private val onRaw: (port: Int, size: Int, from: String) -> Unit = { _, _, _ -> },
    private val onOutGauge: (OutGaugeData) -> Unit,
    private val onMotion: (MotionSimData) -> Unit,
    private val onError: (String) -> Unit = {},
) {
    private var job: Job? = null
    private val sockets = mutableListOf<DatagramSocket>()
    private var multicastLock: WifiManager.MulticastLock? = null

    fun start(outgaugePort: Int = 4444, motionPort: Int = 4445) {
        if (job?.isActive == true) return
        job = scope.launch(Dispatchers.IO) {
            acquireMulticastLock()
            try {
                launchPort(outgaugePort) { bytes, from ->
                    onRaw(outgaugePort, bytes.size, from)
                    OutGaugeParser.parse(bytes)?.let(onOutGauge)
                        ?: onError("OutGauge paket bozuk (${bytes.size}b)")
                }
                launchPort(motionPort) { bytes, from ->
                    onRaw(motionPort, bytes.size, from)
                    MotionSimParser.parse(bytes)?.let(onMotion)
                }
            } catch (e: Exception) {
                onError(e.message ?: "UDP açılamadı")
            }
        }
    }

    private fun CoroutineScope.launchPort(port: Int, handler: (ByteArray, String) -> Unit) = launch(Dispatchers.IO) {
        try {
            val sock = DatagramSocket(null).apply {
                reuseAddress = true
                broadcast = true
                bind(InetSocketAddress("0.0.0.0", port))
                soTimeout = 1000
            }
            synchronized(sockets) { sockets += sock }
            onListening(port, true)
            val buf = ByteArray(512)
            while (isActive) {
                try {
                    val packet = DatagramPacket(buf, buf.size)
                    sock.receive(packet)
                    val from = packet.address?.hostAddress ?: "?"
                    handler(buf.copyOf(packet.length), from)
                } catch (_: java.net.SocketTimeoutException) {
                } catch (e: Exception) {
                    if (isActive) onError("UDP $port: ${e.message}")
                }
            }
        } catch (e: Exception) {
            onListening(port, false)
            onError("Port $port: ${e.message}")
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        synchronized(sockets) {
            sockets.forEach { runCatching { it.close() } }
            sockets.clear()
        }
        releaseMulticastLock()
    }

    @Suppress("DEPRECATION")
    private fun acquireMulticastLock() {
        try {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifi.createMulticastLock("eymen-udp").apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (_: Exception) {
        }
    }

    private fun releaseMulticastLock() {
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
        }
        multicastLock = null
    }
}
