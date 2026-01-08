// RUTA: android/app/src/main/kotlin/com/example/sasper/AffirmationFocusWidget.kt
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import com.example.sasper.R

class AffirmationFocusWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "AffirmationWidget"

        private const val KOTLIN_PREFS_NAME = "AffirmationFocusWidgetState"
        private const val KEY_DART_LAST_UPDATE = "affirmation_last_update_timestamp" 
        private const val KEY_KOTLIN_LAST_RENDER = "kotlin_last_render_timestamp"

        private const val KEY_CURRENT_INDEX = "affirmation_current_index"
        private const val KEY_TOTAL_COUNT = "affirmation_total_count"
        private const val KEY_CURRENT_AFFIRMATION = "affirmation_current_text"
        private const val KEY_AFFIRMATION_TYPE_NAME = "affirmation_type_name"
        private const val KEY_AFFIRMATION_TYPE_ICON = "affirmation_type_icon"
        private const val KEY_WEEKLY_FOCUS = "affirmation_weekly_focus_count"
        private const val KEY_TRIGGER_ANIMATION = "affirmation_trigger_focus_animation"
        private const val KEY_THEME_GRADIENT_START = "affirmation_theme_gradient_start"
        private const val KEY_THEME_TEXT_COLOR = "affirmation_theme_text_color"
        
        // 🔑 NUEVA FUNCIÓN: Genera la clave con sufijo de widgetId si existe
        private fun keyFor(baseKey: String, widgetId: Int): String {
            return "${baseKey}_${widgetId}"
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
            val isInitialized = widgetPrefs.getBoolean("is_init_$appWidgetId", false)

            if (!isInitialized) {
                Log.d(TAG, "Widget $appWidgetId no está inicializado. Enviando intent...")
                val initUri = Uri.parse("app://affirmation_widget/initialize?widgetId=$appWidgetId")
                HomeWidgetBackgroundIntent.getBroadcast(context, initUri).send()
                widgetPrefs.edit().putBoolean("is_init_$appWidgetId", true).apply()
            } else {
                Log.d(TAG, "Widget $appWidgetId ya está inicializado. Actualizando UI.")
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
        for (appWidgetId in appWidgetIds) {
            Log.d(TAG, "Eliminando bandera de inicialización para widget $appWidgetId")
            widgetPrefs.edit().remove("is_init_$appWidgetId").apply()
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.affirmation_focus_widget)
        
        val totalCount = prefs.getInt(keyFor(KEY_TOTAL_COUNT, appWidgetId), 0)
        if (totalCount == 0) {
            val initUri = Uri.parse("app://affirmation_widget/initialize?widgetId=$appWidgetId")
            HomeWidgetBackgroundIntent.getBroadcast(context, initUri).send()
            Log.d(TAG, "Enviando inicialización para widget $appWidgetId")
            return
        }
        

        // 🔑 CAMBIO CLAVE: Primero intentar leer con sufijo, luego sin sufijo
        
        val gradientStart = prefs.getString(keyFor(KEY_THEME_GRADIENT_START, appWidgetId), 
            prefs.getString(KEY_THEME_GRADIENT_START, "#4A90E2")) ?: "#4A90E2"
        
        val textColor = prefs.getString(keyFor(KEY_THEME_TEXT_COLOR, appWidgetId), 
            prefs.getString(KEY_THEME_TEXT_COLOR, "#FFFFFF")) ?: "#FFFFFF"

        Log.d(TAG, "Widget $appWidgetId actualizado: totalCount=$totalCount")

        if (totalCount > 0) {
            val currentIndex = prefs.getInt(keyFor(KEY_CURRENT_INDEX, appWidgetId), 
                prefs.getInt(KEY_CURRENT_INDEX, 0))
            
            val affirmationText = prefs.getString(keyFor(KEY_CURRENT_AFFIRMATION, appWidgetId), 
                prefs.getString(KEY_CURRENT_AFFIRMATION, "Crea tu primera manifestación")) 
                ?: "Crea tu primera manifestación"
            
            val affirmationType = prefs.getString(keyFor(KEY_AFFIRMATION_TYPE_NAME, appWidgetId), 
                prefs.getString(KEY_AFFIRMATION_TYPE_NAME, "Gratitud")) ?: "Gratitud"
            
            val affirmationIcon = prefs.getString(keyFor(KEY_AFFIRMATION_TYPE_ICON, appWidgetId), 
                prefs.getString(KEY_AFFIRMATION_TYPE_ICON, "🙏")) ?: "🙏"
            
            val weeklyFocus = prefs.getInt(keyFor(KEY_WEEKLY_FOCUS, appWidgetId), 
                prefs.getInt(KEY_WEEKLY_FOCUS, 0))
            
            val triggerAnimation = prefs.getBoolean(keyFor(KEY_TRIGGER_ANIMATION, appWidgetId), 
                prefs.getBoolean(KEY_TRIGGER_ANIMATION, false))

            views.setTextViewText(R.id.affirmation_text, affirmationText)
            views.setTextColor(R.id.affirmation_text, Color.parseColor(textColor))

            views.setTextViewText(R.id.affirmation_type_label, "$affirmationIcon $affirmationType")
            views.setTextColor(R.id.affirmation_type_label, Color.parseColor(textColor))

            views.setTextViewText(R.id.manifestation_counter, "${currentIndex + 1} de $totalCount")
            views.setTextColor(R.id.manifestation_counter, Color.parseColor(textColor))

            views.setTextViewText(R.id.weekly_focus_count, "Esta semana: $weeklyFocus veces")
            views.setTextColor(R.id.weekly_focus_count, Color.parseColor(textColor))

            if (triggerAnimation) {
                views.setViewVisibility(R.id.focus_animation_overlay, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.focus_animation_overlay, android.view.View.GONE)
            }
        } else {
            views.setTextViewText(R.id.affirmation_text, "Crea tu primera manifestación en la app")
            views.setTextViewText(R.id.affirmation_type_label, "✨ Comienza")
            views.setTextViewText(R.id.manifestation_counter, "0 manifestaciones")
            views.setTextViewText(R.id.weekly_focus_count, "")
        }

        applyGradientBackground(views, gradientStart)
        setupButtonActions(context, views, appWidgetId) // Esto conectará los botones.
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    private fun applyGradientBackground(views: RemoteViews, startColor: String) {
        try {
            val color = Color.parseColor(startColor)
            views.setInt(R.id.widget_background, "setBackgroundColor", color)
        } catch (e: Exception) {
            views.setInt(R.id.widget_background, "setBackgroundColor", Color.parseColor("#4A90E2"))
        }
    }

    private fun setupButtonActions(context: Context, views: RemoteViews, appWidgetId: Int) {
        val previousUri = Uri.parse("app://affirmation_widget/previous?widgetId=$appWidgetId")
        val previousIntent = HomeWidgetBackgroundIntent.getBroadcast(context, previousUri)
        views.setOnClickPendingIntent(R.id.btn_previous, previousIntent)

        val nextUri = Uri.parse("app://affirmation_widget/next?widgetId=$appWidgetId")
        val nextIntent = HomeWidgetBackgroundIntent.getBroadcast(context, nextUri)
        views.setOnClickPendingIntent(R.id.btn_next, nextIntent)

        val rotateUri = Uri.parse("app://affirmation_widget/rotate?widgetId=$appWidgetId")
        val rotateIntent = HomeWidgetBackgroundIntent.getBroadcast(context, rotateUri)
        views.setOnClickPendingIntent(R.id.btn_rotate_affirmation, rotateIntent)

        val focusUri = Uri.parse("app://affirmation_widget/focus?widgetId=$appWidgetId")
        val focusIntent = HomeWidgetBackgroundIntent.getBroadcast(context, focusUri)
        views.setOnClickPendingIntent(R.id.affirmation_text_container, focusIntent)

        val openAppIntent = HomeWidgetLaunchIntent.getActivity(
            context, 
            MainActivity::class.java, 
            Uri.parse("app://affirmation_widget/open_app?widgetId=$appWidgetId")
        )
        views.setOnClickPendingIntent(R.id.btn_open_app, openAppIntent)
    }
}