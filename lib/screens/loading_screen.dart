// lib/screens/loading_screen.dart
import 'package:flutter/material.dart';

// Esta pantalla ahora es un StatelessWidget "tonto".
// Su única responsabilidad es mostrar un mensaje.
class LoadingScreen extends StatelessWidget {
  // Acepta un mensaje opcional.
  final String? message;
  
  const LoadingScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            // Muestra el mensaje si se proporciona, si no, un texto por defecto.
            Text(message ?? 'Cargando...'), 
          ],
        ),
      ),
    );
  }
}