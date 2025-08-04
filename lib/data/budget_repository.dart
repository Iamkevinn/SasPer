// lib/data/budget_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/budget_models.dart';

class BudgetRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<BudgetProgress>>.broadcast();
  RealtimeChannel? _channel;

  // Constructor privado para forzar el uso del Singleton `instance`.
  BudgetRepository._internal();
  static final BudgetRepository instance = BudgetRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription(); // La configuración de Realtime depende de la inicialización.
      _isInitialized = true;
      developer.log('✅ BudgetRepository inicializado PEREZOSAMENTE.', name: 'BudgetRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para BudgetRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream del progreso de los presupuestos.
  Stream<List<BudgetProgress>> getBudgetsStream() {
    // La inicialización se activará la primera vez que se llame a `_fetchAndPushData`.
    _fetchAndPushData();
    return _streamController.stream;
  }

  /// Vuelve a cargar los datos de los presupuestos.
  Future<void> refreshData() => _fetchAndPushData();

  /// Obtiene el progreso de los presupuestos para el mes actual (llamada única).
  Future<List<BudgetProgress>> getBudgetsForCurrentMonth() => _fetchBudgetsProgress();
  
  /// Añade o actualiza un presupuesto para una categoría en un mes/año específico.
  Future<void> addBudget({
    required String category,
    required double amount,
    required int month,
    required int year,
  }) async {
    developer.log('💾 [Repo] Guardando presupuesto para "$category" con monto $amount', name: 'BudgetRepository');
    final userId = client.auth.currentUser!.id;
    try {
      await client.from('budgets').upsert({
        'user_id': userId,
        'category': category,
        'month': month,
        'year': year,
        'amount': amount,
      }, onConflict: 'user_id, category, month, year');
      developer.log('✅ [Repo] Presupuesto guardado con éxito.', name: 'BudgetRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error guardando presupuesto: $e', name: 'BudgetRepository');
      throw Exception('No se pudo guardar el presupuesto.');
    }
  }

  /// Actualiza el monto de un presupuesto existente por su ID.
  Future<void> updateBudget({required int budgetId, required double newAmount}) async {
    developer.log('🔄 [Repo] Actualizando presupuesto $budgetId con nuevo monto $newAmount', name: 'BudgetRepository');
    try {
      await client
          .from('budgets')
          .update({'amount': newAmount})
          .eq('id', budgetId);
      developer.log('✅ [Repo] Presupuesto actualizado con éxito.', name: 'BudgetRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error actualizando presupuesto: $e', name: 'BudgetRepository');
      throw Exception('No se pudo actualizar el presupuesto.');
    }
  }
  
  /// Llama a un RPC para eliminar un presupuesto de forma segura.
  Future<void> deleteBudgetSafely(int budgetId) async {
    developer.log('🗑️ [Repo] Eliminando presupuesto con id $budgetId', name: 'BudgetRepository');
    try {
      await client.rpc(
        'delete_budget_safely',
        params: {'budget_id_to_delete': budgetId},
      );
    } catch (e) {
      developer.log('🔥 [Repo] Error en RPC delete_budget_safely: $e', name: 'BudgetRepository');
      throw Exception('No se pudo eliminar el presupuesto.');
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de BudgetRepository.', name: 'BudgetRepository');
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // --- MÉTODOS PRIVADOS ---

  /// Configura las suscripciones de Realtime para los presupuestos y transacciones.
  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo-Lazy] Configurando Realtime para Presupuestos...', name: 'BudgetRepository');
    _channel = _supabase!
        .channel('public:budgets_and_transactions_for_budgets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'budgets',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (_) => _fetchAndPushData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (_) => _fetchAndPushData(),
        )
        .subscribe();
  }

  /// Carga los datos frescos desde el RPC y los emite en el stream.
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Obteniendo progreso de presupuestos...', name: 'BudgetRepository');
    try {
      final data = await _fetchBudgetsProgress();
      if (!_streamController.isClosed) {
        _streamController.add(data);
      }
    } catch (e) {
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  /// Llama al RPC para obtener el progreso de todos los presupuestos del mes actual.
  Future<List<BudgetProgress>> _fetchBudgetsProgress() async {
    try {
      // Usa el getter `client` para asegurar la inicialización.
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Usuario no autenticado");
      
      final response = await client.rpc('get_budgets_progress_for_user', params: {'p_user_id': userId});
      
      if (kDebugMode && response is List && response.isNotEmpty) {
        print('===== VERDAD ABSOLUTA DE SUPABASE (Budgets) =====');
        print('Datos crudos del primer presupuesto: ${response.first}');
        print('=======================================');
      }

      final budgetsProgress = (response as List)
          .map((data) => BudgetProgress.fromMap(data))
          .toList();
      developer.log('✅ [Repo] Obtenidos ${budgetsProgress.length} presupuestos vía RPC.', name: 'BudgetRepository');
      return budgetsProgress;
    } catch (e) {
      developer.log('🔥 [Repo] Error en RPC get_budgets_progress: $e', name: 'BudgetRepository');
      throw Exception('Falló al obtener el progreso de los presupuestos.');
    }
  }
}