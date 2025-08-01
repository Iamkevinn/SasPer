// Archivo: app/src/main/kotlin/com/example/sasper/WidgetUpdater.kt

package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
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

object WidgetUpdater {

    // ===== CAMBIO 1: AÑADIMOS UN TAG PARA LOGS DE DEPURACIÓN =====
    // Esto nos permitirá filtrar los mensajes en Logcat y ver solo los de nuestros widgets.
    private const val TAG = "WidgetDebug"

    // ===== CAMBIO 2: HELPER PARA OBTENER COLORES DEL TEMA ACTUAL =====
    // Esta función nos permite obtener colores dinámicos (para modo claro/oscuro)
    // usando los atributos del tema, en lugar de colores fijos.
    @ColorInt
    private fun getThemeColor(context: Context, @AttrRes colorAttr: Int): Int {
        val typedValue = TypedValue()
        context.theme.resolveAttribute(colorAttr, typedValue, true)
        return typedValue.data
    }

    fun updateSmallWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
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
                    // ===== CAMBIO 3: MANEJO DE BITMAP NULO =====
                    // BitmapFactory.decodeFile puede devolver nulo si el archivo está corrupto.
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_medium_chart, bitmap)
                        views.setViewVisibility(R.id.widget_medium_chart, View.VISIBLE)
                        Log.d(TAG, "Gráfico cargado correctamente.")
                    } else {
                        Log.e(TAG, "Error al decodificar el bitmap. El archivo podría estar corrupto.")
                        views.setViewVisibility(R.id.widget_medium_chart, View.GONE)
                    }
                } catch (e: Exception) {
                    // Si algo falla (ej. OutOfMemoryError), lo capturamos y lo registramos.
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
    
    fun updateLargeWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        Log.d(TAG, "Iniciando updateLargeWidget para el widgetId: $widgetId")
        val views = RemoteViews(context.packageName, R.layout.widget_large_layout)
        
        val gson = Gson()
        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "ES"))

        val budgets: List<BudgetWidgetItem> = try {
            val budgetsJson = widgetData.getString("budgets_json", "[]")
            gson.fromJson(budgetsJson, object : TypeToken<List<BudgetWidgetItem>>() {}.type) ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error al parsear budgets_json: ${e.message}", e)
            emptyList()
        }
        
        Log.d(TAG, "Presupuestos parseados. Total: ${budgets.size}")

        views.setViewVisibility(R.id.budget_item_1, View.GONE)
        views.setViewVisibility(R.id.budget_item_2, View.GONE)

        budgets.getOrNull(0)?.let {
            views.setTextViewText(R.id.budget_item_1_title, "🍔 ${it.category}")
            views.setProgressBar(R.id.budget_item_1_progress, 100, (it.progress * 100).toInt(), false)
            views.setViewVisibility(R.id.budget_item_1, View.VISIBLE)
        }
        budgets.getOrNull(1)?.let {
            views.setTextViewText(R.id.budget_item_2_title, "🚗 ${it.category}")
            views.setProgressBar(R.id.budget_item_2_progress, 100, (it.progress * 100).toInt(), false)
            views.setViewVisibility(R.id.budget_item_2, View.VISIBLE)
        }

        val transactions: List<TransactionWidgetItem> = try {
            val transactionsJson = widgetData.getString("recent_transactions_json", "[]")
            gson.fromJson(transactionsJson, object : TypeToken<List<TransactionWidgetItem>>() {}.type) ?: emptyList()
        } catch (e: Exception) {
            Log.e(TAG, "Error al parsear recent_transactions_json: ${e.message}", e)
            emptyList()
        }
        
        Log.d(TAG, "Transacciones parseadas. Total: ${transactions.size}")

        views.setViewVisibility(R.id.transaction_item_1, View.GONE)
        views.setViewVisibility(R.id.transaction_item_2, View.GONE)
        views.setViewVisibility(R.id.transaction_item_3, View.GONE)
        
        val positiveColor = getThemeColor(context, R.attr.positiveColor)
        val negativeColor = getThemeColor(context, R.attr.negativeColor)

        transactions.getOrNull(0)?.let { tx ->
            // ===== CORRECCIÓN AQUÍ =====
            val title = tx.description?.trim() ?: "Transacción"
            views.setTextViewText(R.id.transaction_item_1_title, title)
            views.setTextViewText(R.id.transaction_item_1_amount, currencyFormat.format(tx.amount))
            views.setTextColor(R.id.transaction_item_1_amount, if (tx.amount < 0) negativeColor else positiveColor)
            views.setViewVisibility(R.id.transaction_item_1, View.VISIBLE)
        }
        transactions.getOrNull(1)?.let { tx ->
            // ===== CORRECCIÓN AQUÍ =====
            val title = tx.description?.trim() ?: "Transacción"
            views.setTextViewText(R.id.transaction_item_2_title, title)
            views.setTextViewText(R.id.transaction_item_2_amount, currencyFormat.format(tx.amount))
            views.setTextColor(R.id.transaction_item_2_amount, if (tx.amount < 0) negativeColor else positiveColor)
            views.setViewVisibility(R.id.transaction_item_2, View.VISIBLE)
        }
        transactions.getOrNull(2)?.let { tx ->
            // ===== CORRECCIÓN AQUÍ =====
            val title = tx.description?.trim() ?: "Transacción"
            views.setTextViewText(R.id.transaction_item_3_title, title)
            views.setTextViewText(R.id.transaction_item_3_amount, currencyFormat.format(tx.amount))
            views.setTextColor(R.id.transaction_item_3_amount, if (tx.amount < 0) negativeColor else positiveColor)
            views.setViewVisibility(R.id.transaction_item_3, View.VISIBLE)
        }

        val uniqueRequestCode = widgetId * 10
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val launchPendingIntent = PendingIntent.getActivity(context, uniqueRequestCode, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_large_container, launchPendingIntent)

        val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val addPendingIntent = PendingIntent.getActivity(context, uniqueRequestCode + 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_large_add_button, addPendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
        Log.d(TAG, "updateLargeWidget completado para el widgetId: $widgetId")
    }
}