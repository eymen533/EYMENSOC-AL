package com.teslapulse.phonekey

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.webkit.CookieManager
import android.webkit.WebChromeClient
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AppCompatActivity
import com.teslapulse.phonekey.databinding.ActivityHudBinding

class HudActivity : AppCompatActivity() {
    private lateinit var binding: ActivityHudBinding

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityHudBinding.inflate(layoutInflater)
        setContentView(binding.root)

        window.decorView.systemUiVisibility = (
            View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
            )

        val cm = CookieManager.getInstance()
        cm.setAcceptCookie(true)
        cm.setAcceptThirdPartyCookies(binding.webView, true)

        binding.webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            mediaPlaybackRequiresUserGesture = false
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            userAgentString = userAgentString + " TeslaPulseApp/2.0"
            cacheMode = WebSettings.LOAD_DEFAULT
        }
        binding.webView.webChromeClient = WebChromeClient()
        binding.webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView?, url: String?) {
                // Keep session cookies flushed
                CookieManager.getInstance().flush()
            }
        }

        binding.btnReload.setOnClickListener { binding.webView.reload() }
        binding.btnPair.setOnClickListener {
            startActivity(Intent(this, PairActivity::class.java))
        }
        binding.btnSettings.setOnClickListener {
            startActivity(Intent(this, SettingsActivity::class.java))
        }

        loadHud()
    }

    override fun onResume() {
        super.onResume()
        // If server URL changed, reload
        val current = binding.webView.url
        val target = AppPrefs.serverUrl(this) + "/"
        if (current == null || !current.startsWith(AppPrefs.serverUrl(this))) {
            loadHud()
        }
    }

    private fun loadHud() {
        val base = AppPrefs.serverUrl(this)
        CookieManager.getInstance().flush()
        binding.webView.loadUrl("$base/")
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (binding.webView.canGoBack()) binding.webView.goBack() else super.onBackPressed()
    }
}
