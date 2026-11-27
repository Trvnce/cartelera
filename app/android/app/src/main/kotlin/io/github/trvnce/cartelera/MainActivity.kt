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
    }
}
