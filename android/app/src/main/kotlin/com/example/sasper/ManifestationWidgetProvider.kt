package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import android.net.Uri
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import com.example.sasper.R

class ManifestationWidgetProvider : AppWidgetProvider() {

    // 1. DEFINIMOS LAS CLAVES CORRECTAS PARA ESTE WIDGET
    companion object {
        private const val TAG = "SimpleManifestWidget"
        private const val KEY_TOTAL_COUNT = "simple_manifestations_total_count"
        private const val KEY_CURRENT_INDEX = "simple_current_manifestation_index"
        private const val KEY_TITLE = "simple_current_title"
        private const val KEY_IMAGE_URL = "simple_current_image_url"
        private const val KEY_DESCRIPTION = "simple_current_description"
        private const val KEY_TRIGGER_ANIMATION = "trigger_visualization_animation"
        // ... dentro de companion object
        private const val KOTLIN_PREFS_NAME = "SimpleWidgetState"
        private const val KEY_KOTLIN_LAST_RENDER = "kotlin_last_render_timestamp"

        // Helper para usar claves específicas por widgetId
        private fun keyFor(baseKey: String, widgetId: Int): String {
            return "${baseKey}_${widgetId}"
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // Usamos SharedPreferences para rastrear los widgets inicializados
            val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
            val isInitialized = widgetPrefs.getBoolean("is_init_$appWidgetId", false)

            if (!isInitialized) {
                // Si no está inicializado, enviamos el intent a Dart
                Log.d(TAG, "Widget $appWidgetId no está inicializado. Enviando intent...")
                val intent = HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("app://simple_manifestation_widget/initialize?widgetId=$appWidgetId")
                )
                intent.send()
                
                // Marcamos el widget como inicializado para no volver a entrar aquí
                widgetPrefs.edit().putBoolean("is_init_$appWidgetId", true).apply()
            } else {
                // Si ya está inicializado, simplemente actualizamos la vista con los datos que ya tiene
                Log.d(TAG, "Widget $appWidgetId ya está inicializado. Actualizando UI.")
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    // 🔥 IMPORTANTE: Añade este método si el widget se elimina de la pantalla
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        // Limpiamos la bandera de inicialización cuando el widget es eliminado
        val widgetPrefs = context.getSharedPreferences("WidgetInitState", Context.MODE_PRIVATE)
        for (appWidgetId in appWidgetIds) {
            Log.d(TAG, "Eliminando bandera de inicialización para widget $appWidgetId")
            widgetPrefs.edit().remove("is_init_$appWidgetId").apply()
        }
    }

    // 2. REEMPLAZAMOS EL MÉTODO updateAppWidget CON LÓGICA REAL
    private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val views = RemoteViews(context.packageName, R.layout.manifestation_widget_layout)

        // Leemos los datos directamente. Si no existen, los valores por defecto se encargarán.
        val totalCount = prefs.getInt(keyFor(KEY_TOTAL_COUNT, appWidgetId), 0)
        Log.d(TAG, "Actualizando Widget $appWidgetId: totalCount=$totalCount")

        if (totalCount > 0) {
            val currentIndex = prefs.getInt(keyFor(KEY_CURRENT_INDEX, appWidgetId), 0)
            val title = prefs.getString(keyFor(KEY_TITLE, appWidgetId), "Cargar...") ?: "Cargar..."
            val description = prefs.getString(keyFor(KEY_DESCRIPTION, appWidgetId), "") ?: ""
            val imageUrl = prefs.getString(keyFor(KEY_IMAGE_URL, appWidgetId), "") ?: ""
            
            views.setTextViewText(R.id.widget_manifestation_title, title)
            views.setTextViewText(R.id.widget_manifestation_description, description)
            
            views.setViewVisibility(R.id.widget_manifestation_description, if (description.isNotEmpty()) View.VISIBLE else View.GONE)
            
            if (imageUrl.isNotEmpty()) {
                loadImageIntoWidget(context, appWidgetManager, appWidgetId, views, imageUrl)
            } else {
                views.setImageViewResource(R.id.widget_manifestation_image, R.drawable.placeholder_manifestation)
            }
        } else {
            views.setTextViewText(R.id.widget_manifestation_title, "Sin Manifestaciones")
            views.setTextViewText(R.id.widget_manifestation_description, "Añade una desde la app")
            views.setImageViewResource(R.id.widget_manifestation_image, R.drawable.empty_state_manifestation)
        }

        setupButtonActions(context, views, appWidgetId)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    // 3. AGREGAMOS EL MANEJO DE BOTONES (YA LO TENÍAS, PERO ASEGURAMOS QUE ESTÉ BIEN)
    private fun setupButtonActions(context: Context, views: RemoteViews, appWidgetId: Int) {
        // OJO: El host de la URI debe coincidir con el que usas en el router de Dart.
        // En tu `simple_manifestation_widget_service` no tienes un host definido,
        // pero en el router general (`home_widget_callback_handler`) sí lo tienes.
        // Vamos a usar 'manifestation_widget' como parece ser tu intención.
        val host = "simple_manifestation_widget"

        val nextUri = Uri.parse("app://$host/next?widgetId=$appWidgetId")
        val nextIntent = HomeWidgetBackgroundIntent.getBroadcast(context, nextUri)
        views.setOnClickPendingIntent(R.id.widget_next_button, nextIntent) // Reemplaza con el ID de tu botón

        val previousUri = Uri.parse("app://$host/previous?widgetId=$appWidgetId")
        val previousIntent = HomeWidgetBackgroundIntent.getBroadcast(context, previousUri)
        views.setOnClickPendingIntent(R.id.widget_prev_button, previousIntent) // Reemplaza con el ID de tu botón

        val visualizeUri = Uri.parse("app://$host/visualize?widgetId=$appWidgetId")
        val visualizeIntent = HomeWidgetBackgroundIntent.getBroadcast(context, visualizeUri)
        views.setOnClickPendingIntent(R.id.widget_manifestation_image, visualizeIntent) // Reemplaza con el ID de tu imagen
    }

    // 4. AGREGAMOS UN HELPER PARA CARGAR IMÁGENES (COPIADO DE TU OTRO WIDGET)
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
                        views.setImageViewBitmap(R.id.widget_manifestation_image, resource) // Reemplaza con el ID de tu imagen
                        appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                    override fun onLoadCleared(placeholder: Drawable?) {}
                    override fun onLoadFailed(errorDrawable: Drawable?) {
                         views.setImageViewResource(R.id.widget_manifestation_image, R.drawable.placeholder_manifestation) // Reemplaza
                         appWidgetManager.updateAppWidget(appWidgetId, views)
                    }
                })
        } catch (e: Exception) {
            views.setImageViewResource(R.id.widget_manifestation_image, R.drawable.placeholder_manifestation) // Reemplaza
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        Log.d(TAG, "onReceive action=${intent.action} extras=${intent.extras} widgetId=${intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)}")
    }
}