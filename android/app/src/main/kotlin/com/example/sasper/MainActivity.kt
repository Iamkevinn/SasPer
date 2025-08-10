// android/app/src/main/kotlin/com/example/sasper/MainActivity.kt
package com.example.sasper

import android.content.Intent // Importa la clase Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterFragmentActivity 
import android.os.Bundle // Importa la clase Bundle

class MainActivity: FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Inicia el servicio de escucha de widgets
        // Esto asegurará que el receptor de cambio de wallpaper esté activo
        val serviceIntent = Intent(this, WidgetUpdateService::class.java)
        startService(serviceIntent)
    }
}