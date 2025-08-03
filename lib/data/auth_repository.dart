// lib/data/auth_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! AuthRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---

  AuthRepository._privateConstructor();
  static final AuthRepository instance = AuthRepository._privateConstructor();
  bool _isInitialized = false;

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] AuthRepository Singleton Initialized and Client Injected.', name: 'AuthRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

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
      throw Exception(e.message);
    } catch (e) {
      developer.log('🔥 Error inesperado en signUp: $e', name: 'AuthRepository');
      throw Exception('Ocurrió un error inesperado.');
    }
  }
  
  Future<void> signInWithPassword(String email, String password) async {
    try {
      await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials')) {
        throw 'Correo o contraseña incorrectos. Por favor, verifica tus datos.';
      }
      throw 'Error de autenticación: ${e.message}';
    } catch (e) {
      throw 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }
}