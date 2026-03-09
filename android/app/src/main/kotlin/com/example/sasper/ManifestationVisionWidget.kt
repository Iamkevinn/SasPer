package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class ManifestationVisionWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ManifestationVision"
        
        private const val KEY_CURRENT_INDEX = "vision_current_manifestation_index"
        private const val KEY_TOTAL_COUNT = "vision_manifestations_total_count"
        private const val KEY_CURRENT_TITLE = "vision_current_title"
        private const val KEY_CURRENT_DESCRIPTION = "vision_current_description"
        private const val KEY_CURRENT_IMAGE_URL = "vision_current_image_url"
        private const val KEY_DAILY_COUNT_PREFIX = "vision_daily_count_"
        private const val KEY_TRIGGER_ANIMATION = "trigger_visualization_animation"
        
        private fun keyFor(baseKey: String, widgetId: Int): String {
            return "${baseKey}_${widgetId}"
        }
        
        private fun getCurrentDate(): String {
            val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            return sdf.format(Date())
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
            val isInitialized = widgetPrefs.getBoolean("is_init_$appWidgetId", false)
            
            if (!isInitialized) {
                val intent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("app://manifestation_widget/initialize?widgetId=$appWidgetId")
                )
                intent.send()
                widgetPrefs.edit().putBoolean("is_init_$appWidgetId", true).apply()
            } else {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
        for (appWidgetId in appWidgetIds) {
            widgetPrefs.edit().remove("is_init_$appWidgetId").apply()
        }
    }

    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.manifestation_vision_widget)
        
        val totalCount = prefs.getInt(keyFor(KEY_TOTAL_COUNT, appWidgetId), prefs.getInt(KEY_TOTAL_COUNT, 0))
        
        // 1. Configurar botones siempre
        setupButtonActions(context, views, appWidgetId)

        // 2. Verificar si debe mostrarse la animación
        val shouldAnimate = prefs.getBoolean(keyFor(KEY_TRIGGER_ANIMATION, appWidgetId), false)
        if (shouldAnimate) {
            views.setViewVisibility(R.id.visualization_effect, View.VISIBLE)
            // Limpiamos la bandera inmediatamente para evitar repeticiones
            prefs.edit().putBoolean(keyFor(KEY_TRIGGER_ANIMATION, appWidgetId), false).apply()
        } else {
            views.setViewVisibility(R.id.visualization_effect, View.GONE)
        }
        
        if (totalCount > 0) {
            val currentIndex = prefs.getInt(keyFor(KEY_CURRENT_INDEX, appWidgetId), prefs.getInt(KEY_CURRENT_INDEX, 0))
            val title = prefs.getString(keyFor(KEY_CURRENT_TITLE, appWidgetId), "Sin manifestaciones") ?: "Sin manifestaciones"
            val description = prefs.getString(keyFor(KEY_CURRENT_DESCRIPTION, appWidgetId), "") ?: ""
            val imageUrl = prefs.getString(keyFor(KEY_CURRENT_IMAGE_URL, appWidgetId), "") ?: ""
            
            views.setTextViewText(R.id.manifestation_title, title)
            views.setTextViewText(R.id.manifestation_counter, "${currentIndex + 1} de $totalCount")
            
            if (description.isNotEmpty()) {
                views.setTextViewText(R.id.manifestation_description, description)
                views.setViewVisibility(R.id.manifestation_description, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.manifestation_description, View.GONE)
            }
            
            updateDailyCounter(context, views, appWidgetId, currentIndex)
            
            // 🔥 TRUCO ANTI-PARPADEO: No actualizamos el widget aún. Se lo pasamos a Glide.
            if (imageUrl.isNotEmpty()) {
                loadImageIntoWidget(context, appWidgetManager, appWidgetId, views, imageUrl, shouldAnimate)
            } else {
                views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                if (shouldAnimate) scheduleOverlayRemoval(context, appWidgetManager, appWidgetId)
            }
        } else {
            views.setTextViewText(R.id.manifestation_title, "Comienza a Manifestar")
            views.setTextViewText(R.id.manifestation_description, "Toca el botón '+' en la app")
            views.setTextViewText(R.id.manifestation_counter, "0/0")
            views.setImageViewResource(R.id.manifestation_image, R.drawable.empty_state_manifestation)
            views.setViewVisibility(R.id.manifestation_description, View.VISIBLE)
            views.setViewVisibility(R.id.daily_manifestation_count, View.GONE)
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            if (shouldAnimate) scheduleOverlayRemoval(context, appWidgetManager, appWidgetId)
        }
    }
    
    private fun updateDailyCounter(context: Context, views: RemoteViews, widgetId: Int, manifestationIndex: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val currentDate = getCurrentDate()
        val countKey = keyFor("${KEY_DAILY_COUNT_PREFIX}${manifestationIndex}_$currentDate", widgetId)
        val dailyCount = prefs.getInt(countKey, 0)
        
        if (dailyCount > 0) {
            val countText = if (dailyCount == 1) "✨ Has manifestado 1 vez hoy" else "✨ Has manifestado $dailyCount veces hoy"
            views.setTextViewText(R.id.daily_manifestation_count, countText)
            views.setViewVisibility(R.id.daily_manifestation_count, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.daily_manifestation_count, View.GONE)
        }
    }

    // 🔥 TRUCO DE ACTUALIZACIÓN PARCIAL
    private fun scheduleOverlayRemoval(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        Handler(Looper.getMainLooper()).postDelayed({
            // Creamos unas vistas 'vacías' solo con la instrucción de ocultar el overlay
            val partialViews = RemoteViews(context.packageName, R.layout.manifestation_vision_widget)
            partialViews.setViewVisibility(R.id.visualization_effect, View.GONE)
            
            // partiallyUpdateAppWidget NO redibuja el widget, solo aplica el cambio específico. Cero parpadeos.
            appWidgetManager.partiallyUpdateAppWidget(appWidgetId, partialViews)
        }, 1500) // 1.5 segundos es el tiempo ideal estilo iOS
    }
    
    private fun loadImageIntoWidget(
        context: Context, 
        appWidgetManager: AppWidgetManager, 
        appWidgetId: Int, 
        views: RemoteViews, 
        imagePath: String, // Ahora puede ser URL o Ruta Local
        shouldAnimate: Boolean
    ) {
        try {
            // Lógica híbrida: detectamos si es URL o archivo local
            val loadTarget: Any = if (imagePath.startsWith("http")) {
                imagePath // Si es web, Glide usa la URL directamente
            } else {
                File(imagePath) // Si es local, Glide usa el archivo
            }

            Glide.with(context.applicationContext)
                .asBitmap()
                .load(loadTarget) // 👈 Usamos el target correcto
                .override(500, 500) 
                .centerCrop()
                .into(object : CustomTarget<Bitmap>() {
                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                        views.setImageViewBitmap(R.id.manifestation_image, resource)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                        if (shouldAnimate) scheduleOverlayRemoval(context, appWidgetManager, appWidgetId)
                    }
                    override fun onLoadCleared(placeholder: Drawable?) {}
                    override fun onLoadFailed(errorDrawable: Drawable?) {
                        views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                        if (shouldAnimate) scheduleOverlayRemoval(context, appWidgetManager, appWidgetId)
                    }
                })
        } catch (e: Exception) {
            Log.e(TAG, "Error loading image: ${e.message}")
            views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            if (shouldAnimate) scheduleOverlayRemoval(context, appWidgetManager, appWidgetId)
        }
    }

    private fun setupButtonActions(context: Context, views: RemoteViews, appWidgetId: Int) {
        val nextUri = Uri.parse("app://manifestation_widget/next?widgetId=$appWidgetId")
        val nextIntent = HomeWidgetBackgroundIntent.getBroadcast(context, nextUri)
        views.setOnClickPendingIntent(R.id.btn_next, nextIntent)

        val previousUri = Uri.parse("app://manifestation_widget/previous?widgetId=$appWidgetId")
        val previousIntent = HomeWidgetBackgroundIntent.getBroadcast(context, previousUri)
        views.setOnClickPendingIntent(R.id.btn_previous, previousIntent)

        val visualizeUri = Uri.parse("app://manifestation_widget/visualize?widgetId=$appWidgetId")
        val visualizeIntent = HomeWidgetBackgroundIntent.getBroadcast(context, visualizeUri)
        views.setOnClickPendingIntent(R.id.btn_visualize, visualizeIntent)

        val openAppIntent = HomeWidgetLaunchIntent.getActivity(
            context, 
            MainActivity::class.java, 
            Uri.parse("app://manifestation_widget/open_app?widgetId=$appWidgetId")
        )
        views.setOnClickPendingIntent(R.id.btn_open_app, openAppIntent)

        val refreshUri = Uri.parse("app://manifestation_widget/refresh?widgetId=$appWidgetId")
        val refreshIntent = HomeWidgetBackgroundIntent.getBroadcast(context, refreshUri)
        views.setOnClickPendingIntent(R.id.btn_refresh, refreshIntent)
    }
}