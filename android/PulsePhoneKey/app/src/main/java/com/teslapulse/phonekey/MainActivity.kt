package com.teslapulse.phonekey

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import androidx.core.view.isVisible
import com.teslapulse.phonekey.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private var pairer: BlePairer? = null
    private val logs = ArrayDeque<String>()

    private val permissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) { result ->
            if (result.values.all { it }) {
                beginPair()
            } else {
                setStatus("Bluetooth / konum izni gerekli")
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val saved = getSharedPreferences("pulse_ui", MODE_PRIVATE).getString("vin", "")
        if (!saved.isNullOrBlank()) binding.vinInput.setText(saved)

        // Prefill from known owner VIN if shipped via build config later — leave empty
        binding.pairButton.setOnClickListener { ensurePermissionsAndPair() }
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
        if (needed.isNotEmpty()) {
            permissionLauncher.launch(needed.toTypedArray())
        } else {
            beginPair()
        }
    }

    private fun granted(p: String) =
        ContextCompat.checkSelfPermission(this, p) == PackageManager.PERMISSION_GRANTED

    private fun beginPair() {
        val vin = binding.vinInput.text?.toString()?.trim()?.uppercase().orEmpty()
        if (vin.length != 17) {
            Toast.makeText(this, "VIN 17 karakter olmalı", Toast.LENGTH_SHORT).show()
            return
        }
        getSharedPreferences("pulse_ui", MODE_PRIVATE).edit().putString("vin", vin).apply()
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
                }
            },
            onDone = {
                runOnUiThread {
                    highlightStep(3)
                    binding.pairButton.isEnabled = true
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
        binding.step1.isVisible = true
    }
}
