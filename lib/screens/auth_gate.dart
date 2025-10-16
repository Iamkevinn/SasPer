import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/screens/biometric_gate.dart'; 

// Pantallas
import 'loading_screen.dart';
import 'login_screen.dart';

/// Un widget "guardián" que gestiona el estado de autenticación de la aplicación.
///
/// Escucha los cambios en la sesión de Supabase y muestra la pantalla correspondiente:
/// - `LoginScreen` si no hay sesión.
/// - `LoadingScreen` mientras se autentica o se inicializan los servicios del usuario.
/// - `MainScreen` una vez que el usuario está autenticado y los servicios listos.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Almacena el Future de la inicialización para evitar que se ejecute múltiples veces.
  /// Esto se conoce como "memoización".
  Future<void>? _initializationFuture;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Muestra una pantalla de carga mientras se establece la conexión inicial con Supabase.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final session = snapshot.data?.session;

        // Si hay una sesión activa, procedemos a la inicialización de servicios.
        if (session != null) {
          // Si el future no ha sido creado aún, lo creamos.
          // Esto evita que _initializeUserServices se llame en cada rebuild del widget.
          _initializationFuture ??= _initializeUserServices();

          // Usamos un FutureBuilder para esperar a que los servicios terminen.
          return FutureBuilder<void>(
            future: _initializationFuture,
            builder: (context, futureSnapshot) {
              // Una vez que los servicios están listos, mostramos la pantalla principal.
              if (futureSnapshot.connectionState == ConnectionState.done) {
                // --- 2. ¡CAMBIO CLAVE AQUÍ! ---
                // En lugar de ir a MainScreen, vamos a nuestro BiometricGate.
                return const BiometricGate(); 
              } else {
                // Mientras se inicializan, seguimos mostrando la pantalla de carga.
                return const LoadingScreen();
              }
            },
          );
        } else {
          // Si no hay sesión, reiniciamos el future y mostramos la pantalla de login.
          _initializationFuture = null;
          return const LoginScreen();
        }
      },
    );
  }

  /// Inicializa todos los servicios que dependen de un usuario autenticado.
  ///
  /// Utiliza `Future.wait` para ejecutar todas las inicializaciones en paralelo
  /// y así acelerar el tiempo de carga.
  Future<void> _initializeUserServices() async {
    if (kDebugMode) {
      print("✅ Usuario autenticado. Orquestando inicialización de servicios tardíos...");
    }
    try {
      await Future.wait([
        // [CAMBIO CLAVE] Aquí es el lugar perfecto para llamar a `initializeLate`.
        // Este método pide los permisos de notificación y obtiene el token FCM,
        // tareas que deben ocurrir DESPUÉS de que el usuario haya iniciado sesión.
        NotificationService.instance.initializeLate(),
        
        // (Opcional) Si en el futuro necesitas refrescar todas las notificaciones
        // programadas al iniciar sesión, este sería un buen lugar para hacerlo.
        // NotificationService.instance.refreshAllSchedules(),
        
        // Ejemplo: AnalyticsService.instance.identifyUser(session.user.id),
      ]);
      if (kDebugMode) {
        print("✅ Todos los servicios de usuario inicializados exitosamente.");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("🚨 Error fatal durante la inicialización de servicios: $e\n$stackTrace");
        // En una app de producción, aquí podrías registrar el error en un servicio
        // como Sentry o Firebase Crashlytics.
      }
    }
  }
}