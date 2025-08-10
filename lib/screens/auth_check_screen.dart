// lib/screens/auth_check_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sasper/screens/auth_gate.dart'; // <-- ¡IMPORTANTE! Apunta a tu AuthGate

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    // Inmediatamente intentamos autenticar.
    // Usamos un pequeño retraso para asegurar que la transición de pantalla se complete.
    Future.delayed(const Duration(milliseconds: 200), _authenticate);
  }
  
  Future<void> _authenticate() async {
    // Si el widget ya no está en el árbol, no hacemos nada.
    if (!mounted) return;

    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();
      
      if (!canAuthenticate) {
        // Si el dispositivo no tiene seguridad, lo dejamos pasar directamente.
        _navigateToAuthGate();
        return;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a SasPer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      // Usamos 'mounted' de nuevo por si el usuario tarda mucho en autenticarse.
      if (didAuthenticate && mounted) {
        _navigateToAuthGate();
      } else {
        // Si la autenticación falla o es cancelada, cerramos la app.
        SystemNavigator.pop();
      }
    } on PlatformException catch (_) {
      // Si hay un error (ej. permisos no configurados), cerramos la app.
      SystemNavigator.pop();
    }
  }

  void _navigateToAuthGate() {
    // La clave está aquí: navegamos a AuthGate, no a la pantalla de inicio.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Muestra una UI mínima mientras aparece el diálogo del sistema.
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             SizedBox(
              width: 60,
              height: 60,
              child: Icon(Icons.fingerprint, size: 60),
            ),
            SizedBox(height: 24),
            Text(
              'Esperando autenticación...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}