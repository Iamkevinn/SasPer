// lib/services/preferences_service.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Un servicio Singleton para gestionar las preferencias del usuario guardadas en el dispositivo.
class PreferencesService {
  // Clave para guardar la preferencia del bloqueo biométrico.
  static const _biometricKey = 'isBiometricLockEnabled';

  // --- Patrón Singleton ---
  PreferencesService._internal();
  static final PreferencesService instance = PreferencesService._internal();
  // -------------------------

  /// Comprueba si el bloqueo por huella/PIN está activado.
  /// Devuelve 'true' por defecto si la opción nunca se ha guardado.
  Future<bool> isBiometricLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Usamos '?? true' para que la opción esté activada por defecto la primera vez.
    return prefs.getBool(_biometricKey) ?? true;
  }

  /// Activa o desactiva el bloqueo por huella/PIN.
  Future<void> setBiometricLock({required bool isEnabled}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, isEnabled);
  }
}