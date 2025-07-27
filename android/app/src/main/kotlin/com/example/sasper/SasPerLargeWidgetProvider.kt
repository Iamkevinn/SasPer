package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider

class SasPerLargeWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // Dejaremos que el WidgetUpdater haga el trabajo pesado
            // WidgetUpdater.updateLargeWidget(context, appWidgetManager, widgetId, widgetData)
            WidgetUpdater.updateLargeWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }
}