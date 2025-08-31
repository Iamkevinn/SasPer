// lib/data/auth_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Constructor privado para forzar el uso del Singleton `instance`.
  AuthRepository._internal();
  static final AuthRepository instance = AuthRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  /// Se ejecuta automáticamente la primera vez que se accede al cliente de Supabase.
  void _ensureInitialized() {
    // Esta lógica solo se ejecuta una vez en todo el ciclo de vida de la app.
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      developer.log('✅ AuthRepository inicializado PEREZOSAMENTE.', name: 'AuthRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  /// Activa la inicialización perezosa cuando es necesario.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para AuthRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---
  // Todos los métodos ahora usan el getter `client` que asegura la inicialización.

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  User? get currentUser => client.auth.currentUser;

  Future<void> signUp({
    required String email,
    required String password,
    required String username,
    String? fullName,
  }) async {
    try {
      await client.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username,
          'full_name': fullName,
        },
      );
    } on AuthException catch (e) {
      developer.log('🔥 Error de registro: ${e.message}', name: 'AuthRepository');
      // Re-lanzamos la excepción original de Supabase para que la UI pueda manejarla.
      rethrow;
    } catch (e) {
      developer.log('🔥 Error inesperado en signUp: $e', name: 'AuthRepository');
      throw Exception('Ocurrió un error inesperado durante el registro.');
    }
  }

  Future<void> signInWithPassword(String email, String password) async {
    try {
      await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      developer.log('🔥 Error de inicio de sesión: ${e.message}', name: 'AuthRepository');
      // Es mejor relanzar la excepción original para que la UI decida el mensaje exacto.
      // Así, si Supabase cambia el mensaje, tu app se adapta.
      rethrow;
    } catch (e) {
      developer.log('🔥 Error inesperado en signIn: $e', name: 'AuthRepository');
      throw Exception('Ocurrió un error inesperado al iniciar sesión.');
    }
  }

  Future<void> signOut() async {
    try {
      await client.auth.signOut();
    } catch (e) {
      developer.log('🔥 Error al cerrar sesión: $e', name: 'AuthRepository');
      // Opcional: podrías querer lanzar una excepción si el cierre de sesión falla.
    }
  }
}