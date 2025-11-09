// lib/screens/biometric_gate.dart

import 'package:flutter/foundation.dart';
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
    final isEnabled = await PreferencesService.instance.isBiometricLockEnabled();

    if (isEnabled) {
      final LocalAuthentication auth = LocalAuthentication();
      try {
        // =======================================================
        //  CORRECCIÓN FINAL Y VERIFICADA
        // =======================================================
        // Se elimina 'stickyAuth' ya que no existe en la v3.
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Por favor, autentícate para acceder a SasPer',
        );
        // =======================================================

        if (didAuthenticate) {
          _navigateToMainScreen();
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error de autenticación: $e");
        }
        _navigateToMainScreen();
      }
    } else {
      _navigateToMainScreen();
    }
  }

  void _navigateToMainScreen() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}