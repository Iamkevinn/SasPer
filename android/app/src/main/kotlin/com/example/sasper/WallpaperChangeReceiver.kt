package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

class WallpaperChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val appWidgetManager = AppWidgetManager.getInstance(context)

        // --- CORRECCIÓN: ACTUALIZAR AMBOS TIPOS DE WIDGETS ---

        // 1. Actualizar todos los widgets pequeños
        val smallWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, SasPerWidgetProvider::class.java))
        smallWidgetIds.forEach { widgetId ->
            WidgetUpdater.updateSmallWidget(context, appWidgetManager, widgetId, widgetData)
        }

        // 2. Actualizar todos los widgets medianos
        val mediumWidgetIds = appWidgetManager.getAppWidgetIds(ComponentName(context, SasPerMediumWidgetProvider::class.java))
        mediumWidgetIds.forEach { widgetId ->
            WidgetUpdater.updateMediumWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }
}