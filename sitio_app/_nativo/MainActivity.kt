package com.tocadoscoelhos.sitio.equipe

import android.content.Intent
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Responde ao app se o aparelho TEM NFC / câmera e se o NFC está ligado.
/// Não exige permissão nova (a de NFC já está no manifesto).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sitio/dispositivo")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "estadoNfc" -> {
                        val adapter = NfcAdapter.getDefaultAdapter(this)
                        result.success(
                            when {
                                adapter == null -> "sem_hardware"
                                adapter.isEnabled -> "ligado"
                                else -> "desligado"
                            }
                        )
                    }
                    "temCamera" -> result.success(
                        packageManager.hasSystemFeature(PackageManager.FEATURE_CAMERA_ANY)
                    )
                    "abrirConfigNfc" -> {
                        try {
                            startActivity(
                                Intent(Settings.ACTION_NFC_SETTINGS)
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
