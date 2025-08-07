package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import es.antonborri.home_widget.HomeWidgetProvider
import android.util.Log     

class SasPerWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            // La única responsabilidad de onUpdate es dibujar el widget con los datos actuales.
            WidgetUpdater.updateSmallWidget(context, appWidgetManager, widgetId, widgetData)
        }
        Log.d("WidgetBypass", "onUpdate para sasperwidgetprovider fue llamado, pero se omitió el trabajo pesado.")
    }
}