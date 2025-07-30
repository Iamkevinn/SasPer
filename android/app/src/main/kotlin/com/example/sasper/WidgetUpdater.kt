// Archivo: C:\Proyectos\SasPer\android\app\src\main\kotlin\com\example\sasper\WidgetUpdater.kt

package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import java.io.File
import java.text.NumberFormat
import java.util.Locale

// Clases de datos para que Gson pueda parsear el JSON de Dart.
// Asegúrate de que los nombres de las propiedades coincidan con los `toJson` de tus modelos en Dart.
 
object WidgetUpdater {

    fun updateSmallWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
            applyDynamicColors(context)
            val balance = widgetData.getString("total_balance", "...") ?: "..."
            setTextViewText(R.id.widget_balance, balance)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingLaunch = PendingIntent.getActivity(context, widgetId * 10, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_root_linear_layout, pendingLaunch)
            val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            val pendingAdd = PendingIntent.getActivity(context, widgetId * 10 + 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_button, pendingAdd)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    fun updateMediumWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_medium_layout).apply {
            applyDynamicColors(context, isMediumWidget = true)

            val balance = widgetData.getString("total_balance", "...") ?: "..."
            setTextViewText(R.id.widget_medium_balance, balance)

            val chartPath = widgetData.getString("widget_chart_path", null)
            Log.d("WidgetDebug", "[KOTLIN] Ruta leída: '$chartPath'")

            if (chartPath != null && chartPath.isNotEmpty()) {
                val chartFile = File(chartPath)
                if (chartFile.exists()) {
                    // Leemos el archivo y lo decodificamos en un Bitmap.
                    // Este método es el más fiable para los widgets.
                    try {
                        val bitmap = BitmapFactory.decodeFile(chartFile.absolutePath)
                        setImageViewBitmap(R.id.widget_medium_chart, bitmap)
                        setViewVisibility(R.id.widget_medium_chart, View.VISIBLE)
                        Log.d("WidgetDebug", "[KOTLIN] ¡ÉXITO! Se estableció la imagen como Bitmap.")
                    } catch (e: Exception) {
                        // Capturamos cualquier error al procesar la imagen.
                        setViewVisibility(R.id.widget_medium_chart, View.GONE)
                        Log.e("WidgetDebug", "[KOTLIN] FALLO: Error al decodificar el Bitmap.", e)
                    }
                } else {
                    setViewVisibility(R.id.widget_medium_chart, View.GONE)
                    Log.d("WidgetDebug", "[KOTLIN] FALLO: El archivo no fue encontrado en la ruta especificada.")
                }
            } else {
                setViewVisibility(R.id.widget_medium_chart, View.GONE)
                Log.d("WidgetDebug", "[KOTLIN] FALLO: La ruta del gráfico es nula o vacía.")
            }

            // Lógica para los intents/botones
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingLaunch = PendingIntent.getActivity(context, widgetId * 10 + 2, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_medium_container, pendingLaunch)

            val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
            val pendingAdd = PendingIntent.getActivity(context, widgetId * 10 + 3, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_medium_add_button, pendingAdd)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    fun updateLargeWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.widget_large_layout)
        views.applyDynamicColors(context, isLargeWidget = true)

        val gson = Gson()
        val budgetsJson = widgetData.getString("budgets_json", "[]")
        val budgetListType = object : TypeToken<List<BudgetWidgetItem>>() {}.type
        val budgets: List<BudgetWidgetItem> = gson.fromJson(budgetsJson, budgetListType)

        val transactionsJson = widgetData.getString("recent_transactions_json", "[]")
        val transactionListType = object : TypeToken<List<TransactionWidgetItem>>() {}.type
        val transactions: List<TransactionWidgetItem> = gson.fromJson(transactionsJson, transactionListType)

        views.setViewVisibility(R.id.budget_item_1, View.GONE)
        views.setViewVisibility(R.id.budget_item_2, View.GONE)
        views.setViewVisibility(R.id.transaction_item_1, View.GONE)
        views.setViewVisibility(R.id.transaction_item_2, View.GONE)
        views.setViewVisibility(R.id.transaction_item_3, View.GONE)

        if (budgets.isEmpty()) {
            views.setTextViewText(R.id.budget_item_1_title, "No tienes presupuestos activos.")
            views.setViewVisibility(R.id.budget_item_1_progress, View.GONE)
            views.setViewVisibility(R.id.budget_item_1, View.VISIBLE)
        } else {
            budgets.getOrNull(0)?.let {
                views.setTextViewText(R.id.budget_item_1_title, "🍔 ${it.category}")
                views.setViewVisibility(R.id.budget_item_1_progress, View.VISIBLE)
                views.setProgressBar(R.id.budget_item_1_progress, 100, (it.progress * 100).toInt(), false)
                views.setViewVisibility(R.id.budget_item_1, View.VISIBLE)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val primaryColor = context.getColor(android.R.color.system_accent1_600)
                    val progressBackgroundColor = context.getColor(android.R.color.system_accent1_200)
                    views.setColorStateList(R.id.budget_item_1_progress, "setProgressTintList", ColorStateList.valueOf(primaryColor))
                    views.setColorStateList(R.id.budget_item_1_progress, "setProgressBackgroundTintList", ColorStateList.valueOf(progressBackgroundColor))
                }
            }
            budgets.getOrNull(1)?.let {
                views.setTextViewText(R.id.budget_item_2_title, "🚗 ${it.category}")
                views.setViewVisibility(R.id.budget_item_2_progress, View.VISIBLE)
                views.setProgressBar(R.id.budget_item_2_progress, 100, (it.progress * 100).toInt(), false)
                views.setViewVisibility(R.id.budget_item_2, View.VISIBLE)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    val primaryColor = context.getColor(android.R.color.system_accent1_600)
                    val progressBackgroundColor = context.getColor(android.R.color.system_accent1_200)
                    views.setColorStateList(R.id.budget_item_2_progress, "setProgressTintList", ColorStateList.valueOf(primaryColor))
                    views.setColorStateList(R.id.budget_item_2_progress, "setProgressBackgroundTintList", ColorStateList.valueOf(progressBackgroundColor))
                }
            }
        }

        val currencyFormat = NumberFormat.getCurrencyInstance(Locale("es", "ES"))
        transactions.getOrNull(0)?.let { tx ->
            val title = "${tx.category ?: "Transacción"}: ${tx.description ?: ""}"
            views.setTextViewText(R.id.transaction_item_1_title, title.trim())
            views.setTextViewText(R.id.transaction_item_1_amount, currencyFormat.format(tx.amount))
            val color = if (tx.type == "Gasto") Color.parseColor("#E53935") else Color.parseColor("#43A047")
            views.setTextColor(R.id.transaction_item_1_amount, color)
            views.setViewVisibility(R.id.transaction_item_1, View.VISIBLE)
        }
        transactions.getOrNull(1)?.let { tx ->
            val title = "${tx.category ?: "Transacción"}: ${tx.description ?: ""}"
            views.setTextViewText(R.id.transaction_item_2_title, title.trim())
            views.setTextViewText(R.id.transaction_item_2_amount, currencyFormat.format(tx.amount))
            val color = if (tx.type == "Gasto") Color.parseColor("#E53935") else Color.parseColor("#43A047")
            views.setTextColor(R.id.transaction_item_2_amount, color)
            views.setViewVisibility(R.id.transaction_item_2, View.VISIBLE)
        }
        transactions.getOrNull(2)?.let { tx ->
            val title = "${tx.category ?: "Transacción"}: ${tx.description ?: ""}"
            views.setTextViewText(R.id.transaction_item_3_title, title.trim())
            views.setTextViewText(R.id.transaction_item_3_amount, currencyFormat.format(tx.amount))
            val color = if (tx.type == "Gasto") Color.parseColor("#E53935") else Color.parseColor("#43A047")
            views.setTextColor(R.id.transaction_item_3_amount, color)
            views.setViewVisibility(R.id.transaction_item_3, View.VISIBLE)
        }

        val uniqueRequestCode = widgetId * 10
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val launchPendingIntent = PendingIntent.getActivity(context, uniqueRequestCode, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_large_container, launchPendingIntent)

        val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val addPendingIntent = PendingIntent.getActivity(context, uniqueRequestCode + 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.widget_large_add_button, addPendingIntent)

        val budgetListIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://planning_hub_screen")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val budgetListPendingIntent = PendingIntent.getActivity(context, uniqueRequestCode + 2, budgetListIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.budget_item_1, budgetListPendingIntent)
        views.setOnClickPendingIntent(R.id.budget_item_2, budgetListPendingIntent)

        val transactionListIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://transactions_screen")).apply { addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        val transactionListPendingIntent = PendingIntent.getActivity(context, uniqueRequestCode + 3, transactionListIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setOnClickPendingIntent(R.id.transaction_item_1, transactionListPendingIntent)
        views.setOnClickPendingIntent(R.id.transaction_item_2, transactionListPendingIntent)
        views.setOnClickPendingIntent(R.id.transaction_item_3, transactionListPendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun RemoteViews.applyDynamicColors(context: Context, isMediumWidget: Boolean = false, isLargeWidget: Boolean = false) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val primaryColor = context.getColor(android.R.color.system_accent1_600)
            val secondaryColor = context.getColor(android.R.color.system_accent1_100)
            val onPrimaryColor = context.getColor(android.R.color.system_neutral1_50)
            val onSecondaryColor = context.getColor(android.R.color.system_neutral1_800)
            
            when {
                isMediumWidget -> {
                    setInt(R.id.widget_medium_container, "setBackgroundColor", secondaryColor)
                    setTextColor(R.id.widget_medium_title, onSecondaryColor)
                    setTextViewTextSize(R.id.widget_medium_title, TypedValue.COMPLEX_UNIT_SP, 16f)
                    setTextColor(R.id.widget_medium_balance, onSecondaryColor)
                    setTextViewTextSize(R.id.widget_medium_balance, TypedValue.COMPLEX_UNIT_SP, 28f)
                    setInt(R.id.widget_medium_add_button, "setColorFilter", onPrimaryColor)
                    setInt(R.id.widget_medium_add_button, "setBackgroundColor", primaryColor)
                }
                isLargeWidget -> {
                    setInt(R.id.widget_large_container, "setBackgroundColor", secondaryColor)
                    setTextColor(R.id.widget_large_title, onSecondaryColor)
                    setInt(R.id.widget_large_add_button, "setColorFilter", onPrimaryColor)
                    setInt(R.id.widget_large_add_button, "setBackgroundColor", primaryColor)
                }
                else -> { // Widget pequeño
                    setInt(R.id.widget_root_linear_layout, "setBackgroundColor", secondaryColor)
                    setTextColor(R.id.widget_title, onSecondaryColor)
                    setTextColor(R.id.widget_balance, onSecondaryColor)
                    setInt(R.id.widget_button, "setColorFilter", onPrimaryColor)
                    setInt(R.id.widget_button, "setBackgroundColor", primaryColor)
                }
            }
        } else {
            val fallbackBg = Color.parseColor("#EFEFEF")
            val fallbackText = Color.BLACK
            if (isMediumWidget) {
                setInt(R.id.widget_medium_container, "setBackgroundColor", fallbackBg)
                setTextColor(R.id.widget_medium_title, fallbackText)
                setTextColor(R.id.widget_medium_balance, fallbackText)
            } else {
                setInt(R.id.widget_root_linear_layout, "setBackgroundColor", fallbackBg)
                setTextColor(R.id.widget_title, fallbackText)
                setTextColor(R.id.widget_balance, fallbackText)
            }
        }
    }
}