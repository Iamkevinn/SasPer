// Archivo: android/app/src/main/kotlin/com/example/sasper/GoalsWidgetProvider.kt
package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class GoalsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            
            val serviceIntent = Intent(context, GoalsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            val views = RemoteViews(context.packageName, R.layout.widget_goals_layout).apply {
                setRemoteAdapter(R.id.goals_list_view, serviceIntent)
                // --- [CORRECCIÓN] Se reemplazó "/" por "." ---
                setEmptyView(R.id.goals_list_view, R.id.empty_view)
            }

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

            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.goals_list_view)
        }
    }
}