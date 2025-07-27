package com.example.sasper

import android.content.Intent
import android.widget.RemoteViewsService

class WidgetListService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        // Esta fábrica se reutiliza para ambas listas.
        // El 'intent' nos dirá qué tipo de datos debe cargar (presupuestos o transacciones).
        return WidgetListFactory(this.applicationContext, intent)
    }
}