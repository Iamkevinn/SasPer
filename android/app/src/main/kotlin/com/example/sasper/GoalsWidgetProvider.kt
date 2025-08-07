// android/app/src/main/kotlin/com/example/sasper/GoalsWidgetProvider.kt
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.net.Uri
import android.util.Log

class GoalsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // Crear el Intent para el servicio que poblará la lista
            val intent = Intent(context, GoalsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            // Obtener las RemoteViews y vincular el adaptador del servicio
            val views = RemoteViews(context.packageName, R.layout.widget_goals_layout).apply {
                setRemoteAdapter(R.id.goals_list_view, intent)
                setEmptyView(R.id.goals_list_view, R.id.empty_view)
            }

            // Actualizar el widget
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.goals_list_view)
        }
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        Log.d("WidgetBypass", "onUpdate para GoalsWidgetProvider fue llamado, pero se omitió el trabajo pesado.")
    }
}