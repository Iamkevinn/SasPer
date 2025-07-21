// lib/screens/auth_gate.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'loading_screen.dart'; // Tu pantalla de carga
import 'main_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<void>? _initializationFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Usamos tu LoadingScreen sin parámetros
          return const LoadingScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          _initializationFuture ??= _initializeUserServices();

          return FutureBuilder<void>(
            future: _initializationFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.done) {
                return const MainScreen();
              } else {
                // Mientras se inicializa, mostramos la pantalla de carga.
                return const LoadingScreen();
              }
            },
          );
        } else {
          _initializationFuture = null;
          return const LoginScreen();
        }
      },
    );
  }

  Future<void> _initializeUserServices() async {
    if (kDebugMode) {
      print("✅ Usuario autenticado. Orquestando inicialización de servicios...");
    }
    try {
      await Future.wait([
        NotificationService.instance.initialize(),
      ]);
      if (kDebugMode) {
        print("✅ Todos los servicios de usuario inicializados exitosamente.");
      }
    } catch (e) {
      if (kDebugMode) {
        print("🚨 Error fatal durante la inicialización de servicios: $e");
      }
    }
  }
}