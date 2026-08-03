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

class OutGaugeListener(
    private val context: Context,
    private val port: Int = 4444,
    private val scope: CoroutineScope,
    private val onListening: (Boolean) -> Unit = {},
    private val onRawPacket: (size: Int, from: String) -> Unit = { _, _ -> },
    private val onPacket: (OutGaugeData) -> Unit,
    private val onError: (String) -> Unit = {},
) {
    private var job: Job? = null
    private var socket: DatagramSocket? = null
    private var multicastLock: WifiManager.MulticastLock? = null

    fun start() {
        if (job?.isActive == true) return
        job = scope.launch(Dispatchers.IO) {
            try {
                acquireMulticastLock()
                val sock = DatagramSocket(null).apply {
                    reuseAddress = true
                    broadcast = true
                    bind(InetSocketAddress("0.0.0.0", port))
                    soTimeout = 1000
                }
                socket = sock
                onListening(true)
                val buf = ByteArray(512)
                while (isActive) {
                    try {
                        val packet = DatagramPacket(buf, buf.size)
                        sock.receive(packet)
                        val from = packet.address?.hostAddress ?: "?"
                        onRawPacket(packet.length, from)
                        val data = buf.copyOf(packet.length)
                        val parsed = OutGaugeParser.parse(data)
                        if (parsed != null) {
                            onPacket(parsed)
                        } else {
                            onError("Paket geldi (${packet.length} byte) ama okunamadı")
                        }
                    } catch (_: java.net.SocketTimeoutException) {
                        // keep listening
                    } catch (e: Exception) {
                        if (isActive) onError(e.message ?: "UDP hata")
                    }
                }
            } catch (e: Exception) {
                onListening(false)
                onError(e.message ?: "Port $port açılamadı")
            } finally {
                onListening(false)
                runCatching { socket?.close() }
                socket = null
                releaseMulticastLock()
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        runCatching { socket?.close() }
        socket = null
        releaseMulticastLock()
    }

    @Suppress("DEPRECATION")
    private fun acquireMulticastLock() {
        try {
            val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            multicastLock = wifi.createMulticastLock("eymen-outgauge").apply {
                setReferenceCounted(true)
                acquire()
            }
        } catch (_: Exception) {
            // optional
        }
    }

    private fun releaseMulticastLock() {
        try {
            multicastLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {
            // ignore
        }
        multicastLock = null
    }
}
