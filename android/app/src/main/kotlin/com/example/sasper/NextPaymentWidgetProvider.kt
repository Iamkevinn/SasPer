// Archivo: android/app/src/main/kotlin/com/example/sasper/NextPaymentWidgetProvider.kt

package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import android.graphics.Color
import com.google.gson.Gson
import es.antonborri.home_widget.HomeWidgetBackgroundService
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.NumberFormat
import java.time.LocalDateTime
import java.time.ZonedDateTime
import java.time.temporal.ChronoUnit
import java.util.Locale
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

class NextPaymentWidgetProvider : HomeWidgetProvider() {

    private val ACTION_REFRESH_PAYMENT = "com.example.sasper.ACTION_REFRESH_PAYMENT"

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_next_payment_layout)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("next_payment_data", null)

            if (jsonString.isNullOrEmpty() || jsonString == "null") {
                showEmptyState(views)
            } else {
                try {
                    val payment = Gson().fromJson(jsonString, UpcomingPayment::class.java)
                    showPaymentState(context, views, payment, widgetId)
                } catch (e: Exception) {
                    e.printStackTrace()
                    showEmptyState(views)
                }
            }

            // --- DEEP LINK PARA ABRIR LA PANTALLA CORRECTA ---
            // Al tocar el widget entero, abrirá la app (idealmente en la pantalla de pendientes)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("sasper://pending_payments") // Configura esto en tu app/router si lo necesitas
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val launchPendingIntent = PendingIntent.getActivity(
                context, widgetId, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_next_payment_container, launchPendingIntent)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun showEmptyState(views: RemoteViews) {
        views.setViewVisibility(R.id.next_payment_content, View.GONE)
        views.setViewVisibility(R.id.empty_view_next_payment, View.VISIBLE)
    }

    private fun showPaymentState(
        context: Context,
        views: RemoteViews,
        payment: UpcomingPayment,
        widgetId: Int
    ) {
        views.setViewVisibility(R.id.next_payment_content, View.VISIBLE)
        views.setViewVisibility(R.id.empty_view_next_payment, View.GONE)

        // ── Formatear monto ───────────────────────────────────────────────────
        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
            .apply { maximumFractionDigits = 0 }
        val amountText = currencyFormat.format(payment.amount)

        // ── Parsear fecha ─────────────────────────────────────────────────────
        val dueDate = try {
            ZonedDateTime.parse(payment.nextDueDate).toLocalDateTime()
        } catch (e: DateTimeParseException) {
            LocalDateTime.parse(payment.nextDueDate)
        }

        // ── Calcular días restantes ───────────────────────────────────────────
        val now = LocalDateTime.now()
        val daysRemaining = ChronoUnit.DAYS.between(now.toLocalDate(), dueDate.toLocalDate())

        val statusText = when {
            daysRemaining < 0  -> "Vencido"
            daysRemaining == 0L -> "Vence hoy"
            daysRemaining == 1L -> "Vence mañana"
            else               -> "Vence en $daysRemaining días"
        }

        // ── Texto de categoría / tipo ─────────────────────────────────────────
        val categoryLabel: String = when {
            !payment.subtype.isNullOrBlank() -> payment.subtype
            else -> when (payment.type) {
                "debt"       -> "Deuda"
                "recurring"  -> "Recurrente"
                "freeTrial"  -> "Prueba gratuita"
                "creditCard" -> "Tarjeta de crédito"
                else         -> payment.type.replaceFirstChar { it.uppercase() }
            }
        }

        // ── Aplicar textos ────────────────────────────────────────────────────
        views.setTextViewText(R.id.tv_next_payment_amount, amountText)
        views.setTextViewText(R.id.tv_next_payment_concept, payment.concept)
        // Combinamos la categoría y el estado para un look más limpio
        views.setTextViewText(R.id.tv_payment_category, "$categoryLabel · $statusText")

        // ── Color dinámico de urgencia (Estilo Apple) ──────────────────────────
        // Si vence en 3 días o menos (o ya venció), pintamos el monto de Rojo
        if (daysRemaining <= 3) {
            views.setTextColor(R.id.tv_next_payment_amount, Color.parseColor("#FF453A")) // iOS Red
        } else {
            // Usamos un color normal que extraemos de los recursos de Android (Theme)
            // Como RemoteViews no siempre pilla bien los atributos dinámicos programáticamente,
            // si quieres asegurarlo, lo dejas como lo pusiste en el XML.
            // Para "resetear" el color y dejar que el XML mande, a veces es complejo en RemoteViews,
            // pero podemos forzar el color de texto primario en modo oscuro si lo deseas.
            // Por defecto, si no es urgente, el XML aplicará el color `?attr/colorOnSurface`.
        }

        // ── Botón "Recargar" ──────────────────────────────────────────────────
        val refreshIntent = Intent(context, NextPaymentWidgetProvider::class.java).apply {
            action = ACTION_REFRESH_PAYMENT
            data = Uri.parse("home_widget://widget?action=refresh_next_payment")
        }
        val refreshPendingIntent = PendingIntent.getBroadcast(
            context, 100 + widgetId, refreshIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.refresh_button, refreshPendingIntent)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        if (intent.action == ACTION_REFRESH_PAYMENT) {
            val backgroundIntent = Intent(context, HomeWidgetBackgroundService::class.java).apply {
                data = Uri.parse("home_widget://widget?action=refresh_next_payment")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(backgroundIntent)
            } else {
                context.startService(backgroundIntent)
            }
        }
    }
}