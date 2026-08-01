package com.teslapulse.phonekey

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import java.util.UUID

class BlePairer(
    private val context: Context,
    private val onStatus: (String) -> Unit,
    private val onLog: (String) -> Unit,
    private val onWaitingCard: () -> Unit,
    private val onDone: () -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())
    private val adapter: BluetoothAdapter? =
        (context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager).adapter

    private var gatt: BluetoothGatt? = null
    private var writeChar: BluetoothGattCharacteristic? = null
    private var payload: ByteArray? = null
    private var targetNames: Set<String> = emptySet()
    private var scanning = false
    private var connected = false

    private val serviceUuid = UUID.fromString(VcsecPayload.SERVICE_UUID)
    private val writeUuid = UUID.fromString(VcsecPayload.WRITE_UUID)
    private val readUuid = UUID.fromString(VcsecPayload.READ_UUID)
    private val cccd = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    @SuppressLint("MissingPermission")
    fun start(vin: String, publicKey: ByteArray) {
        stop()
        val names = VcsecPayload.bleNames(vin)
        targetNames = names.toSet()
        payload = VcsecPayload.addKeyRequest(publicKey)
        onLog("Hedef: ${names.joinToString(", ")}")
        onLog("Payload ${payload!!.size} byte")

        val bt = adapter
        if (bt == null || !bt.isEnabled) {
            onStatus("Bluetooth kapalı — Ayarlar’dan aç")
            return
        }

        onStatus("Tesla aranıyor…")
        scanning = true
        val scanner = bt.bluetoothLeScanner
        val filters = listOf(
            ScanFilter.Builder().setServiceUuid(ParcelUuid(serviceUuid)).build(),
        )
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        try {
            scanner.startScan(filters, settings, scanCallback)
        } catch (_: Exception) {
            scanner.startScan(scanCallback)
        }
        // Also unfiltered after 2s — some cars omit service UUID in adv
        handler.postDelayed({
            if (scanning && !connected) {
                try {
                    scanner.stopScan(scanCallback)
                    scanner.startScan(scanCallback)
                    onLog("Filtresiz tarama…")
                } catch (_: Exception) {
                }
            }
        }, 2000)
        handler.postDelayed({
            if (scanning && !connected) {
                stopScan()
                onStatus("Araç bulunamadı. Yakınlaş / arabayı uyandır.")
            }
        }, 28_000)
    }

    @SuppressLint("MissingPermission")
    fun stop() {
        stopScan()
        try {
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        writeChar = null
        connected = false
    }

    @SuppressLint("MissingPermission")
    private fun stopScan() {
        if (!scanning) return
        scanning = false
        try {
            adapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (_: Exception) {
        }
    }

    private val scanCallback = object : ScanCallback() {
        @SuppressLint("MissingPermission")
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.device.name
                ?: result.scanRecord?.deviceName
                ?: ""
            val match = targetNames.contains(name)
                || name.startsWith("Tesla")
                || (name.startsWith("S") && name.endsWith("C") && name.length == 18)
            if (!match) return
            if (connected) return
            connected = true
            stopScan()
            onLog("Bulundu: $name (${result.rssi} dBm)")
            onStatus("Bağlanıyor: $name…")
            gatt = result.device.connectGatt(
                context,
                false,
                gattCallback,
                BluetoothDevice.TRANSPORT_LE,
            )
        }

        override fun onScanFailed(errorCode: Int) {
            onStatus("Tarama hatası: $errorCode")
            onLog("Scan failed $errorCode")
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        @SuppressLint("MissingPermission")
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                onLog("GATT bağlı, servisler…")
                handler.post { onStatus("Servisler keşfediliyor…") }
                g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                handler.post { onLog("GATT koptu") }
            }
        }

        @SuppressLint("MissingPermission")
        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val service = g.getService(serviceUuid)
            if (service == null) {
                handler.post { onStatus("Tesla servisi yok") }
                return
            }
            writeChar = service.getCharacteristic(writeUuid)
            val read = service.getCharacteristic(readUuid)
            if (writeChar == null) {
                handler.post { onStatus("Write characteristic yok") }
                return
            }
            if (read != null) {
                g.setCharacteristicNotification(read, true)
                val desc = read.getDescriptor(cccd)
                if (desc != null) {
                    if (Build.VERSION.SDK_INT >= 33) {
                        g.writeDescriptor(desc, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE)
                    } else {
                        @Suppress("DEPRECATION")
                        desc.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        @Suppress("DEPRECATION")
                        g.writeDescriptor(desc)
                    }
                }
            }
            handler.post {
                onStatus("add-key gönderiliyor…")
                writePayload(g)
            }
        }

        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            value: ByteArray,
        ) {
            handleNotify(value)
        }

        @Deprecated("Deprecated in Java")
        override fun onCharacteristicChanged(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
        ) {
            @Suppress("DEPRECATION")
            val value = characteristic.value ?: return
            handleNotify(value)
        }

        @SuppressLint("MissingPermission")
        override fun onCharacteristicWrite(
            g: BluetoothGatt,
            characteristic: BluetoothGattCharacteristic,
            status: Int,
        ) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                handler.post {
                    onWaitingCard()
                    onStatus("Key Card’ı KONSOLA koy → Pair / Confirm")
                    onLog("İstek gönderildi ✓")
                }
            } else {
                handler.post {
                    onStatus("Yazma hatası: $status")
                    onLog("Write failed $status")
                }
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun writePayload(g: BluetoothGatt) {
        val data = payload ?: return
        val ch = writeChar ?: return
        // Single write is fine for ~88 bytes on modern phones; chunk if needed
        if (Build.VERSION.SDK_INT >= 33) {
            g.writeCharacteristic(ch, data, BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT)
        } else {
            @Suppress("DEPRECATION")
            ch.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            @Suppress("DEPRECATION")
            ch.value = data
            @Suppress("DEPRECATION")
            g.writeCharacteristic(ch)
        }
    }

    private fun handleNotify(value: ByteArray) {
        val hex = value.joinToString("") { "%02x".format(it) }
        handler.post {
            onLog("RX ${hex.take(48)}…")
            if (hex.contains("0801") || hex.contains("2202")) {
                onWaitingCard()
                onStatus("Araç kart bekliyor — konsola Key Card koy")
            }
            if (hex.contains("1a08") || hex.contains("5f0d")) {
                onDone()
                onStatus("Onaylandı — Phone Key eklendi")
                onLog("Whitelist OK (muhtemel)")
            }
        }
    }
}
