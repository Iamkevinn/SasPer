// lib/data/auth_repository.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  // Stream para que el AuthGate pueda escuchar cambios de estado.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // Obtener el usuario actual
  User? get currentUser => _client.auth.currentUser;

  Future<void> signInWithPassword(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      // Mapeamos errores comunes a mensajes más claros
      if (e.message.contains('Invalid login credentials')) {
        throw 'Correo o contraseña incorrectos. Por favor, verifica tus datos.';
      }
      throw 'Error de autenticación: ${e.message}';
    } catch (e) {
      throw 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
  }

  Future<void> signUp(String email, String password) async {
     try {
      await _client.auth.signUp(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      if (e.message.contains('User already registered')) {
        throw 'Ya existe una cuenta con este correo electrónico.';
      }
      throw 'Error en el registro: ${e.message}';
    } catch (e) {
      throw 'Ocurrió un error inesperado. Inténtalo de nuevo.';
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}