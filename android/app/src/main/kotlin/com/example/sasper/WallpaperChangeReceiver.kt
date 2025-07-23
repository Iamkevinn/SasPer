// android/app/src/main/kotlin/com/example/sasper/WallpaperChangeReceiver.kt (VERSIÓN FINAL)
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import es.antonborri.home_widget.HomeWidgetPlugin

class WallpaperChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        // Solo reaccionar a estas dos acciones
        if (intent?.action == Intent.ACTION_WALLPAPER_CHANGED || intent?.action == Intent.ACTION_CONFIGURATION_CHANGED) {
            
            // Obtenemos una instancia del AppWidgetManager
            val appWidgetManager = AppWidgetManager.getInstance(context)
            
            // Obtenemos los IDs de todos los widgets de nuestra app
            val componentName = ComponentName(context, SasPerWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            // Obtenemos los datos guardados por Flutter (el balance)
            val widgetData = HomeWidgetPlugin.getData(context)

            // Llamamos directamente a nuestra función de actualización centralizada
            SasPerWidgetProvider.updateWidget(context, appWidgetManager, appWidgetIds, widgetData)
        }
    }
}