package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider
import android.util.Log     
class SasPerLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            WidgetUpdater.updateLargeWidget(context, appWidgetManager, widgetId, widgetData)
        }
        Log.d("WidgetBypass", "onUpdate para SasPerLargeWidgetProvider fue llamado, pero se omitió el trabajo pesado.")
    }
}