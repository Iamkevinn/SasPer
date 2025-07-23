// android/app/src/main/kotlin/com/example/sasper/WallpaperChangeReceiver.kt
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

class WallpaperChangeReceiver : BroadcastReceiver() {
  override fun onReceive(context: Context, intent: Intent?) {
    if (intent?.action != Intent.ACTION_WALLPAPER_CHANGED) return

    // Encontrar todos los IDs de tu widget
    val mgr = AppWidgetManager.getInstance(context)
    val comp = ComponentName(context, SasPerWidgetProvider::class.java)
    val ids = mgr.getAppWidgetIds(comp)

    // Re-emite el update para forzar onUpdate() en tu provider
    val update = Intent(context, SasPerWidgetProvider::class.java).apply {
      action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
      putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
    }
    context.sendBroadcast(update)
  }
}
