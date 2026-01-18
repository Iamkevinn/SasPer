// RUTA: android/app/src/main/kotlin/com/example/sasper/ManifestationVisionWidget.kt
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
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.CustomTarget
import com.bumptech.glide.request.transition.Transition
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import com.example.sasper.R
import java.text.SimpleDateFormat
import java.util.*

class ManifestationVisionWidget : AppWidgetProvider() {
    companion object {
        private const val TAG = "ManifestationVision"
        
        // Claves de datos
        private const val KEY_CURRENT_INDEX = "vision_current_manifestation_index"
        private const val KEY_TOTAL_COUNT = "vision_manifestations_total_count"
        private const val KEY_CURRENT_TITLE = "vision_current_title"
        private const val KEY_CURRENT_DESCRIPTION = "vision_current_description"
        private const val KEY_CURRENT_IMAGE_URL = "vision_current_image_url"
        
        // 🆕 Claves para el contador diario
        private const val KEY_DAILY_COUNT_PREFIX = "vision_daily_count_"
        private const val KEY_LAST_COUNT_DATE = "vision_last_count_date"
        private const val KEY_TRIGGER_ANIMATION = "vision_trigger_animation"
        
        private fun keyFor(baseKey: String, widgetId: Int): String {
            return "${baseKey}_${widgetId}"
        }
        
        // Obtener la fecha actual en formato "yyyy-MM-dd"
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
            
            views.setTextViewText(R.id.manifestation_title, title)
            views.setTextViewText(R.id.manifestation_counter, "${currentIndex + 1} de $totalCount")
            
            if (description.isNotEmpty()) {
                views.setTextViewText(R.id.manifestation_description, description)
                views.setViewVisibility(R.id.manifestation_description, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.manifestation_description, android.view.View.GONE)
            }
            
            // 🆕 Actualizar contador diario
            updateDailyCounter(context, views, appWidgetId, currentIndex)
            
            if (imageUrl.isNotEmpty()) {
                loadImageIntoWidget(context, appWidgetManager, appWidgetId, views, imageUrl)
            } else {
                views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
            }
            
            // 🆕 Verificar y mostrar animación
            checkAndShowAnimation(context, appWidgetManager, appWidgetId, views)
            
        } else {
            views.setTextViewText(R.id.manifestation_title, "Comienza a Manifestar")
            views.setTextViewText(R.id.manifestation_description, "Crea tu primera manifestación en la app")
            views.setTextViewText(R.id.manifestation_counter, "0 manifestaciones")
            views.setImageViewResource(R.id.manifestation_image, R.drawable.empty_state_manifestation)
            views.setViewVisibility(R.id.manifestation_description, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.daily_manifestation_count, android.view.View.GONE)
        }
        
        setupButtonActions(context, views, appWidgetId)
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    // 🆕 Función para actualizar el contador diario
    private fun updateDailyCounter(context: Context, views: RemoteViews, widgetId: Int, manifestationIndex: Int) {
        val prefs = HomeWidgetPlugin.getData(context)
        val currentDate = getCurrentDate()
        
        // Construir clave única: manifestación + fecha + widget
        val countKey = keyFor("${KEY_DAILY_COUNT_PREFIX}${manifestationIndex}_$currentDate", widgetId)
        val dailyCount = prefs.getInt(countKey, 0)
        
        Log.d(TAG, "📊 Contador diario para widget $widgetId, manifestación $manifestationIndex: $dailyCount")
        
        if (dailyCount > 0) {
            val countText = when (dailyCount) {
                1 -> "✨ Has manifestado 1 vez hoy"
                else -> "✨ Has manifestado $dailyCount veces hoy"
            }
            views.setTextViewText(R.id.daily_manifestation_count, countText)
            views.setViewVisibility(R.id.daily_manifestation_count, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.daily_manifestation_count, android.view.View.GONE)
        }
    }
    
