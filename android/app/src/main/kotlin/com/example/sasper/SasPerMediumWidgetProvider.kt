package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri // <-- AÑADIR IMPORT
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

class SasPerMediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // 1. Dibuja inmediatamente con los datos guardados
            WidgetUpdater.updateMediumWidget(context, appWidgetManager, widgetId, widgetData)

            // 2. Pide a Dart que busque datos nuevos en segundo plano
            val pendingIntent = HomeWidgetBackgroundIntent.getBroadcast(
                context,
                Uri.parse("sasper://update-medium-widget")
            )
            pendingIntent.send()
        }
    }
}