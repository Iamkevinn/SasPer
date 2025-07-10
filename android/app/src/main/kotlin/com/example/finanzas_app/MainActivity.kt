package com.example.finanzas_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.finanzas_app/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getWidgetAction") {
                val action = intent.getStringExtra("widget_action")
                result.success(action)
                // Limpiamos el extra para que no se vuelva a leer
                intent.removeExtra("widget_action")
            } else {
                result.notImplemented()
            }
        }
    }
}