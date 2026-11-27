package io.github.trvnce.cartelera

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Servicio en primer plano durante la actualización (ver RefreshService).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cartelera/refresh_service").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(RefreshService.start(applicationContext))
                "progress" -> {
                    RefreshService.progress(applicationContext, call.argument<Int>("done") ?: 0, call.argument<Int>("total") ?: 0)
                    result.success(null)
                }
                "stop" -> {
                    RefreshService.stop(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Actualizaciones desde GitHub Releases (ver Updater.kt y lib/data/updater.dart).
        val updater = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cartelera/updater")
        Updater.onStatus = { ok, message ->
            runOnUiThread { updater.invokeMethod("installStatus", mapOf("ok" to ok, "message" to message)) }
        }
        updater.setMethodCallHandler { call, result ->
            when (call.method) {
                "info" -> result.success(Updater.info(applicationContext))
                "canInstall" -> result.success(Updater.canInstall(applicationContext))
                "openInstallSettings" -> {
                    Updater.openInstallSettings(this)
                    result.success(null)
                }
                "install" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("args", "Falta la ruta del APK", null)
                    } else {
                        // Copiar el APK a la sesión lleva un momento: fuera del hilo principal.
                        Thread {
                            try {
                                Updater.install(applicationContext, path)
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("install", e.message, null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
