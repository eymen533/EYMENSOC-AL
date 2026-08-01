package com.teslapulse.phonekey

import android.content.Context

object AppPrefs {
    private const val PREFS = "tesla_pulse"

    fun serverUrl(context: Context): String {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("server", BuildConfig.DEFAULT_SERVER)
            ?.trim()
            .orEmpty()
        return raw.trimEnd('/')
    }

    fun setServerUrl(context: Context, url: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("server", url.trim().trimEnd('/'))
            .apply()
    }

    fun vin(context: Context): String {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString("vin", BuildConfig.DEFAULT_VIN)
            ?.uppercase()
            .orEmpty()
    }

    fun setVin(context: Context, vin: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString("vin", vin.trim().uppercase())
            .apply()
    }

    fun paired(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean("paired", false)

    fun setPaired(context: Context, value: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("paired", value)
            .apply()
    }
}
