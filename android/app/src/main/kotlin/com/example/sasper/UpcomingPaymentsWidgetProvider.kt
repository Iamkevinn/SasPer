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
    
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            // Obtener la vista del layout
            val views = RemoteViews(
                context.packageName,
                R.layout.widget_upcoming_payments_layout
            )
            
            // ========== CONFIGURACIÓN DE CLICK LISTENERS ==========
            
            // 1. Intent para abrir la app al tocar el widget completo
            // CORREGIDO: Usar widget_content que SÍ existe en el layout
            val launchAppIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
            }
            val launchAppPendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchAppIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            // Aplicar al contenedor principal que SÍ existe
            views.setOnClickPendingIntent(R.id.widget_content, launchAppPendingIntent)
            
            // 2. Intent para el botón de filtro
            val filterIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.sasper.ACTION_OPEN_PAYMENTS_FILTER"
            }
            val filterPendingIntent = PendingIntent.getActivity(
                context,
                1,
                filterIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.filter_button, filterPendingIntent)
            
            // 3. Intent para el botón de calendario
            val calendarIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.sasper.ACTION_OPEN_CALENDAR"
            }
            val calendarPendingIntent = PendingIntent.getActivity(
                context,
                2,
                calendarIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.calendar_button, calendarPendingIntent)
            
            // 4. Intent "plantilla" para los items de la lista
            val itemClickIntent = Intent(context, UpcomingPaymentsWidgetProvider::class.java).apply {
                action = "com.example.sasper.ACTION_ITEM_CLICK"
                data = Uri.parse("sasper://widget/payment/")
            }
            val itemClickPendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                itemClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setPendingIntentTemplate(R.id.lv_upcoming_payments, itemClickPendingIntent)
            
            // ========== CONFIGURACIÓN DE LA LISTA ==========
            
            // Conectar el servicio remoto para la lista
            val serviceIntent = Intent(context, UpcomingPaymentsListService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            views.setRemoteAdapter(R.id.lv_upcoming_payments, serviceIntent)
            
            // Configurar vista vacía
            views.setEmptyView(R.id.lv_upcoming_payments, R.id.empty_view)
            
            // ========== ACTUALIZAR WIDGET ==========
            
            appWidgetManager.updateAppWidget(appWidgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.lv_upcoming_payments)
        }
        
        Log.d("UpcomingPayments", "Widget actualizado correctamente")
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        
        // Manejar clicks en items de la lista
        if (intent.action == "com.example.sasper.ACTION_ITEM_CLICK") {
            val paymentId = intent.data?.lastPathSegment
            
            Log.d("UpcomingPayments", "Click en pago: $paymentId")
            
            // Abrir la app con el pago específico
            val openPaymentIntent = Intent(context, MainActivity::class.java).apply {
                action = "com.example.sasper.ACTION_OPEN_PAYMENT_DETAIL"
                putExtra("payment_id", paymentId)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            context.startActivity(openPaymentIntent)
        }
    }
    
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        Log.d("UpcomingPayments", "Widgets eliminados: ${appWidgetIds.size}")
    }
    
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        Log.d("UpcomingPayments", "Widget habilitado por primera vez")
    }
    
    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        Log.d("UpcomingPayments", "Último widget deshabilitado")
    }
}