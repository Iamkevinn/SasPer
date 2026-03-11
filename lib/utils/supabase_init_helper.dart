import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/config/app_config.dart';

class SupabaseInitHelper {
  static Completer<bool>? _initializationCompleter;

  static Future<bool> ensureInitialized({String? tag}) async {
    final logTag = tag ?? 'SupabaseInitHelper';

    // 1. Si ya hay una inicialización en curso, esperamos a que termine
    if (_initializationCompleter != null) {
      return _initializationCompleter!.future;
    }

    // 2. Verificación: ¿Ya está inicializado?
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      // No está listo, procedemos a crear un nuevo Completer
      _initializationCompleter = Completer<bool>();
    }

    try {
      // Verificar si Supabase ya fue inicializado
if (!Supabase.instance.isInitialized) {
  await Supabase.initialize(
    url: AppConfig.supabaseUrl, // o tu variable de entorno
    anonKey: AppConfig.supabaseAnonKey,
  );
}
      developer.log('✅ Supabase inicializado correctamente.', name: logTag);
      _initializationCompleter!.complete(true);
      return true;
    } catch (e) {
      // Si falla por "already initialized", lo tratamos como éxito
      if (e.toString().contains('already been initialized')) {
        developer.log('✅ Supabase ya estaba listo.', name: logTag);
        _initializationCompleter!.complete(true);
        return true;
      }
      developer.log('🔥 Error crítico al inicializar: $e', name: logTag);
      _initializationCompleter!.complete(false);
      return false;
    } finally {
      _initializationCompleter = null;
    }
  }
}