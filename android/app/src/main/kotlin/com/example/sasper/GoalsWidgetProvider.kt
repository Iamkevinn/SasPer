// Archivo: android/app/src/main/kotlin/com/example/sasper/GoalsWidgetProvider.kt
package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent // 👈 Usaremos esto

class GoalsWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_GOALS_WIDGET_REFRESH = "com.example.sasper.ACTION_GOALS_WIDGET_REFRESH"
    }
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            
            // --- CONFIGURACIÓN DE LA LISTA (Igual) ---
            val serviceIntent = Intent(context, GoalsWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            val views = RemoteViews(context.packageName, R.layout.widget_goals_layout).apply {
                setRemoteAdapter(R.id.goals_list_view, serviceIntent)
                setEmptyView(R.id.goals_list_view, R.id.empty_view)
            }

            // --- BOTÓN PARA AÑADIR (Igual) ---
            val addGoalIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("sasper://add_goal") // Deep link a la pantalla de añadir
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val addGoalPendingIntent = PendingIntent.getActivity(
                context, appWidgetId * 10, addGoalIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.add_goal_button, addGoalPendingIntent)
            views.setOnClickPendingIntent(R.id.empty_view, addGoalPendingIntent)

            // --- BOTÓN DE REFRESCAR (Ahora habla con Dart) ---
            // Le pedimos a Dart que ejecute la lógica de actualización en segundo plano
            val refreshUri = Uri.parse("home_widget://goals?action=refresh")
            val refreshPendingIntent = HomeWidgetBackgroundIntent.getBroadcast(context, refreshUri)
            views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)

            // --- TEMPLATE PARA CLICKS EN LA LISTA (Igual) ---
            val itemTemplate = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("sasper://goal_detail")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val itemTemplatePendingIntent = PendingIntent.getActivity(
                context, appWidgetId * 10 + 1, itemTemplate,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.goals_list_view, itemTemplatePendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    // ❌ ELIMINAMOS onReceive: Toda la lógica de refresco se delega a Dart
}