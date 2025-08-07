// MonthlyComparisonWidgetProvider.kt
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.abs
import android.util.Log     

class MonthlyComparisonWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
    for (appWidgetId in appWidgetIds) {
        val widgetData = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.widget_monthly_comparison)
//
        // ---- INICIO DE LA CORRECCIÓN ----
        // 1. Leemos los datos como String, que es como los guardamos desde Dart.
        val currentSpendingStr = widgetData.getString("comp_current_spending", "0.0")
        val previousSpendingStr = widgetData.getString("comp_previous_spending", "0.0")
//
        // 2. Convertimos los Strings a Double de forma segura.
        // toDoubleOrNull() previene crashes si el string no es un número válido.
        val currentSpending = currentSpendingStr?.toDoubleOrNull() ?: 0.0
        val previousSpending = previousSpendingStr?.toDoubleOrNull() ?: 0.0
        // ---- FIN DE LA CORRECCIÓN ----
//
        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
        views.setTextViewText(R.id.current_spending_text, currencyFormat.format(currentSpending))
//
        var percentageChange = 0.0
        if (previousSpending > 0) {
            percentageChange = ((currentSpending - previousSpending) / previousSpending) * 100
        }
//
        val changeText: String
        val changeColor: Int
//
        if (percentageChange > 1) { // Pequeño umbral para evitar mostrar 0%
            changeText = "↑ ${abs(percentageChange).toInt()}% vs. mes anterior"
            changeColor = Color.parseColor("#FF7043") // Naranja/Rojo
        } else if (percentageChange < -1) {
            changeText = "↓ ${abs(percentageChange).toInt()}% vs. mes anterior"
            changeColor = Color.parseColor("#66BB6A") // Verde
        } else {
            changeText = "≈ sin cambios"
            changeColor = Color.parseColor("#9E9E9E") // Gris
        }
        
        views.setTextViewText(R.id.percentage_change_text, changeText)
        views.setTextColor(R.id.percentage_change_text, changeColor)
        
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    Log.d("WidgetBypass", "onUpdate para monthlycomparisonwidgetprovider fue llamado, pero se omitió el trabajo pesado.")
    }
}