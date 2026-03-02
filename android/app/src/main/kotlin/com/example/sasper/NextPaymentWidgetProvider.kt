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

    private val ACTION_MARK_AS_PAID = "com.example.sasper.ACTION_MARK_AS_PAID"
    private val ACTION_REFRESH_PAYMENT = "com.example.sasper.ACTION_REFRESH_PAYMENT"

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        println("✅ [NextPaymentWidget] onUpdate triggered.")
        appWidgetIds.forEach { widgetId ->
            println("✅ [NextPaymentWidget] Processing widgetId: $widgetId")
            val views = RemoteViews(context.packageName, R.layout.widget_next_payment_layout)

            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonString = prefs.getString("next_payment_data", null)
            println("✅ [NextPaymentWidget] JSON String from SharedPreferences: $jsonString")

            if (jsonString.isNullOrEmpty()) {
                println("✅ [NextPaymentWidget] jsonString is null or empty. Showing empty state.")
                showEmptyState(views)
            } else {
                try {
                    println("✅ [NextPaymentWidget] jsonString found. Entering try block.")

                    println("  [DEBUG] Step 1: Parsing JSON with Gson.")
                    val payment = Gson().fromJson(jsonString, UpcomingPayment::class.java)
                    println("  [DEBUG] Step 1 SUCCESS. Payment concept: ${payment.concept}")

                    println("  [DEBUG] Step 2: Calling showPaymentState.")
                    showPaymentState(context, views, payment, widgetId)
                    println("  [DEBUG] Step 2 SUCCESS. showPaymentState completed without error.")

                } catch (e: Exception) {
                    println("🔥🔥🔥 [NextPaymentWidget] FATAL ERROR in onUpdate's try-catch block: ${e.message}")
                    e.printStackTrace()
                    showEmptyState(views)
                }
            }

            println("✅ [NextPaymentWidget] Setting up main container click intent.")
            val launchIntent = Intent(context, MainActivity::class.java)
            val launchPendingIntent = PendingIntent.getActivity(
                context, widgetId, launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_next_payment_container, launchPendingIntent)

            println("✅ [NextPaymentWidget] Calling appWidgetManager.updateAppWidget for widgetId: $widgetId")
            appWidgetManager.updateAppWidget(widgetId, views)
            println("✅ [NextPaymentWidget] Update complete for widgetId: $widgetId")
        }
    }

    private fun showEmptyState(views: RemoteViews) {
        println("  [DEBUG] showEmptyState called.")
        views.setViewVisibility(R.id.next_payment_content, View.GONE)
        views.setViewVisibility(R.id.empty_view_next_payment, View.VISIBLE)
    }

    private fun showPaymentState(
        context: Context,
        views: RemoteViews,
        payment: UpcomingPayment,
        widgetId: Int
    ) {
        println("  [DEBUG] Inside showPaymentState. Payment: $payment")

        views.setViewVisibility(R.id.next_payment_content, View.VISIBLE)
        views.setViewVisibility(R.id.empty_view_next_payment, View.GONE)

        // ── Formatear monto ───────────────────────────────────────────────────
        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
            .apply { maximumFractionDigits = 0 }
        val amountText = currencyFormat.format(payment.amount)
        println("    [DETAIL] Amount formatted: $amountText")

        // ── Parsear fecha ─────────────────────────────────────────────────────
        println("    [DETAIL] Parsing date string: ${payment.nextDueDate}")
        val dueDate = try {
            ZonedDateTime.parse(payment.nextDueDate).toLocalDateTime()
        } catch (e: DateTimeParseException) {
            LocalDateTime.parse(payment.nextDueDate)
        }
        println("    [DETAIL] Date parsed successfully: $dueDate")

        // ── Calcular días restantes ───────────────────────────────────────────
        val now = LocalDateTime.now()
        val daysRemaining = ChronoUnit.DAYS.between(now.toLocalDate(), dueDate.toLocalDate())
        println("    [DETAIL] Days remaining: $daysRemaining")

        val statusText = when {
            daysRemaining < 0  -> context.getString(R.string.payment_overdue, -daysRemaining)
            daysRemaining == 0L -> context.getString(R.string.payment_due_today)
            daysRemaining == 1L -> context.getString(R.string.payment_due_tomorrow)
            else               -> context.getString(R.string.days_until_payment, daysRemaining)
        }
        println("    [DETAIL] Status text: '$statusText'")

        // ── Texto de categoría / tipo ─────────────────────────────────────────
        // Prioridad: subtype (texto en español de Dart) > etiqueta local por type.
        //
        // subtype viene relleno para freeTrial ("Prueba gratuita") y
        // creditCard ("Cuota 3 de 12"). Para debt y recurring viene null.
        //
        // La cadena en español viene de Dart para no duplicar traducciones.
        val categoryLabel: String = when {
            // Si Dart envió subtype, lo usamos directamente
            !payment.subtype.isNullOrBlank() -> payment.subtype

            // Fallback local por tipo técnico
            else -> when (payment.type) {
                "debt"       -> "Deuda"
                "recurring"  -> "Recurrente"
                "freeTrial"  -> "Prueba gratuita"
                "creditCard" -> "Tarjeta de crédito"
                else         -> payment.type.replaceFirstChar { it.uppercase() }
            }
        }
        println("    [DETAIL] Category label: '$categoryLabel'")

        // ── Aplicar textos ────────────────────────────────────────────────────
        views.setTextViewText(R.id.tv_next_payment_concept, payment.concept)
        views.setTextViewText(R.id.tv_next_payment_amount, amountText)
        views.setTextViewText(R.id.tv_payment_category, categoryLabel)

        val dateFormatter = DateTimeFormatter.ofPattern("d 'de' MMMM", Locale("es", "ES"))
        views.setTextViewText(R.id.tv_next_payment_date, dateFormatter.format(dueDate))
        views.setTextViewText(R.id.tv_days_until_payment, statusText)

        // ── Badge de urgencia ─────────────────────────────────────────────────
        val isUrgent = daysRemaining <= 3
        views.setViewVisibility(
            R.id.urgency_badge_container,
            if (isUrgent) View.VISIBLE else View.GONE
        )
        if (isUrgent) {
            val badgeText = if (daysRemaining < 0) "VENCIDO" else "URGENTE"
            views.setTextViewText(R.id.urgency_badge, badgeText)
        }

        // ── Botón "Marcar como pagado" ────────────────────────────────────────
        val markAsPaidIntent = Intent(context, NextPaymentWidgetProvider::class.java).apply {
            action = ACTION_MARK_AS_PAID
            putExtra("payment_id", payment.id)
            data = Uri.parse("intent://widget/id/$widgetId/${payment.id}")
        }
        val markAsPaidPendingIntent = PendingIntent.getBroadcast(
            context, widgetId, markAsPaidIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.mark_as_paid_button, markAsPaidPendingIntent)
        println("    [DETAIL] 'Mark as Paid' button setup complete.")

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
        println("    [DETAIL] 'Refresh' button setup complete.")
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_MARK_AS_PAID) {
            val paymentId = intent.getStringExtra("payment_id")
            println("✅ [WIDGET_ACTION] Botón 'Marcar como Pagado' presionado para el pago ID: $paymentId")
            val backgroundIntent = Intent(context, HomeWidgetBackgroundService::class.java).apply {
                data = Uri.parse("home_widget://mark_as_paid?paymentId=$paymentId")
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(backgroundIntent)
            } else {
                context.startService(backgroundIntent)
            }
        } else if (intent.action == ACTION_REFRESH_PAYMENT) {
            println("✅ [WIDGET_ACTION] Botón 'Recargar' presionado")
            val backgroundIntent = Intent(context, HomeWidgetBackgroundService::class.java).apply {
                // Enviamos la misma URI que utiliza el botón (host widget + query)
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