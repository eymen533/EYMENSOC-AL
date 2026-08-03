package com.eymen.beamngcluster

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress

class OutGaugeListener(
    private val port: Int = 4444,
    private val scope: CoroutineScope,
    private val onPacket: (OutGaugeData) -> Unit,
    private val onError: (String) -> Unit = {},
) {
    private var job: Job? = null
    private var socket: DatagramSocket? = null

    fun start() {
        if (job?.isActive == true) return
        job = scope.launch(Dispatchers.IO) {
            try {
                val sock = DatagramSocket(null).apply {
                    reuseAddress = true
                    bind(InetSocketAddress(port))
                    soTimeout = 1000
                }
                socket = sock
                val buf = ByteArray(256)
                while (isActive) {
                    try {
                        val packet = DatagramPacket(buf, buf.size)
                        sock.receive(packet)
                        val data = buf.copyOf(packet.length)
                        val parsed = OutGaugeParser.parse(data) ?: continue
                        onPacket(parsed)
                    } catch (_: java.net.SocketTimeoutException) {
                        // keep listening
                    } catch (e: Exception) {
                        if (isActive) onError(e.message ?: "UDP hata")
                    }
                }
            } catch (e: Exception) {
                onError(e.message ?: "Port açılamadı")
            } finally {
                runCatching { socket?.close() }
                socket = null
            }
        }
    }

    fun stop() {
        job?.cancel()
        job = null
        runCatching { socket?.close() }
        socket = null
    }
}
