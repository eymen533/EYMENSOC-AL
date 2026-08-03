package com.teslapulse.phonekey

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.teslapulse.phonekey.databinding.ActivityPairBinding

class PairActivity : AppCompatActivity() {
    private lateinit var binding: ActivityPairBinding
    private var pairer: BlePairer? = null
    private val logs = ArrayDeque<String>()

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            if (result.values.all { it }) beginBle() else setStatus("Bluetooth / konum izni gerekli")
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityPairBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.vinInput.setText(AppPrefs.vin(this))
        binding.pairButton.setOnClickListener { ensurePermissionsAndPair() }
        binding.skipButton.setOnClickListener { openHud(armServer = true) }
        binding.openHudButton.setOnClickListener { openHud(armServer = true) }
    }

    override fun onDestroy() {
        pairer?.stop()
        super.onDestroy()
    }

    private fun ensurePermissionsAndPair() {
        val needed = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= 31) {
            if (!granted(Manifest.permission.BLUETOOTH_SCAN)) needed += Manifest.permission.BLUETOOTH_SCAN
            if (!granted(Manifest.permission.BLUETOOTH_CONNECT)) needed += Manifest.permission.BLUETOOTH_CONNECT
        }
        if (!granted(Manifest.permission.ACCESS_FINE_LOCATION)) {
            needed += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (needed.isNotEmpty()) permissionLauncher.launch(needed.toTypedArray()) else beginBle()
    }

    private fun granted(p: String) =
        ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED

    private fun beginBle() {
        val vin = binding.vinInput.text?.toString()?.trim()?.uppercase().orEmpty()
        if (vin.length != 17) {
            Toast.makeText(this, "VIN 17 karakter olmalı", Toast.LENGTH_SHORT).show()
            return
        }
        AppPrefs.setVin(this, vin)
        binding.pairButton.isEnabled = false
        highlightStep(1)

        pairer?.stop()
        pairer = BlePairer(
            context = this,
            onStatus = { runOnUiThread { setStatus(it) } },
            onLog = { runOnUiThread { appendLog(it) } },
            onWaitingCard = {
                runOnUiThread {
                    highlightStep(2)
                    binding.pairButton.isEnabled = true
                    binding.openHudButton.visibility = View.VISIBLE
                    // Arm server HUD session while waiting for console card
                    PulseApi.hudPairAsync(this, vin) { }
                }
            },
            onDone = {
                runOnUiThread {
                    highlightStep(3)
                    AppPrefs.setPaired(this, true)
                    binding.pairButton.isEnabled = true
                    binding.openHudButton.visibility = View.VISIBLE
                    setStatus("Eşleşme tamam — HUD açılıyor…")
                    PulseApi.hudPairAsync(this, vin) {
                        runOnUiThread { openHud(armServer = false) }
                    }
                }
            },
        )

        try {
            val pub = PulseKeyStore.loadOrCreatePublicUncompressed(this)
            appendLog("Public ${pub.take(8).joinToString("") { "%02x".format(it) }}…")
            pairer?.start(vin, pub)
        } catch (e: Exception) {
            setStatus("Anahtar hatası: ${e.message}")
            binding.pairButton.isEnabled = true
        }
    }

    private fun openHud(armServer: Boolean) {
        val vin = binding.vinInput.text?.toString()?.trim()?.uppercase().orEmpty()
        if (vin.length == 17) AppPrefs.setVin(this, vin)
        if (armServer && vin.length == 17) {
            PulseApi.hudPairAsync(this, vin) {
                runOnUiThread {
                    startActivity(Intent(this, HudActivity::class.java))
                }
            }
        } else {
            startActivity(Intent(this, HudActivity::class.java))
        }
    }

    private fun setStatus(text: String) {
        binding.statusText.text = text
    }

    private fun appendLog(line: String) {
        logs.addFirst(line)
        while (logs.size > 40) logs.removeLast()
        binding.logText.text = logs.joinToString("\n")
    }

    private fun highlightStep(n: Int) {
        val on = R.drawable.bg_step_on
        val off = R.drawable.bg_step
        val onColor = ContextCompat.getColor(this, R.color.text)
        val offColor = ContextCompat.getColor(this, R.color.muted)
        binding.step1.setBackgroundResource(if (n >= 1) on else off)
        binding.step2.setBackgroundResource(if (n >= 2) on else off)
        binding.step3.setBackgroundResource(if (n >= 3) on else off)
        binding.step1.setTextColor(if (n >= 1) onColor else offColor)
        binding.step2.setTextColor(if (n >= 2) onColor else offColor)
        binding.step3.setTextColor(if (n >= 3) onColor else offColor)
    }
}
