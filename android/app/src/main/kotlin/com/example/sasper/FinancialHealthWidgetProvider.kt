package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale
import android.util.Log     

class FinancialHealthWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.widget_financial_health)

            // [CAMBIO CLAVE] Esta función ahora lee el Long y lo reinterpreta como Double.
            fun getDoubleSafely(key: String): Double {
                val value = widgetData.all[key]
                // 1. Verificamos que sea un Long (entero de 64 bits).
                if (value is Long) {
                    // 2. Usamos Double.fromBits para convertir la representación
                    //    binaria del Long de vuelta a un Double.
                    return Double.fromBits(value)
                }
                // Si por alguna razón es otro tipo de número, intentamos convertirlo.
                if (value is Number) {
                    return value.toDouble()
                }
                // Si no existe o no es un número, devolvemos 0.0.
                return 0.0
            }

            // --- LEEMOS LOS DATOS USANDO LA NUEVA FUNCIÓN ---
            val spendingPace = getDoubleSafely("w_health_spending_pace")
            val savingsRate = getDoubleSafely("w_health_savings_rate")
            
            // La lógica de formato ya debería funcionar correctamente.
            val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
            currencyFormat.maximumFractionDigits = 0 // Opcional: para no mostrar decimales en el widget

            // Aseguramos que el porcentaje no se desborde y se muestre correctamente.
            val savingsRatePercentage = (savingsRate * 100).toInt()

            views.setTextViewText(R.id.insight_1_text, "Ritmo: ${currencyFormat.format(spendingPace)}/día")
            views.setTextViewText(R.id.insight_2_text, "Ahorro: $savingsRatePercentage%")

            // Log para depuración
            Log.d("FinancialHealthWidget", "onUpdate - Ritmo: $spendingPace, Ahorro: $savingsRate, %: $savingsRatePercentage")

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}