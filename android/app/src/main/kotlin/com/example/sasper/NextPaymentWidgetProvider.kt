// android/app/src/main/kotlin/com/example/sasper/NextPaymentWidgetProvider.kt

package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.google.gson.Gson
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat
import java.text.SimpleDateFormat
import java.util.Locale

// Reutilizamos el mismo modelo de datos que ya tenemos.
// data class UpcomingPayment(...) ya debería estar definido en otro archivo.

class NextPaymentWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_next_payment_layout)

            // La clave donde guardaremos el JSON del próximo pago.
            val jsonString = widgetData.getString("next_payment_data", null)

            if (jsonString.isNullOrEmpty()) {
                // Si no hay datos, mostramos el mensaje "Estás al día".
                views.setViewVisibility(R.id.next_payment_content, View.GONE)
                views.setViewVisibility(R.id.empty_view_next_payment, View.VISIBLE)
            } else {
                // Si hay datos, los procesamos.
                views.setViewVisibility(R.id.next_payment_content, View.VISIBLE)
                views.setViewVisibility(R.id.empty_view_next_payment, View.GONE)

                try {
                    val payment = Gson().fromJson(jsonString, UpcomingPayment::class.java)

                    // Llenamos las vistas con los datos del pago.
                    views.setTextViewText(R.id.tv_next_payment_concept, payment.concept)

                    // Formateamos el monto.
                    val format = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
                    format.maximumFractionDigits = 0
                    views.setTextViewText(R.id.tv_next_payment_amount, format.format(payment.amount))

                    // Formateamos la fecha.
                    val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
                    val date = isoFormat.parse(payment.nextDueDate)
                    val displayFormat = SimpleDateFormat("dd MMMM yyyy", Locale("es", "ES"))
                    views.setTextViewText(R.id.tv_next_payment_date, "Vence el ${displayFormat.format(date!!)}")

                } catch (e: Exception) {
                    e.printStackTrace()
                    // Si falla el parseo, mostramos el mensaje de "vacío" por seguridad.
                    views.setViewVisibility(R.id.next_payment_content, View.GONE)
                    views.setViewVisibility(R.id.empty_view_next_payment, View.VISIBLE)
                }
            }

            // Hacemos que todo el widget sea clickeable para abrir la app.
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val pendingIntent = PendingIntent.getActivity(context, widgetId, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_next_payment_container, pendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}