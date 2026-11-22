package com.tocadoscoelhos.sitio.equipe

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
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
                    "mostrarNotificacao" -> {
                        try {
                            mostrarNotificacao(
                                call.argument<String>("titulo") ?: "Sítio",
                                call.argument<String>("corpo") ?: ""
                            )
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
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

    /// Canal de alta prioridade: o aviso aparece flutuando no topo da tela.
    private fun criarCanal() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CANAL) == null) {
            val c = NotificationChannel(CANAL, "Avisos do Sítio", NotificationManager.IMPORTANCE_HIGH)
            c.description = "Eventos, estoque baixo e avisos da equipe"
            nm.createNotificationChannel(c)
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        criarCanal()
    }

    /// Mostra o aviso na bandeja do Android mesmo com o app aberto
    /// (o FCM sozinho não mostra nada quando o app está em primeiro plano).
    private fun mostrarNotificacao(titulo: String, corpo: String) {
        criarCanal()
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val abrir = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CANAL) else @Suppress("DEPRECATION") Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_stat_sitio)
            .setContentTitle(titulo)
            .setContentText(corpo)
            .setStyle(Notification.BigTextStyle().bigText(corpo))
            .setColor(resources.getColor(R.color.notificacao_cor, null))
            .setContentIntent(abrir)
            .setAutoCancel(true)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION") b.setPriority(Notification.PRIORITY_HIGH)
        }
        nm.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), b.build())
    }

    companion object {
        const val CANAL = "sitio_avisos"
    }
}
