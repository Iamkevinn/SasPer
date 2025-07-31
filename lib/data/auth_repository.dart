// lib/data/auth_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  // 1. El cliente se declara como 'late final'.
  late final SupabaseClient _client;

  // 2. Constructor privado.
  AuthRepository._privateConstructor();

  // 3. La instancia estática que guarda el único objeto de esta clase.
  static final AuthRepository instance = AuthRepository._privateConstructor();

  // 4. Método público de inicialización. Se llama desde main.dart.
  void initialize(SupabaseClient client) {
    _client = client;
  }

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream que emite eventos de cambio de estado de autenticación.
  /// Ideal para ser usado por el AuthGate.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Devuelve el usuario actualmente autenticado, o null si no hay ninguno.
  User? get currentUser => _client.auth.currentUser;

  /// Registra un nuevo usuario con email y contraseña.
  /// AHORA también acepta un nombre de usuario para pasarlo como metadato.
  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          // Estos datos se guardan en 'raw_user_meta_data'
          // y nuestra función SQL los usará para crear el perfil.
          'username': username,
          'full_name': fullName,
        },
      );
    } on AuthException catch (e) {
      developer.log('🔥 Error de registro: ${e.message}', name: 'AuthRepository');
      throw Exception(e.message);
    } catch (e) {
      developer.log('🔥 Error inesperado en signUp: $e', name: 'AuthRepository');
      throw Exception('Ocurrió un error inesperado.');
    }
  }
  
  /// Inicia sesión con correo y contraseña.
  /// Lanza excepciones con mensajes claros para la UI en caso de error.
  Future<void> signInWithPassword(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // Mapeamos errores comunes a mensajes más amigables.
      if (e.message.contains('Invalid login credentials')) {
        throw 'Correo o contraseña incorrectos. Por favor, verifica tus datos.';
      }
      throw 'Error de autenticación: ${e.message}';
    } catch (e) {
      throw 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
  }

  /// Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}