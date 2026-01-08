// Archivo: android/app/src/main/kotlin/com/example/sasper/MonthlyComparisonWidgetProvider.kt
package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max

class MonthlyComparisonWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        appWidgetIds.forEach { appWidgetId ->
            
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val views = RemoteViews(context.packageName, R.layout.widget_monthly_comparison)

            val currentSpendingStr = prefs.getString("comp_current_spending", "0.0")
            val previousSpendingStr = prefs.getString("comp_previous_spending", "0.0")

            val currentSpending = currentSpendingStr?.toDoubleOrNull() ?: 0.0
            val previousSpending = previousSpendingStr?.toDoubleOrNull() ?: 0.0

            val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO")).apply {
                maximumFractionDigits = 0
            }

            // --- Lógica de UI Principal ---
            views.setTextViewText(R.id.current_spending_text, currencyFormat.format(currentSpending))

            val difference = currentSpending - previousSpending
            val percentageChange = if (previousSpending > 0) (difference / previousSpending) * 100 else 0.0

            // Actualizar textos de porcentaje y descripción
            when {
                percentageChange > 1 -> {
                    views.setTextViewText(R.id.percentage_change_text, "${abs(percentageChange).toInt()}%")
                    views.setImageViewResource(R.id.trend_arrow, R.drawable.ic_arrow_up)
                    views.setTextViewText(R.id.comparison_description, "Has gastado ${currencyFormat.format(abs(difference))} más")
                }
                percentageChange < -1 -> {
                    views.setTextViewText(R.id.percentage_change_text, "${abs(percentageChange).toInt()}%")
                    views.setImageViewResource(R.id.trend_arrow, R.drawable.ic_arrow_down)
                    views.setTextViewText(R.id.comparison_description, "Has gastado ${currencyFormat.format(abs(difference))} menos")
                }
                else -> {
                    views.setTextViewText(R.id.percentage_change_text, "≈ 0%")
                    views.setImageViewResource(R.id.trend_arrow, R.drawable.ic_check) // Un ícono neutral
                    views.setTextViewText(R.id.comparison_description, "Tus gastos se mantienen estables")
                }
            }

            // --- Lógica de las Barras de Progreso ---
            val maxSpending = max(currentSpending, previousSpending)
            val previousBarPercentage = if (maxSpending > 0) (previousSpending / maxSpending * 100).toInt() else 0
            val currentBarPercentage = if (maxSpending > 0) (currentSpending / maxSpending * 100).toInt() else 0

            // Actualizar etiquetas de las barras
            val now = LocalDate.now()
            val currentMonthName = now.month.getDisplayName(TextStyle.FULL, Locale("es", "ES")).replaceFirstChar { it.uppercase() }
            val previousMonthName = now.minusMonths(1).month.getDisplayName(TextStyle.FULL, Locale("es", "ES")).replaceFirstChar { it.uppercase() }
            
            views.setTextViewText(R.id.current_month_label, currentMonthName)
            views.setTextViewText(R.id.previous_month_label, previousMonthName)
            views.setTextViewText(R.id.comparison_period, "$currentMonthName vs $previousMonthName")

            views.setTextViewText(R.id.current_month_amount, currencyFormat.format(currentSpending))
            views.setTextViewText(R.id.previous_month_amount, currencyFormat.format(previousSpending))

            // Para actualizar el ancho de las barras, necesitamos crear una subclase de RemoteViews o usar un truco.
            // La forma más simple es tener varias imágenes de fondo con diferentes anchos.
            // Por simplicidad aquí, no actualizaremos el ancho dinámicamente, pero la lógica está lista.
            // Para una solución avanzada se requeriría un enfoque más complejo.

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}