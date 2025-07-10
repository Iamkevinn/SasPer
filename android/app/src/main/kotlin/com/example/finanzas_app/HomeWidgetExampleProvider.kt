package com.example.finanzas_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class HomeWidgetExampleProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: android.content.SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
                val balance = widgetData.getString("balance", "...")
                setTextViewText(R.id.widget_balance, balance ?: "Error")

                // --- NUEVA LÓGICA DE LANZAMIENTO DIRECTO ---
                // Se crea un Intent que apunta DIRECTAMENTE a la actividad principal de Flutter
                
                // Intent para "Añadir Transacción"
                val addTransactionIntent = Intent(context, Class.forName("com.example.finanzas_app.MainActivity")).apply {
                    action = "WIDGET_CLICK" // Una acción personalizada para identificar que viene de un widget
                    putExtra("widget_action", "add_transaction") // Acción estándar para ver contenido
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val addTransactionPendingIntent = PendingIntent.getActivity(
                    context, 101, addTransactionIntent,
                    // Flag de inmutabilidad es crucial para Android 12+
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                setOnClickPendingIntent(R.id.btn_add_transaction, addTransactionPendingIntent)

                // Intent para abrir el Dashboard
                val openDashboardIntent = Intent(context, Class.forName("com.example.finanzas_app.MainActivity")).apply {
                    // Ponemos la acción específica en los extras
                    putExtra("widget_action", "open_dashboard")
                    action = "WIDGET_CLICK"
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val openDashboardPendingIntent = PendingIntent.getActivity(
                    context, 202, openDashboardIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                )
                setOnClickPendingIntent(R.id.widget_root, openDashboardPendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}