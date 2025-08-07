package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import androidx.annotation.AttrRes
import androidx.annotation.ColorInt
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import java.text.NumberFormat
import java.util.Locale

// --- MODELOS DE DATOS DE KOTLIN (Añadidos aquí) ---
// Estos deben coincidir con los campos del JSON que envías desde Dart.
data class WidgetBudget(
    val category: String,
    // Asegúrate de que tu JSON de Dart incluya 'progress'
    val progress: Double 
)

data class WidgetTransaction(
    val description: String?, // Hacemos los strings nullable por seguridad
    val category: String?,    // <-- CORRECCIÓN: De 'categoryName' a 'category'
    val amount: Double,
    val type: String
)



object WidgetUpdater {

    private const val TAG = "WidgetDebug"

    // Claves para leer de SharedPreferences. DEBEN COINCIDIR CON LAS DE DART.
    private const val KEY_BUDGETS = "featured_budgets_json"
    private const val KEY_TRANSACTIONS = "recent_transactions_json"

    // --- FUNCIONES DE WIDGETS PEQUEÑO Y MEDIANO (SIN CAMBIOS) ---

    fun updateSmallWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        // Tu código existente aquí, sin cambios...
        Log.d(TAG, "Iniciando updateSmallWidget para el widgetId: $widgetId")
        val views = RemoteViews(context.packageName, R.layout.home_widget_layout)

        val balance = widgetData.getString("total_balance", "...") ?: "..."
        views.setTextViewText(R.id.widget_balance, balance)
        Log.d(TAG, "Balance (small) actualizado a: $balance")

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingLaunch = PendingIntent.getActivity(context, widgetId * 10, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_root_linear_layout, pendingLaunch)

