package com.teslapulse.phonekey

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.webkit.CookieManager
import androidx.appcompat.app.AppCompatActivity
import com.teslapulse.phonekey.databinding.ActivityLoginBinding

class LoginActivity : AppCompatActivity() {
    private lateinit var binding: ActivityLoginBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        CookieManager.getInstance().setAcceptCookie(true)
        binding = ActivityLoginBinding.inflate(layoutInflater)
        setContentView(binding.root)

        binding.serverHint.text = AppPrefs.serverUrl(this)
        binding.settingsButton.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }
        binding.loginButton.setOnClickListener { doLogin() }
    }

    override fun onResume() {
        super.onResume()
        binding.serverHint.text = AppPrefs.serverUrl(this)
    }

    private fun doLogin() {
        val pin = binding.pinInput.text?.toString()?.trim().orEmpty()
        if (pin.isEmpty()) {
            showError("PIN gir")
            return
        }
        binding.loginButton.isEnabled = false
        binding.loginError.visibility = View.GONE
        PulseApi.unlockAsync(this, pin) { result ->
            runOnUiThread {
                binding.loginButton.isEnabled = true
                if (result.ok) {
                    startActivity(Intent(this, PairActivity::class.java))
                    finish()
                } else {
                    showError(result.error ?: "Giriş başarısız (${result.code})")
                }
            }
        }
    }

    private fun showError(msg: String) {
        binding.loginError.visibility = View.VISIBLE
        binding.loginError.text = msg
    }
}
