package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class SasPerMediumWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // Llama a la lógica centralizada para el widget mediano
            WidgetUpdater.updateMediumWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }
}