        val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val pendingAdd = PendingIntent.getActivity(context, widgetId * 10 + 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_button, pendingAdd)
        
        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "updateSmallWidget completado para el widgetId: $widgetId")
    }

    fun updateMediumWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        // Tu código existente aquí, sin cambios...
        Log.d(TAG, "Iniciando updateMediumWidget para el widgetId: $widgetId")
        val views = RemoteViews(context.packageName, R.layout.widget_medium_layout)

        val balance = widgetData.getString("total_balance", "...") ?: "..."
        views.setTextViewText(R.id.widget_medium_balance, balance)
        Log.d(TAG, "Balance (medium) actualizado a: $balance")

        val chartPath = widgetData.getString("widget_chart_path", null)
        if (chartPath != null && chartPath.isNotEmpty()) {
            val chartFile = File(chartPath)
            if (chartFile.exists()) {
                Log.d(TAG, "Intentando decodificar el gráfico desde: $chartPath")
                try {
                    val bitmap = BitmapFactory.decodeFile(chartFile.absolutePath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_medium_chart, bitmap)
                        views.setViewVisibility(R.id.widget_medium_chart, View.VISIBLE)
                        Log.d(TAG, "Gráfico cargado correctamente.")
                    } else {
                        Log.e(TAG, "Error al decodificar el bitmap. El archivo podría estar corrupto.")
                        views.setViewVisibility(R.id.widget_medium_chart, View.GONE)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Excepción al cargar el bitmap del gráfico: ${e.message}", e)
                    views.setViewVisibility(R.id.widget_medium_chart, View.GONE)
                }
            } else {
                Log.w(TAG, "El archivo del gráfico no existe en la ruta: $chartPath")
                views.setViewVisibility(R.id.widget_medium_chart, View.GONE)
            }
        } else {
            Log.d(TAG, "No se proporcionó ruta para el gráfico.")
            views.setViewVisibility(R.id.widget_medium_chart, View.GONE)
        }

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingLaunch = PendingIntent.getActivity(context, widgetId * 10 + 2, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_medium_container, pendingLaunch)

        val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val pendingAdd = PendingIntent.getActivity(context, widgetId * 10 + 3, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_medium_add_button, pendingAdd)

        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "updateMediumWidget completado para el widgetId: $widgetId")
    }

    // --- FUNCIÓN DEL WIDGET GRANDE (VERSIÓN FUNCIONAL) ---
    fun updateLargeWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        Log.d(TAG, "=================================================")
        Log.d(TAG, "[$widgetId] INICIANDO actualización de Widget Grande (VERSIÓN FUNCIONAL)")
        
        val views = RemoteViews(context.packageName, R.layout.widget_large_layout)
        val gson = Gson()
        
        // --- 1. PROCESAR PRESUPUESTOS ---
        val budgetsJson = widgetData.getString(KEY_BUDGETS, "[]")
        Log.d(TAG, "[$widgetId] JSON de Presupuestos recibido: $budgetsJson")
        try {
            val budgetListType = object : TypeToken<List<WidgetBudget>>() {}.type
            val budgets: List<WidgetBudget> = gson.fromJson(budgetsJson, budgetListType)
            Log.d(TAG, "[$widgetId] Presupuestos Parseados: ${budgets.size}")

            // Llenar Presupuesto 1
            if (budgets.isNotEmpty()) {
                populateBudget(context, views, budgets[0], 1)
            } else {
                views.setViewVisibility(R.id.budget_item_1, View.GONE)
            }

            // Llenar Presupuesto 2
            if (budgets.size > 1) {
                populateBudget(context, views, budgets[1], 2)
            } else {
                views.setViewVisibility(R.id.budget_item_2, View.GONE)
            }

        } catch (e: Exception) {
            Log.e(TAG, "[$widgetId] CRASH en la sección de presupuestos: ${e.message}", e)
            views.setViewVisibility(R.id.budget_item_1, View.GONE)
            views.setViewVisibility(R.id.budget_item_2, View.GONE)
        }

        // --- 2. PROCESAR TRANSACCIONES ---
        val transactionsJson = widgetData.getString(KEY_TRANSACTIONS, "[]")
        Log.d(TAG, "[$widgetId] JSON de Transacciones recibido: $transactionsJson")
        try {
            val transactionListType = object : TypeToken<List<WidgetTransaction>>() {}.type
            val transactions: List<WidgetTransaction> = gson.fromJson(transactionsJson, transactionListType)
            Log.d(TAG, "[$widgetId] Transacciones Parseadas: ${transactions.size}")

            // Llenar Transacción 1
            if (transactions.isNotEmpty()) {
                populateTransaction(context, views, transactions[0], 1)
            } else {
                views.setViewVisibility(R.id.transaction_item_1, View.GONE)
            }

            // Llenar Transacción 2
            if (transactions.size > 1) {
                populateTransaction(context, views, transactions[1], 2)
            } else {
                views.setViewVisibility(R.id.transaction_item_2, View.GONE)
            }
            
            // Llenar Transacción 3
            if (transactions.size > 2) {
                populateTransaction(context, views, transactions[2], 3)
            } else {
                views.setViewVisibility(R.id.transaction_item_3, View.GONE)
            }

        } catch (e: Exception) {
            Log.e(TAG, "[$widgetId] CRASH en la sección de transacciones: ${e.message}", e)
            views.setViewVisibility(R.id.transaction_item_1, View.GONE)
            views.setViewVisibility(R.id.transaction_item_2, View.GONE)
            views.setViewVisibility(R.id.transaction_item_3, View.GONE)
        }

        // --- 3. CONFIGURAR INTENTS ---
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pendingLaunch = PendingIntent.getActivity(context, widgetId * 10 + 4, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_large_container, pendingLaunch)
        
        val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val pendingAdd = PendingIntent.getActivity(context, widgetId * 10 + 5, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_large_add_button, pendingAdd)

        // --- 4. ACTUALIZACIÓN FINAL ---
        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "[$widgetId] FIN de la actualización de Widget Grande (VERSIÓN FUNCIONAL)")
        Log.d(TAG, "=================================================")
    }

    // --- FUNCIONES AUXILIARES (HELPERS) ---
    private fun populateBudget(context: Context, views: RemoteViews, budget: WidgetBudget, index: Int) {
        val titleId = context.resources.getIdentifier("budget_item_${index}_title", "id", context.packageName)
        val percentageId = context.resources.getIdentifier("budget_item_${index}_percentage", "id", context.packageName)
        val progressId = context.resources.getIdentifier("budget_item_${index}_progress", "id", context.packageName)
        val containerId = context.resources.getIdentifier("budget_item_${index}", "id", context.packageName)

        views.setTextViewText(titleId, budget.category)
        val percentage = (budget.progress * 100).toInt()
        views.setTextViewText(percentageId, "$percentage%")
        views.setProgressBar(progressId, 100, percentage, false)
        views.setViewVisibility(containerId, View.VISIBLE)
    }

    private fun populateTransaction(context: Context, views: RemoteViews, transaction: WidgetTransaction, index: Int) {
        val titleId = context.resources.getIdentifier("transaction_item_${index}_title", "id", context.packageName)
        val categoryId = context.resources.getIdentifier("transaction_item_${index}_category", "id", context.packageName)
        val amountId = context.resources.getIdentifier("transaction_item_${index}_amount", "id", context.packageName)
        val containerId = context.resources.getIdentifier("transaction_item_${index}", "id", context.packageName)

        val format = NumberFormat.getCurrencyInstance(Locale("es", "CO"))
        format.maximumFractionDigits = 0
        
        // CORRECCIÓN: Usamos transaction.category y proveemos un valor por defecto si es nulo
        views.setTextViewText(titleId, transaction.description ?: "Sin descripción")
        views.setTextViewText(categoryId, transaction.category ?: "Sin categoría")
        views.setTextViewText(amountId, format.format(transaction.amount))

        val color = if (transaction.type == "Gasto") Color.parseColor("#E57373") else Color.parseColor("#81C784")
        views.setTextColor(amountId, color)
        
        views.setViewVisibility(containerId, View.VISIBLE)
    }
}