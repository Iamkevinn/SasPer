// android/app/src/main/kotlin/com/example/sasper/UpcomingPaymentsWidgetProvider.kt
package com.example.sasper

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import android.net.Uri
import android.app.PendingIntent
import android.util.Log     

class UpcomingPaymentsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            // Simplemente obtenemos la vista. El estilo ya está en el XML.
            val views = RemoteViews(context.packageName, R.layout.widget_upcoming_payments_layout)

            // ========== INICIO DE LA CORRECCIÓN DE ERRORES ==========

            // 1. Intent para abrir la app al tocar el fondo/título del widget.
            // AHORA (Correcto): Creamos un Intent explícito para lanzar nuestra MainActivity.
            val launchAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val launchAppPendingIntent = PendingIntent.getActivity(
                context,
                0, // requestCode, 0 es suficiente aquí.
                launchAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_background, launchAppPendingIntent)


            // 2. Intent "plantilla" para los items de la lista.
            val itemClickIntent = Intent(context, UpcomingPaymentsWidgetProvider::class.java).apply {
                action = "com.example.sasper.ACTION_ITEM_CLICK"
                data = Uri.parse("sasper://widget/item/")
            }
            
            // AHORA (Correcto): Corregimos el error de tipeo 'Pendingiente' a 'PendingIntent'.
            val itemClickPendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                itemClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.lv_upcoming_payments, itemClickPendingIntent)
            
            // ========== FIN DE LA CORRECCIÓN DE ERRORES ==========
            // Conectamos el servicio para la lista.
            val intent = Intent(context, UpcomingPaymentsListService::class.java)
            views.setRemoteAdapter(R.id.lv_upcoming_payments, intent)
            views.setEmptyView(R.id.lv_upcoming_payments, R.id.empty_view)

            // Actualizamos el widget.
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.lv_upcoming_payments)
        }
        Log.d("WidgetBypass", "onUpdate para Upcomingpaymentswidgetprovider fue llamado, pero se omitió el trabajo pesado.")
    }
}