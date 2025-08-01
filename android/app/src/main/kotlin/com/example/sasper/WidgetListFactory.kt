// Archivo: app/src/main/kotlin/com/example/sasper/WidgetListFactory.kt

package com.example.sasper

import android.content.Context
import android.content.Intent
import android.util.Log
import android.util.TypedValue
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.annotation.AttrRes
import androidx.annotation.ColorInt
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class WidgetListFactory(private val context: Context, private val intent: Intent) : RemoteViewsService.RemoteViewsFactory {
    
    private val TAG = "WidgetListFactory"
    private var items: List<Any> = emptyList()
    private val listType = intent.getStringExtra("LIST_TYPE") ?: "UNKNOWN"
    
    @ColorInt private var positiveColor: Int = 0
    @ColorInt private var negativeColor: Int = 0

    @ColorInt
    private fun getThemeColor(@AttrRes colorAttr: Int): Int {
        val typedValue = TypedValue()
        context.theme.resolveAttribute(colorAttr, typedValue, true)
        return typedValue.data
    }

    override fun onCreate() {
        Log.d(TAG, "onCreate para lista de tipo: $listType")
        // Obtenemos los colores del tema cuando se crea la Factory
        positiveColor = getThemeColor(R.attr.positiveColor)
        negativeColor = getThemeColor(R.attr.negativeColor)
    }

    override fun onDataSetChanged() {
        Log.d(TAG, "onDataSetChanged - Recargando datos para lista tipo: $listType")
        val widgetData = HomeWidgetPlugin.getData(context)
        val gson = Gson()
        
        try {
            items = if (listType == "BUDGETS") {
                val budgetsJson = widgetData.getString("featured_budgets_json", "[]")
                Log.d(TAG, "JSON de presupuestos: $budgetsJson")
                // Asegura que los datos nulos resulten en una lista vacía
                gson.fromJson<List<BudgetWidgetItem>>(budgetsJson, object : TypeToken<List<BudgetWidgetItem>>() {}.type) ?: emptyList()
            } else if (listType == "TRANSACTIONS") {
                val transactionsJson = widgetData.getString("recent_transactions_json", "[]")
                Log.d(TAG, "JSON de transacciones: $transactionsJson")
                // Asegura que los datos nulos resulten en una lista vacía
                gson.fromJson<List<TransactionWidgetItem>>(transactionsJson, object : TypeToken<List<TransactionWidgetItem>>() {}.type) ?: emptyList()
            } else {
                Log.w(TAG, "Tipo de lista desconocido: $listType")
                emptyList()
            }
            Log.d(TAG, "Datos cargados. Número de items: ${items.size}")
        } catch (e: Exception) {
            Log.e(TAG, "Error fatal al parsear JSON para la lista $listType: ${e.message}", e)
            items = emptyList() // Si hay un error, nos aseguramos que la lista esté vacía.
        }
    }

    override fun onDestroy() {
        Log.d(TAG, "onDestroy - Limpiando datos.")
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position >= items.size) {
            Log.w(TAG, "getViewAt solicitó una posición inválida: $position. Total de items: ${items.size}")
            return null
        }

        // Usamos un `when` con `is` para un casteo de tipos seguro y evitar ClassCastException.
        return when (val item = items[position]) {
            is BudgetWidgetItem -> {
                RemoteViews(context.packageName, R.layout.widget_budget_item_layout).apply {
                    setTextViewText(R.id.widget_item_budget_title, item.category)
                    
                    // CORRECCIÓN: Se calcula el progreso a partir del valor decimal (0.0 a 1.0)
                    val progressInt = (item.progress * 100).toInt()
                    setProgressBar(R.id.widget_item_budget_progress, 100, progressInt, false)
                }
            }
            is TransactionWidgetItem -> {
                // ===== LOG DE DEPURACIÓN 2 =====
                Log.d(TAG, "VERDAD ABSOLUTA (Objeto Transacción Parseado): description=${item.description}, amount=${item.amount}, category=${item.category}")
                // =================================
                RemoteViews(context.packageName, R.layout.widget_transaction_item_layout).apply {
                    setTextViewText(R.id.widget_item_transaction_title, item.description ?: "Transacción")
                    
                    // ===== CORRECCIÓN CLAVE =====
                    // Se establece el texto para el TextView de la categoría que añadimos en el XML.
                    setTextViewText(R.id.widget_item_transaction_category, item.category ?: "Sin categoría")

                    // Se formatea el monto y se establece el color dinámicamente
                    val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
                    setTextViewText(R.id.widget_item_transaction_amount, currencyFormat.format(item.amount))
                    
                    val color = if (item.amount < 0) negativeColor else positiveColor
                    setTextColor(R.id.widget_item_transaction_amount, color)
                }
            }
            else -> {
                // Si por alguna razón el tipo de item es desconocido, no crasheamos.
                Log.e(TAG, "Tipo de item desconocido en la posición $position: ${item.javaClass.name}")
                null
            }
        }
    }

    override fun getLoadingView(): RemoteViews {
        // Devolvemos una vista de carga simple para una mejor experiencia de usuario
        return RemoteViews(context.packageName, R.layout.widget_loading_layout)
    }

    override fun getViewTypeCount(): Int = 2 // 2 tipos de vista: budget y transaction
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}