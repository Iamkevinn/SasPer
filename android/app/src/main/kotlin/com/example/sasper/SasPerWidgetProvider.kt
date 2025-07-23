// android/app/src/main/kotlin/com/example/sasper/SasPerWidgetProvider.kt (VERSIÓN FINAL Y CORREGIDA)
package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SasPerWidgetProvider : HomeWidgetProvider() {

    // onUpdate ahora solo llama a nuestra función centralizada
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        updateWidget(context, appWidgetManager, appWidgetIds, widgetData)
    }

    // El companion object contiene la lógica que queremos compartir
    companion object {
        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
            appWidgetIds.forEach { widgetId ->
                val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
                    
                    // --- 1. Lógica de Colores Dinámicos ---
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val primaryColor = context.getColor(android.R.color.system_accent1_600)
                        val secondaryColor = context.getColor(android.R.color.system_accent1_100)
                        val onPrimaryColor = context.getColor(android.R.color.system_neutral1_50)
                        val onSecondaryColor = context.getColor(android.R.color.system_neutral1_800)

                        setInt(R.id.widget_root_linear_layout, "setBackgroundColor", secondaryColor)
                        setTextColor(R.id.widget_title, onSecondaryColor)
                        setTextColor(R.id.widget_balance, onSecondaryColor)
                        setInt(R.id.widget_button, "setColorFilter", onPrimaryColor)
                        setInt(R.id.widget_button, "setBackgroundColor", primaryColor)

                    } else {
                        // Fallback para versiones antiguas de Android
                        val fallbackBg = Color.parseColor("#EFEFEF")
                        val fallbackText = Color.BLACK
                        setInt(R.id.widget_root_linear_layout, "setBackgroundColor", fallbackBg)
                        setTextColor(R.id.widget_title, fallbackText)
                        setTextColor(R.id.widget_balance, fallbackText)
                    }

                    // --- 2. Lógica de Datos de Flutter ---
                    val balance = widgetData.getString("total_balance", "$0") ?: "$0"
                    setTextViewText(R.id.widget_balance, balance)

                    // --- 3. Lógica de Clics (SIN DUPLICADOS) ---
                    
                    // Abrir la app al hacer clic en cualquier parte del widget
                    val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    val pendingLaunch = PendingIntent.getActivity(
                        context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_root_linear_layout, pendingLaunch)

                    // Abrir "Añadir Transacción" al hacer clic en el botón (+)
                    val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    val pendingAdd = PendingIntent.getActivity(
                        context, 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    setOnClickPendingIntent(R.id.widget_button, pendingAdd)
                }
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }
}