    // 🆕 Función para verificar y mostrar animación
    private fun checkAndShowAnimation(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        views: RemoteViews
    ) {
        val prefs = HomeWidgetPlugin.getData(context)
        val shouldAnimate = prefs.getBoolean(keyFor(KEY_TRIGGER_ANIMATION, appWidgetId), false)
        
        if (shouldAnimate) {
            Log.d(TAG, "✨ Mostrando mensaje de éxito limpio en widget $appWidgetId")
            
            // 1. Mostrar el overlay inmediatamente
            views.setViewVisibility(R.id.visualization_effect, android.view.View.VISIBLE)
            
            // 2. IMPORTANTE: Apagamos la bandera en SharedPrefs INMEDIATAMENTE
            // Esto evita que si el sistema redibuja el widget por otra razón, 
            // la animación se reinicie o parpadee.
            prefs.edit().putBoolean(keyFor(KEY_TRIGGER_ANIMATION, appWidgetId), false).apply()
            
            // 3. Actualizamos el widget para que se vea el mensaje
            appWidgetManager.updateAppWidget(appWidgetId, views)
            
            // 4. Programamos la desaparición (2 segundos para leer bien el mensaje)
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    // Volvemos a cargar las vistas base para asegurarnos de no tener referencias viejas
                    val newViews = RemoteViews(context.packageName, R.layout.manifestation_vision_widget)
                    
                    // Restauramos el estado visual (título, imagen, contadores)
                    // Esto es vital para que al ocultar el overlay, lo de abajo no esté vacío
                    val totalCount = prefs.getInt(keyFor(KEY_TOTAL_COUNT, appWidgetId), 0)
                    if (totalCount > 0) {
                        val currentIndex = prefs.getInt(keyFor(KEY_CURRENT_INDEX, appWidgetId), 0)
                        val title = prefs.getString(keyFor(KEY_CURRENT_TITLE, appWidgetId), "") ?: ""
                        val imageUrl = prefs.getString(keyFor(KEY_CURRENT_IMAGE_URL, appWidgetId), "") ?: ""
                        
                        newViews.setTextViewText(R.id.manifestation_title, title)
                        newViews.setTextViewText(R.id.manifestation_counter, "${currentIndex + 1} de $totalCount")
                        
                        // Cargamos imagen de nuevo (Glide puede usar caché, así que es rápido)
                         // Nota: Si usas Glide aquí asegúrate de usar sync o simplemente dejar la imagen anterior si no cambió
                        // Para simplificar y evitar parpadeo de imagen, a veces es mejor solo ocultar el overlay
                        // en el objeto 'views' original si la referencia es válida, pero en AppWidget 
                        // es mejor crear un nuevo RemoteViews solo con la instrucción de ocultar.
                    }

                    // OCULTAR EL OVERLAY
                    newViews.setViewVisibility(R.id.visualization_effect, android.view.View.GONE)
                    
                    // Aquí volvemos a llamar a updateAppWidget para "limpiar" la pantalla
                    // Usamos partiallyUpdateAppWidget si es posible para ser más eficientes, 
                    // pero updateAppWidget es más seguro para quitar el overlay
                    appWidgetManager.updateAppWidget(appWidgetId, newViews)
                    
                    // Disparamos una actualización completa "silenciosa" para asegurar que la imagen de fondo esté bien
                    // (Opcional, pero ayuda si la imagen desaparece)
                    val intent = Intent(context, ManifestationVisionWidget::class.java)
                    intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(appWidgetId))
                    context.sendBroadcast(intent)

                } catch (e: Exception) {
                    Log.e(TAG, "Error ocultando animación: ${e.message}")
                }
            }, 2500) // 2.5 segundos: Tiempo suficiente para leer y sentir el impacto
        } else {
            // Estado normal: Asegurar que esté oculto
            views.setViewVisibility(R.id.visualization_effect, android.view.View.GONE)
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
                // 👇 AGREGA ESTA LÍNEA: Limita el tamaño de la imagen
                // Los widgets no necesitan resolución 4K. 500x500 es suficiente.
                .override(500, 500) 
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
            Log.e(TAG, "Error loading image: ${e.message}") // Agrega log de error
            views.setImageViewResource(R.id.manifestation_image, R.drawable.placeholder_manifestation)
            appWidgetManager.updateAppWidget(appWidgetId, views) // Asegura actualización si falla
        }
    }
}