// lib/screens/auth_check_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:sasper/screens/auth_gate.dart';

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
    Future.delayed(const Duration(milliseconds: 200), _authenticate);
  }

  Future<void> _authenticate() async {
    if (!mounted) return;

    try {
      final bool canAuthenticate = await auth.canCheckBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        _navigateToAuthGate();
        return;
      }

      // =======================================================
      //  CORRECCIÓN FINAL Y VERIFICADA
      // =======================================================
      // El parámetro 'stickyAuth' fue eliminado en la v3.
      // 'biometricOnly' es un parámetro directo válido.
      // El comportamiento del diálogo ahora es el estándar del sistema.
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Por favor, autentícate para acceder a SasPer',
        biometricOnly: false, // Permite PIN/Patrón si la biometría falla
      );
      // =======================================================

      if (didAuthenticate && mounted) {
        _navigateToAuthGate();
      } else {
        SystemNavigator.pop();
      }
    } on PlatformException catch (_) {
      SystemNavigator.pop();
    }
  }

  void _navigateToAuthGate() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
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