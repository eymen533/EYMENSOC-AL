package com.teslapulse.phonekey

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.teslapulse.phonekey.databinding.ActivitySettingsBinding

class SettingsActivity : AppCompatActivity() {
    private lateinit var binding: ActivitySettingsBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivitySettingsBinding.inflate(layoutInflater)
        setContentView(binding.root)
        binding.serverInput.setText(AppPrefs.serverUrl(this))
        binding.saveButton.setOnClickListener {
            val url = binding.serverInput.text?.toString()?.trim().orEmpty()
            if (!url.startsWith("http://") && !url.startsWith("https://")) {
                Toast.makeText(this, "http(s):// ile başlamalı", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }
            AppPrefs.setServerUrl(this, url)
            Toast.makeText(this, "Kaydedildi", Toast.LENGTH_SHORT).show()
            finish()
        }
    }
}
