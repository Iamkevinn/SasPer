// Archivo: android/app/src/main/kotlin/com/example/sasper/GoalsWidgetProvider.kt
package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import android.content.ComponentName

class GoalsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_GOALS_WIDGET_REFRESH = "com.example.sasper.ACTION_GOALS_WIDGET_REFRESH"
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            
            val serviceIntent = Intent(context, GoalsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            val views = RemoteViews(context.packageName, R.layout.widget_goals_layout).apply {
                setRemoteAdapter(R.id.goals_list_view, serviceIntent)
                setEmptyView(R.id.goals_list_view, R.id.empty_view)
            }

            // Botón para añadir una nueva meta
            val addGoalIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.sasper.ACTION_ADD_GOAL"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val addGoalPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 1,
                addGoalIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.add_goal_button, addGoalPendingIntent)
            views.setOnClickPendingIntent(R.id.empty_view, addGoalPendingIntent)

            // Botón para refrescar el widget
            val refreshIntent = Intent(context, GoalsWidgetProvider::class.java).apply {
                action = ACTION_GOALS_WIDGET_REFRESH
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val refreshPendingIntent = PendingIntent.getBroadcast(
                context,
                appWidgetId,
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.goals_list_view)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_GOALS_WIDGET_REFRESH) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisAppWidget = ComponentName(context.packageName, javaClass.name)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisAppWidget)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, R.id.goals_list_view)
        }
    }
}