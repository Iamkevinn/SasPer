// android/app/src/main/kotlin/com/example/sasper/UpcomingPaymentsWidgetService.kt
package com.example.sasper

import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import android.content.SharedPreferences // <--- AÑADIR ESTE IMPORT
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone

// Modelo de datos en Kotlin que coincide con el JSON de Dart
data class UpcomingPayment(
    val id: String,
    val concept: String,
    val amount: Double,
    val nextDueDate: String,
    val type: String
)

class UpcomingPaymentsListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return UpcomingPaymentsListFactory(this.applicationContext)
    }
}

class UpcomingPaymentsListFactory(private val context: Context) : RemoteViewsService.RemoteViewsFactory {
    private var payments: List<UpcomingPayment> = emptyList()

    override fun onCreate() {
        // Se llama al crear la factory, es un buen lugar para cargar los datos iniciales.
        fetchData()
    }

    override fun onDataSetChanged() {
        // Android llama a este método cuando notificamos que los datos del widget han cambiado.
        fetchData()
    }

    private fun fetchData() {
        // --- INICIO DE LA CORRECCIÓN ---

        // AHORA (Correcto): Accedemos a los datos a través de SharedPreferences, que es como
        // el plugin home_widget realmente los almacena.
        val prefs: SharedPreferences = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val jsonString = prefs.getString("upcoming_payments_data", null)

        // AHORA (Correcto): Comprobamos que jsonString no sea nulo antes de usarlo.
        if (jsonString != null) {
            try {
                // El parseo de Gson va dentro de un try-catch por si el JSON estuviera corrupto.
                val type = object : TypeToken<List<UpcomingPayment>>() {}.type
                payments = Gson().fromJson(jsonString, type)
            } catch (e: Exception) {
                // Si hay un error de parseo, lo registramos y aseguramos que la lista esté vacía.
                e.printStackTrace()
                payments = emptyList()
            }
        } else {
            // Si no hay datos guardados, nos aseguramos de que la lista esté vacía.
            payments = emptyList()
        }
        // --- FIN DE LA CORRECCIÓN ---
    }

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_upcoming_payment_item)
        val payment = payments[position]

        views.setTextViewText(R.id.tv_concept, payment.concept)
        // Usar Locale.US para el formato de punto flotante para evitar comas en algunas regiones
        views.setTextViewText(R.id.tv_amount, String.format(Locale.US, "€%.2f", payment.amount))

        // Formatear la fecha (el código anterior estaba bien, pero lo refinamos un poco)
        try {
            // Asumiendo que el formato ISO 8601 viene de Dart
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault())
            val date = isoFormat.parse(payment.nextDueDate)
            val displayFormat = SimpleDateFormat("dd/MM/yyyy", Locale.getDefault())
            views.setTextViewText(R.id.tv_due_date, displayFormat.format(date!!))
        } catch (e: Exception) {
            // Si la fecha está mal formateada, mostramos el string original o un placeholder
            views.setTextViewText(R.id.tv_due_date, "Fecha inválida")
            e.printStackTrace()
        }

        return views
    }

    // El resto de los métodos de la factory no necesitan cambios.
    override fun getCount(): Int = payments.size
    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
    override fun onDestroy() {}
}