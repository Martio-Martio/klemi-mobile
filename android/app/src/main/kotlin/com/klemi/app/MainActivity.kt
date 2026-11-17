package com.klemi.app

import android.annotation.SuppressLint
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "klemi/config_google")
            .setMethodCallHandler { call, result ->
                if (call.method != "lire") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(
                    mapOf(
                        "gidClientId" to "",
                        "schemesUrl" to emptyList<String>(),
                        "clientWebPresent" to clientWebPresent(),
                    ),
                )
            }
    }

    /// Vrai seulement si le plugin google-services a généré un client web
    /// (`oauth_client` de type 3 → `default_web_client_id`).
    @SuppressLint("DiscouragedApi")
    private fun clientWebPresent(): Boolean {
        val id = resources.getIdentifier("default_web_client_id", "string", packageName)
        if (id == 0) return false
        return getString(id).trim().isNotEmpty()
    }
}
