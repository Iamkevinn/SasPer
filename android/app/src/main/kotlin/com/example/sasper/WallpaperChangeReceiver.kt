// Archivo: app/src/main/kotlin/com/example/sasper/WallpaperChangeReceiver.kt

package com.example.sasper

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log

class WallpaperChangeReceiver : BroadcastReceiver() {

    private val TAG = "WallpaperReceiver"

    override fun onReceive(context: Context, intent: Intent) {
        // Log para saber qué acción disparó el receptor
        Log.d(TAG, "Receptor activado por la acción: ${intent.action}")

        // Verificamos que la acción sea una de las que nos interesan.
        // ACTION_BOOT_COMPLETED también es útil para forzar una actualización cuando el dispositivo se reinicia.
        if (intent.action == Intent.ACTION_WALLPAPER_CHANGED ||
            intent.action == Intent.ACTION_CONFIGURATION_CHANGED ||
            intent.action == Intent.ACTION_BOOT_COMPLETED) {

            Log.d(TAG, "Acción válida detectada. Forzando actualización de todos los widgets.")
            
            // 1. Obtener el AppWidgetManager, que es el gestor de widgets del sistema.
            val appWidgetManager = AppWidgetManager.getInstance(context)

            // 2. Construir la lista de todos tus AppWidgetProvider.
            // Es crucial incluir todos los providers que has declarado en el manifiesto.
            val providers = listOf(
                SasPerWidgetProvider::class.java,
                SasPerMediumWidgetProvider::class.java,
                SasPerLargeWidgetProvider::class.java
            )

            // 3. Para cada uno de tus providers, obtenemos los IDs de los widgets que están actualmente en la pantalla.
            providers.forEach { providerClass ->
                val componentName = ComponentName(context, providerClass)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

                if (appWidgetIds.isNotEmpty()) {
                    Log.d(TAG, "Actualizando ${appWidgetIds.size} widget(s) para el provider: ${providerClass.simpleName}")
                    
                    // 4. Notificamos al AppWidgetManager que los datos para estos widgets han cambiado.
                    // Esto hará que el sistema llame al método `onUpdate` de cada provider correspondiente,
                    // lo que a su vez ejecutará tu lógica en WidgetUpdater.kt y recargará la interfaz.
                    appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetIds, android.R.id.list) // Para listas
                    
                    // También enviamos un intent de actualización explícito para estar seguros.
                    val updateIntent = Intent(context, providerClass).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                    }
                    context.sendBroadcast(updateIntent)
                }
            }
        }
    }
}