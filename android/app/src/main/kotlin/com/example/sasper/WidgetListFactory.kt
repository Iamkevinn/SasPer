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
    
    // ===== CAMBIO 1: AÑADIMOS TAG PARA LOGS Y VARIABLES DE COLOR =====
    private val TAG = "WidgetListFactory"
    private var items: List<Any> = emptyList()
    private val listType = intent.getStringExtra("LIST_TYPE") ?: "UNKNOWN"
    
    // Almacenamos los colores una vez para no tener que buscarlos en cada `getViewAt`
    @ColorInt private var positiveColor: Int = 0
    @ColorInt private var negativeColor: Int = 0

    // ===== CAMBIO 2: HELPER PARA OBTENER COLORES DEL TEMA =====
    // Reutilizamos la misma función para obtener colores del tema actual.
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
        
        // ===== CAMBIO 3: PARSEO DE JSON SEGURO Y A PRUEBA DE CRASHES =====
        // Envolvemos todo en un bloque try-catch para evitar crashes si el JSON es inválido.
        try {
            items = if (listType == "BUDGETS") {
                val budgetsJson = widgetData.getString("featured_budgets_json", "[]")
                Log.d(TAG, "JSON de presupuestos: $budgetsJson")
                gson.fromJson<List<BudgetWidgetItem>>(budgetsJson, object : TypeToken<List<BudgetWidgetItem>>() {}.type) ?: emptyList()
            } else if (listType == "TRANSACTIONS") {
                val transactionsJson = widgetData.getString("recent_transactions_json", "[]")
                Log.d(TAG, "JSON de transacciones: $transactionsJson")
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

        // ===== CAMBIO 4: LÓGICA DE VISTAS MÁS SEGURA Y CON COLORES DINÁMICOS =====
        // Usamos un `when` con `is` para un casteo de tipos seguro y evitar ClassCastException.
        return when (val item = items[position]) {
            is BudgetWidgetItem -> {
                RemoteViews(context.packageName, R.layout.widget_budget_item_layout).apply {
                    setTextViewText(R.id.widget_item_budget_title, "🍔 ${item.category}")
                    setProgressBar(R.id.widget_item_budget_progress, 100, (item.progress * 100).toInt(), false)
                }
            }
            is TransactionWidgetItem -> {
                RemoteViews(context.packageName, R.layout.widget_transaction_item_layout).apply {
                    setTextViewText(R.id.widget_item_transaction_title, item.description ?: "Transacción")
                    
                    val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "ES"))
                    setTextViewText(R.id.widget_item_transaction_amount, currencyFormat.format(item.amount))
                    
                    // ¡Usamos los colores del tema que cargamos en onCreate!
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

    override fun getLoadingView(): RemoteViews? {
        // Puedes opcionalmente devolver una vista de "cargando..." aquí.
        return null
    }

    override fun getViewTypeCount(): Int = 2 // Ahora tenemos 2 tipos de vista: budget y transaction
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}