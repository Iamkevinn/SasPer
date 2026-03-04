// android/app/src/main/kotlin/com/example/sasper/MainActivity.kt
package com.example.sasper

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Bundle

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.example.sasper/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateGoalsWidget") {
                val intent = Intent(this, GoalsWidgetProvider::class.java).apply {
                    action = GoalsWidgetProvider.ACTION_GOALS_WIDGET_REFRESH
                }
                sendBroadcast(intent)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Inicia el servicio de escucha de widgets
        // Esto asegurará que el receptor de cambio de wallpaper esté activo
        val serviceIntent = Intent(this, WidgetUpdateService::class.java)
        startService(serviceIntent)
    }
}