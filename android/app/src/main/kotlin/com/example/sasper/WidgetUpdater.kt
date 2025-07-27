package com.example.sasper

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.util.Log
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import java.io.File

object WidgetUpdater {

    fun updateSmallWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val views = RemoteViews(context.packageName, R.layout.home_widget_layout).apply {
            // --- CORRECCIÓN EN LA LLAMADA ---
            // 'this' es implícito, solo pasamos los otros parámetros.
            applyDynamicColors(context)

            // Lógica de datos (sin cambios)
            val balance = widgetData.getString("total_balance", "€0,00") ?: "€0,00"
            setTextViewText(R.id.widget_balance, balance)

            // Lógica de clics (sin cambios)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingLaunch = PendingIntent.getActivity(context, 0, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_root_linear_layout, pendingLaunch)

            val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val pendingAdd = PendingIntent.getActivity(context, 1, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_button, pendingAdd)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    fun updateMediumWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        Log.d("WidgetUpdater", "Starting update for Medium Widget ID: $widgetId") // Log de inicio
        val views = RemoteViews(context.packageName, R.layout.widget_medium_layout).apply {
            // --- CORRECCIÓN EN LA LLAMADA ---
            // 'this' es implícito, solo pasamos los otros parámetros.
            applyDynamicColors(context, isMediumWidget = true)

            // Lógica de datos (sin cambios)
            val balance = widgetData.getString("total_balance", "€0,00") ?: "€0,00"
            setTextViewText(R.id.widget_medium_balance, balance)
            Log.d("WidgetUpdater", "Balance updated to: $balance") // Log de datos

            // --- LÓGICA DE GRÁFICO CON DEPURACIÓN ---
            val chartPath = widgetData.getString("widget_chart_path", null)
            if (chartPath != null) {
                Log.d("WidgetUpdater", "Chart path found: $chartPath") // Log de ruta
                val chartFile = File(chartPath)
                if (chartFile.exists()) {
                    Log.d("WidgetUpdater", "Chart file exists. Decoding bitmap...") // Log de existencia
                    try {
                        val bitmap = BitmapFactory.decodeFile(chartFile.absolutePath)
                        setImageViewBitmap(R.id.widget_medium_chart, bitmap)
                        setViewVisibility(R.id.widget_medium_chart, View.VISIBLE)
                        Log.d("WidgetUpdater", "✅ Bitmap set successfully!") // Log de éxito
                    } catch (e: Exception) {
                        Log.e("WidgetUpdater", "🔥 Error decoding or setting bitmap", e) // Log de error
                        setViewVisibility(R.id.widget_medium_chart, View.GONE)
                    }
                } else {
                    Log.w("WidgetUpdater", "⚠️ Chart file does not exist at path.") // Log de advertencia
                    setViewVisibility(R.id.widget_medium_chart, View.GONE)
                }
            } else {
                Log.d("WidgetUpdater", "No chart path provided. Hiding chart view.") // Log de ruta nula
                setViewVisibility(R.id.widget_medium_chart, View.GONE)
            }
            // --- FIN DE LA LÓGICA DE GRÁFICO ---
            
            // Lógica de clics (sin cambios)
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pendingLaunch = PendingIntent.getActivity(context, 2, launchIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_medium_container, pendingLaunch)

            val addIntent = Intent(Intent.ACTION_VIEW, Uri.parse("sasper://add_transaction")).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            val pendingAdd = PendingIntent.getActivity(context, 3, addIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            setOnClickPendingIntent(R.id.widget_medium_add_button, pendingAdd)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    // La definición de la función de extensión se queda igual
    private fun RemoteViews.applyDynamicColors(context: Context, isMediumWidget: Boolean = false) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val primaryColor = context.getColor(android.R.color.system_accent1_600)
            val secondaryColor = context.getColor(android.R.color.system_accent1_100)
            val onPrimaryColor = context.getColor(android.R.color.system_neutral1_50)
            val onSecondaryColor = context.getColor(android.R.color.system_neutral1_800)

            if (isMediumWidget) {
                // --- ESTILO EXPLÍCITO PARA WIDGET MEDIANO ---
                // Fondo
                setInt(R.id.widget_medium_container, "setBackgroundColor", secondaryColor)
                
                // Texto "Saldo Total"
                setTextColor(R.id.widget_medium_title, onSecondaryColor)
                setTextViewTextSize(R.id.widget_medium_title, TypedValue.COMPLEX_UNIT_SP, 16f)

                // Texto del Saldo (grande y en negrita)
                setTextColor(R.id.widget_medium_balance, onSecondaryColor)
                setTextViewTextSize(R.id.widget_medium_balance, TypedValue.COMPLEX_UNIT_SP, 28f)
                // No hay un método directo para "setBold", pero podemos simularlo con un shader.
                // Por ahora, el tamaño grande será suficiente.

                // Botón
                setInt(R.id.widget_medium_add_button, "setColorFilter", onPrimaryColor) // Color del icono '+'
                // Aquí usamos el color primario (oscuro) para el fondo del botón, creando contraste
                setInt(R.id.widget_medium_add_button, "setBackgroundColor", primaryColor)
                
            } else {
                // Estilo para el widget pequeño (ya funciona, lo mantenemos)
                setInt(R.id.widget_root_linear_layout, "setBackgroundColor", secondaryColor)
                setTextColor(R.id.widget_title, onSecondaryColor)
                setTextColor(R.id.widget_balance, onSecondaryColor)
                setInt(R.id.widget_button, "setColorFilter", onPrimaryColor)
                setInt(R.id.widget_button, "setBackgroundColor", primaryColor)
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