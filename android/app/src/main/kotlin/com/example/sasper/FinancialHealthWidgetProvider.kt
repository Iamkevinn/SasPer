// Archivo: android/app/src/main/kotlin/com/example/sasper/FinancialHealthWidgetProvider.kt

package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundService
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class FinancialHealthWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            // Leemos los datos directamente de SharedPreferences para asegurar que sean los más frescos.
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val widgetData = prefs.all

            val views = RemoteViews(context.packageName, R.layout.widget_financial_health)

            fun getDoubleSafely(key: String): Double {
                val value = widgetData[key]
                if (value is Long) return Double.fromBits(value)
                if (value is Number) return value.toDouble()
                return 0.0 // Valor por defecto
            }

            // Lectura y formato de datos
            val spendingPace = getDoubleSafely("w_health_spending_pace")
            val savingsRate = getDoubleSafely("w_health_savings_rate")
            
            val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO")).apply {
                maximumFractionDigits = 0
            }
            val savingsRatePercentage = (savingsRate * 100).toInt()

            // Asignación de textos a la UI
            views.setTextViewText(R.id.insight_1_text, "${currencyFormat.format(spendingPace)}/día")
            views.setTextViewText(R.id.insight_2_text, "$savingsRatePercentage%")
            views.setTextViewText(R.id.widget_last_update, "Actualizado ahora")

            // Configuración de Acciones (Intents)
            val launchAppIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.sasper.ACTION_OPEN_FINANCIAL_HEALTH"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val launchAppPendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 1, // Request code único por widget
                launchAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root_container, launchAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_action_button, launchAppPendingIntent)

            val refreshIntent = Intent(context, HomeWidgetBackgroundService::class.java)
            val refreshPendingIntent = PendingIntent.getService(
                context,
                appWidgetId * 10 + 2, // Request code único por widget
                refreshIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_refresh_button, refreshPendingIntent)

            Log.d("FinancialHealthWidget", "onUpdate - Ritmo: $spendingPace, Ahorro: $savingsRate")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}