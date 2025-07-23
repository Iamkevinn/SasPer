// android/app/src/main/kotlin/com/example/sasper/SasPerWidgetProvider.kt
package com.example.sasper

import android.app.PendingIntent
import android.app.WallpaperManager
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import androidx.core.graphics.drawable.toBitmap
import androidx.palette.graphics.Palette
import es.antonborri.home_widget.HomeWidgetProvider

class SasPerWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetIds: IntArray,
    widgetData: android.content.SharedPreferences
  ) {
    // 1. Extrae color dinámico del wallpaper (Android 12+)
    val wallpaperManager = WallpaperManager.getInstance(context)
    val colors = wallpaperManager.getWallpaperColors(WallpaperManager.FLAG_SYSTEM)
    // fallback pastel claro si no hay ningún wallpaperColors
    val bgColor = colors?.primaryColor?.toArgb() ?: 0xFFF5F1E6.toInt()

    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
        // 2. Fondo dinámico
        setInt(R.id.widget_container, "setBackgroundColor", bgColor)

        // 3. Texto de saldo
        val balance = widgetData.getString("total_balance", "--.--") ?: "--.--"
        setTextViewText(R.id.widget_balance, balance)

        // 4. Click para abrir la app
        val launchIntent = context.packageManager
          .getLaunchIntentForPackage(context.packageName)
        val pendingLaunch = PendingIntent.getActivity(
          context, 0, launchIntent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        setOnClickPendingIntent(R.id.widget_container, pendingLaunch)

        // 5. Click en botón para añadir transacción
        val addIntent = Intent(context, MainActivity::class.java).apply {
          action = Intent.ACTION_VIEW
          data = Uri.parse("sasper://add_transaction")
        }
        val pendingAdd = PendingIntent.getActivity(
          context, 1, addIntent,
          PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        setOnClickPendingIntent(R.id.widget_button, pendingAdd)
      }

      // 6. Aplica cambios
      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
