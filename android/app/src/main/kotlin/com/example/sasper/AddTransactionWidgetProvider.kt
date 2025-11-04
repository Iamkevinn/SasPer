// android/app/src/main/kotlin/com/example/sasper/AddTransactionWidgetProvider.kt
// (Asegúrate de que el 'package' coincida con tu estructura de carpetas)
package com.example.sasper // <--- ¡CAMBIA ESTO A TU PAQUETE!

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

class AddTransactionWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // 1. Crea un Intent para lanzar la app. Usamos un "deep link" con un esquema personalizado.
            val intent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("sasper://add_transaction"), // Esta es la "instrucción" para Flutter
                context,
                MainActivity::class.java // Apunta a tu actividad principal de Flutter
            )
            
            // 2. Envuelve el Intent en un PendingIntent, que es lo que el widget puede ejecutar.
            val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_IMMUTABLE)

            // 3. Obtiene la vista del widget y le asigna el evento de clic.
            val views = RemoteViews(context.packageName, R.layout.add_transaction_widget)
            views.setOnClickPendingIntent(R.id.add_widget_button, pendingIntent)

            // 4. Actualiza el widget.
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}