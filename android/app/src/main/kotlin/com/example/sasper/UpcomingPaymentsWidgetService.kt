// Archivo: android/app/src/main/kotlin/com/example/sasper/UpcomingPaymentsWidgetService.kt

package com.example.sasper

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.text.NumberFormat
import java.time.LocalDateTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit
import java.util.Locale
import android.os.Bundle // Importar Bundle

class UpcomingPaymentsListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return UpcomingPaymentsListFactory(this.applicationContext)
    }
}

class UpcomingPaymentsListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var payments: List<UpcomingPayment> = emptyList()

    override fun onCreate() {
        // No es necesario hacer nada aquí
    }

    override fun onDataSetChanged() {
        // Aquí es donde se leen los datos frescos
        val prefs: SharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("upcoming_payments_data", null)

        payments = if (jsonString != null) {
            try {
                val type = object : TypeToken<List<UpcomingPayment>>() {}.type
                Gson().fromJson(jsonString, type)
            } catch (e: Exception) {
                e.printStackTrace()
                emptyList()
            }
        } else {
            emptyList()
        }
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_payment_item)
        val payment = payments[position]

        // --- Lógica de datos y UI para cada ítem ---

        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO")).apply {
            maximumFractionDigits = 0
        }
        
        // Lógica de fecha robusta (igual que en el otro widget)
        val dueDate = try {
            ZonedDateTime.parse(payment.nextDueDate).toLocalDateTime()
        } catch (e: DateTimeParseException) {
            LocalDateTime.parse(payment.nextDueDate.take(23))
        }
        val daysRemaining = ChronoUnit.DAYS.between(LocalDateTime.now().toLocalDate(), dueDate.toLocalDate())

        val statusText = when {
            daysRemaining < 0 -> "Vencido"
            daysRemaining == 0L -> "Hoy"
            daysRemaining == 1L -> "Mañana"
            else -> "en $daysRemaining días"
        }

        // --- Aplicar datos a la UI ---

        views.setTextViewText(R.id.tv_concept, payment.concept)
        views.setTextViewText(R.id.tv_amount, currencyFormat.format(payment.amount))
        views.setTextViewText(R.id.tv_days_remaining, statusText)

        val dateFormatter = DateTimeFormatter.ofPattern("d MMM", Locale("es", "ES"))
        views.setTextViewText(R.id.tv_due_date, dateFormatter.format(dueDate))

        // Cambiar el color del indicador de urgencia
        val indicatorColor = when {
            daysRemaining <= 1 -> Color.RED
            daysRemaining <= 7 -> Color.parseColor("#FFA726") // Naranja
            else -> Color.GRAY
        }
        views.setInt(R.id.urgency_indicator_bar, "setBackgroundColor", indicatorColor)

        // --- Configurar el intent de click para este ítem específico ---
        val fillInIntent = Intent().apply {
            val extras = Bundle()
            extras.putString("payment_id", payment.id)
            putExtras(extras)
        }
        views.setOnClickFillInIntent(R.id.upcoming_payment_item_container, fillInIntent)


        return views
    }
    
    // --- Métodos de la Factory (sin cambios) ---
    override fun getCount(): Int = payments.size
    override fun getLoadingView(): RemoteViews? = null // Podríamos poner un layout de carga aquí
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = payments[position].id.hashCode().toLong()
    override fun hasStableIds(): Boolean = true
    override fun onDestroy() {
        // Limpiar recursos si es necesario
    }
}