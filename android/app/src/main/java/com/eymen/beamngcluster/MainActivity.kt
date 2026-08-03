package com.eymen.beamngcluster

import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.ActivityInfo
import android.graphics.Bitmap
import android.os.Bundle
import android.view.View
import android.view.inputmethod.EditorInfo
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
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
import org.json.JSONObject
import kotlin.math.max
import kotlin.math.sin

class MainActivity : AppCompatActivity() {
    private lateinit var binding: ActivityMainBinding
    private var demoJob: Job? = null
    private var clusterReady = false
    private val prefs by lazy { getSharedPreferences("eymen", Context.MODE_PRIVATE) }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)
        hideSystemUi()

        binding.portValue.text = "Port $HTTP_PORT"
        binding.pcIpInput.setText(prefs.getString("pc_ip", "") ?: "")

        binding.pcIpInput.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                openCluster(demo = false)
                true
            } else false
        }

        binding.btnStart.setOnClickListener { openCluster(demo = false) }
        binding.btnDemo.setOnClickListener { openCluster(demo = true) }

        binding.clusterWeb.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            mediaPlaybackRequiresUserGesture = false
            cacheMode = WebSettings.LOAD_NO_CACHE
            mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
            allowFileAccess = true
        }
        binding.clusterWeb.webChromeClient = WebChromeClient()
        binding.clusterWeb.webViewClient = object : WebViewClient() {
            override fun onPageStarted(view: WebView?, url: String?, favicon: Bitmap?) {
                clusterReady = false
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                clusterReady = true
            }

            override fun onReceivedError(
                view: WebView?,
                request: WebResourceRequest?,
                error: WebResourceError?,
            ) {
                if (request?.isForMainFrame == true) {
                    Toast.makeText(
                        this@MainActivity,
                        "PC’ye ulaşılamadı. .bat açık mı? IP doğru mu?",
                        Toast.LENGTH_LONG,
                    ).show()
                }
            }
        }
    }

    private fun openCluster(demo: Boolean) {
        demoJob?.cancel()
        binding.setupRoot.visibility = View.GONE
        binding.clusterWeb.visibility = View.VISIBLE
        clusterReady = false

        if (demo) {
            binding.clusterWeb.loadUrl("file:///android_asset/index.html")
            // Inject minimal demo via local assets after load — use built-in JS demo page if present,
            // else synthesize through evaluateJavascript loop using public-like API.
            startLocalDemo()
            return
        }

        val ip = binding.pcIpInput.text?.toString()?.trim().orEmpty()
            .removePrefix("http://").removePrefix("https://")
            .substringBefore("/")
            .substringBefore(":")
        if (ip.isEmpty()) {
            Toast.makeText(this, "PC IP yaz", Toast.LENGTH_SHORT).show()
            binding.setupRoot.visibility = View.VISIBLE
            binding.clusterWeb.visibility = View.GONE
            return
        }
        prefs.edit().putString("pc_ip", ip).apply()
        val url = "http://$ip:$HTTP_PORT/"
        Toast.makeText(this, "Bağlanıyor: $url", Toast.LENGTH_SHORT).show()
        binding.clusterWeb.loadUrl(url)
    }

    /** Offline demo when PC bridge is not used. */
    private fun startLocalDemo() {
        demoJob = lifecycleScope.launch {
            // wait for page
            delay(400)
            var t = 0.0
            var trail = org.json.JSONArray()
            while (isActive) {
                t += 0.05
                val speedKmh = 40 + 80 * (0.5 + 0.5 * sin(t * 0.35))
                val rpm = 1200 + 4800 * (0.45 + 0.45 * sin(t * 0.7))
                val gearNum = minOf(6, maxOf(1, (speedKmh / 28).toInt() + 1))
                val ang = t * 0.4
                val r = 80 + 20 * sin(t * 0.1)
                val x = kotlin.math.cos(ang) * r
                val y = kotlin.math.sin(ang) * r
                trail.put(JSONObject().put("x", x).put("y", y).put("t", System.currentTimeMillis()))
                if (trail.length() > 120) {
                    val next = org.json.JSONArray()
                    for (i in trail.length() - 120 until trail.length()) next.put(trail.get(i))
                    trail = next
                }
                val json = JSONObject().apply {
                    put("gearLabel", gearNum.toString())
                    put("speedKmh", speedKmh)
                    put("speedMph", speedKmh * 0.621371)
                    put("preferKm", true)
                    put("rpm", rpm)
                    put("turbo", 0.4 + 0.6 * max(0.0, sin(t)))
                    put("engTemp", 88 + 4 * sin(t * 0.2))
                    put("fuel", 0.62)
                    put("throttle", 0.3 + 0.5 * (0.5 + 0.5 * sin(t * 0.7)))
                    put("brake", max(0.0, sin(t * 0.2) - 0.7))
                    put("showTurbo", true)
                    put("source", "demo")
                    put("lights", JSONObject().apply {
                        put("shift", rpm > 5500)
                        put("fullbeam", true)
                        put("handbrake", false)
                        put("tc", false)
                        put("signalL", (t * 2).toInt() % 2 == 0 && sin(t * 0.15) > 0.7)
                        put("signalR", false)
                        put("oilWarn", false)
                        put("battery", false)
                        put("abs", false)
                    })
                    put("map", JSONObject().apply {
                        put("x", x); put("y", y); put("z", 0)
                        put("yaw", ang + Math.PI / 2)
                        put("velX", 0); put("velY", 0)
                        put("speedMs", speedKmh / 3.6)
                    })
                    put("trail", trail)
                }.toString()
                val escaped = JSONObject.quote(json)
                binding.clusterWeb.evaluateJavascript(
                    "window.__eymenPush && window.__eymenPush($escaped)",
                    null,
                )
                delay(50)
            }
        }
    }

    private fun hideSystemUi() {
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).let { controller ->
            controller.hide(WindowInsetsCompat.Type.systemBars())
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
    }

    override fun onDestroy() {
        demoJob?.cancel()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        if (binding.clusterWeb.visibility == View.VISIBLE) {
            demoJob?.cancel()
            binding.clusterWeb.loadUrl("about:blank")
            binding.clusterWeb.visibility = View.GONE
            binding.setupRoot.visibility = View.VISIBLE
            clusterReady = false
        } else {
            @Suppress("DEPRECATION")
            super.onBackPressed()
        }
    }

    companion object {
        const val HTTP_PORT = 8080
    }
}
