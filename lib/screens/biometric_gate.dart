// lib/screens/biometric_gate.dart

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sasper/screens/main_screen.dart';
import 'package:sasper/services/preferences_service.dart';

class BiometricGate extends StatefulWidget {
  const BiometricGate({super.key});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate> {
  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    // Comprobamos la preferencia del usuario
    final isEnabled = await PreferencesService.instance.isBiometricLockEnabled();

    if (isEnabled) {
      final LocalAuthentication auth = LocalAuthentication();
      try {
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Por favor, autentícate para acceder a SasPer',
          options: const AuthenticationOptions(
            stickyAuth: true, // Mantiene el diálogo nativo abierto
          ),
        );
        if (didAuthenticate) {
          _navigateToMainScreen();
        } else {
          // Si el usuario cancela, no hacemos nada. Podrías cerrar la app aquí si quisieras.
        }
      } catch (e) {
        // Manejar errores (ej: no hay biometría configurada)
        print("Error de autenticación: $e");
        _navigateToMainScreen(); // En caso de error, por seguridad, lo dejamos pasar por ahora
      }
    } else {
      // Si el bloqueo está desactivado, vamos directamente a la pantalla principal
      _navigateToMainScreen();
    }
  }

  void _navigateToMainScreen() {
    // Usamos pushReplacement para que el usuario no pueda volver atrás a la pantalla de bloqueo
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mostramos una pantalla de carga vacía mientras se realiza la comprobación
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}