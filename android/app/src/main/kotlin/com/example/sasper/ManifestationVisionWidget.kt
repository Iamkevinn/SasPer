// RUTA: android/app/src/main/kotlin/com/example/sasper/ManifestationVisionWidget.kt
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.Log
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import com.example.sasper.R

class ManifestationVisionWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ManifestationVision"
        
        private const val KOTLIN_PREFS_NAME = "ManifestationVisionState"
        private const val KEY_DART_LAST_UPDATE = "vision_last_update_timestamp" // Se queda con 'vision_'
        private const val KEY_KOTLIN_LAST_RENDER = "kotlin_last_render_timestamp"
        
        // Claves de datos (se quedan como estaban, son únicas para este widget)
        private const val KEY_CURRENT_INDEX = "vision_current_manifestation_index"
        private const val KEY_TOTAL_COUNT = "vision_manifestations_total_count"
        private const val KEY_CURRENT_TITLE = "vision_current_title"
        private const val KEY_CURRENT_DESCRIPTION = "vision_current_description"
        private const val KEY_CURRENT_IMAGE_URL = "vision_current_image_url"
        //private const val KEY_TRIGGER_ANIMATION = "vision_trigger_visualization_animation"
        
        // 🔑 NUEVA FUNCIÓN
        private fun keyFor(baseKey: String, widgetId: Int): String {
            return "${baseKey}_${widgetId}"
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
            val isInitialized = widgetPrefs.getBoolean("is_init_$appWidgetId", false)

            if (!isInitialized) {
                Log.d(TAG, "Widget $appWidgetId no está inicializado. Enviando intent...")
                val intent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("app://manifestation_widget/initialize?widgetId=$appWidgetId")
                )
                intent.send()
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
        val views = RemoteViews(context.packageName, R.layout.manifestation_vision_widget)
        
        
        // 🔑 LEER CON SUFIJO PRIMERO, LUEGO SIN SUFIJO (FALLBACK)
        val totalCount = prefs.getInt(keyFor(KEY_TOTAL_COUNT, appWidgetId), 
            prefs.getInt(KEY_TOTAL_COUNT, 0))
        
        Log.d(TAG, "Widget $appWidgetId actualizado: totalCount=$totalCount")
        
        if (totalCount > 0) {
            val currentIndex = prefs.getInt(keyFor(KEY_CURRENT_INDEX, appWidgetId), 
                prefs.getInt(KEY_CURRENT_INDEX, 0))
            
            val title = prefs.getString(keyFor(KEY_CURRENT_TITLE, appWidgetId), 
                prefs.getString(KEY_CURRENT_TITLE, "Sin manifestaciones")) ?: "Sin manifestaciones"
            
            val description = prefs.getString(keyFor(KEY_CURRENT_DESCRIPTION, appWidgetId), 
                prefs.getString(KEY_CURRENT_DESCRIPTION, "")) ?: ""
            
            val imageUrl = prefs.getString(keyFor(KEY_CURRENT_IMAGE_URL, appWidgetId), 
                prefs.getString(KEY_CURRENT_IMAGE_URL, "")) ?: ""
            
            //val triggerAnimation = prefs.getBoolean(keyFor(KEY_TRIGGER_ANIMATION, appWidgetId), 
              //  prefs.getBoolean(KEY_TRIGGER_ANIMATION, false))

            views.setTextViewText(R.id.manifestation_title, title)
            views.setTextViewText(R.id.manifestation_counter, "${currentIndex + 1} de $totalCount")
            
            if (description.isNotEmpty()) {
                views.setTextViewText(R.id.manifestation_description, description)
                views.setViewVisibility(R.id.manifestation_description, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.manifestation_description, android.view.View.GONE)
            }

            if (imageUrl.isNotEmpty()) {
                loadImageIntoWidget(context, appWidgetManager, appWidgetId, views, imageUrl)
            } else {
                views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
            }

            //if (triggerAnimation) {
              //  views.setViewVisibility(R.id.visualization_effect, android.view.View.VISIBLE)
            //} else {
              //  views.setViewVisibility(R.id.visualization_effect, android.view.View.GONE)
            //}
        } else {
            views.setTextViewText(R.id.manifestation_title, "Comienza a Manifestar")
            views.setTextViewText(R.id.manifestation_description, "Crea tu primera manifestación en la app")
            views.setTextViewText(R.id.manifestation_counter, "0 manifestaciones")
            views.setImageViewResource(R.id.manifestation_image, R.drawable.empty_state_manifestation)
            views.setViewVisibility(R.id.manifestation_description, android.view.View.VISIBLE)
        }

        setupButtonActions(context, views, appWidgetId)
        appWidgetManager.updateAppWidget(appWidgetId, views)
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
    }

    private fun loadImageIntoWidget(
        context: Context, 
        appWidgetManager: AppWidgetManager, 
        appWidgetId: Int, 
        views: RemoteViews, 
        imageUrl: String
    ) {
        try {
            Glide.with(context)
                .asBitmap()
                .load(imageUrl)
                .centerCrop()
                .into(object : CustomTarget<Bitmap>() {
                    override fun onResourceReady(resource: Bitmap, transition: Transition<in Bitmap>?) {
                        views.setImageViewBitmap(R.id.manifestation_image, resource)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }

                    override fun onLoadCleared(placeholder: Drawable?) {}

                    override fun onLoadFailed(errorDrawable: Drawable?) {
                        views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                })
        } catch (e: Exception) {
            views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
        }
    }
}