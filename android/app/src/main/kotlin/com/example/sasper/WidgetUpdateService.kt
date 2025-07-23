// android/app/src/main/kotlin/com/example/sasper/WidgetUpdateService.kt
package com.example.sasper

import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder

class WidgetUpdateService : Service() {

    // Creamos una instancia de nuestro receptor
    private val wallpaperReceiver = WallpaperChangeReceiver()

    override fun onCreate() {
        super.onCreate()
        // Cuando el servicio se crea, registramos nuestro receptor
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_WALLPAPER_CHANGED)
            addAction(Intent.ACTION_CONFIGURATION_CHANGED)
        }
        registerReceiver(wallpaperReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        // Cuando el servicio se destruye, quitamos el registro para evitar fugas de memoria
        unregisterReceiver(wallpaperReceiver)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Le decimos al sistema que si mata este servicio, intente recrearlo.
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        // No necesitamos enlazar a este servicio, así que devolvemos null.
        return null
    }
}