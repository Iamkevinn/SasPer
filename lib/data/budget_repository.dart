// lib/data/budget_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/budget_models.dart';

class BudgetRepository {
  // 1. El cliente se declara como 'late final'. Se inicializará una vez.
  late final SupabaseClient _client;

  final _streamController = StreamController<List<BudgetProgress>>.broadcast();
  RealtimeChannel? _channel;

  // 2. Constructor privado para evitar que se creen instancias desde fuera.
  BudgetRepository._privateConstructor();

  // 3. La instancia estática que guarda el único objeto de esta clase.
  static final BudgetRepository instance = BudgetRepository._privateConstructor();

  // 4. Método público de inicialización. Se llama desde main.dart.
  void initialize(SupabaseClient client) {
    _client = client;
    developer.log('✅ [Repo] BudgetRepository Singleton Initialized and Client Injected.', name: 'BudgetRepository');
  }

  /// Devuelve un stream con el progreso de los presupuestos del mes actual.
  /// Se actualiza en tiempo real cuando cambian los presupuestos o las transacciones.
  Stream<List<BudgetProgress>> getBudgetsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushData();
    return _streamController.stream;
  }

  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for budgets & transactions...', name: 'BudgetRepository');
    _channel = _client
        .channel('public:budgets_and_transactions_for_budgets')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'budgets',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change in BUDGETS. Refetching progress...', name: 'BudgetRepository');
            _fetchAndPushData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change in TRANSACTIONS. Refetching budget progress...', name: 'BudgetRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }

  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Fetching fresh budget progress data...', name: 'BudgetRepository');
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

  /// Fuerza una recarga manual de los datos de los presupuestos.
  Future<void> refreshData() async {
    await _fetchAndPushData();
  }

  Future<List<BudgetProgress>> _fetchBudgetsProgress() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");
      
      final response = await _client.rpc('get_budgets_progress_for_user', params: {'p_user_id': userId});
      // ===== ¡LÍNEA DE DEPURACIÓN CLAVE! =====
      // Esto nos mostrará los nombres de las claves tal como llegan de Supabase.
      if (response is List && response.isNotEmpty) {
        if (kDebugMode) {
          print('===== VERDAD ABSOLUTA DE SUPABASE =====');
          print('Datos crudos del primer presupuesto: ${response.first}');
          print('=======================================');
        }

      }
      // ===========================================
      final budgetsProgress = (response as List)
          .map((data) => BudgetProgress.fromMap(data))
          .toList();
      developer.log('✅ [Repo] Fetched ${budgetsProgress.length} budget progress items via RPC.', name: 'BudgetRepository');
      return budgetsProgress;
    } catch (e) {
      developer.log('🔥 [Repo] Error in RPC get_budgets_progress: $e', name: 'BudgetRepository');
      throw Exception('Failed to fetch budget progress.');
    }
  }

  /// Obtiene los presupuestos para el mes y año actual. Ideal para la pantalla de añadir transacción.
  Future<List<BudgetProgress>> getBudgetsForCurrentMonth() async {
    return await _fetchBudgetsProgress();
  }

  Future<void> addBudget({
    required String category,
    required double amount,
    required int month,
    required int year,
  }) async {
    developer.log('💾 [Repo] Adding budget for "$category" with amount $amount', name: 'BudgetRepository');
    final userId = _client.auth.currentUser!.id;
    try {
      await _client.from('budgets').upsert({
        'user_id': userId,
        'category': category,
        'month': month,
        'year': year,
        'amount': amount,
      }, onConflict: 'user_id, category, month, year');
      developer.log('✅ [Repo] Budget added/updated successfully.', name: 'BudgetRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error adding budget: $e', name: 'BudgetRepository');
      throw Exception('No se pudo guardar el presupuesto.');
    }
  }

  Future<void> updateBudget({required int budgetId, required double newAmount}) async {
    developer.log('🔄 [Repo] Updating budget $budgetId with new amount $newAmount', name: 'BudgetRepository');
    try {
      await _client
          .from('budgets')
          .update({'amount': newAmount})
          .eq('id', budgetId);
      developer.log('✅ [Repo] Budget updated successfully.', name: 'BudgetRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error updating budget: $e', name: 'BudgetRepository');
      throw Exception('No se pudo actualizar el presupuesto.');
    }
  }

  Future<void> deleteBudgetSafely(int budgetId) async {
    developer.log('🗑️ [Repo] Safely deleting budget with id $budgetId', name: 'BudgetRepository');
    try {
      await _client.rpc(
        'delete_budget_safely',
        params: {'budget_id_to_delete': budgetId},
      );
    } catch (e) {
      developer.log('🔥 [Repo] Error in RPC delete_budget_safely: $e', name: 'BudgetRepository');
      throw Exception('No se pudo eliminar el presupuesto.');
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing BudgetRepository resources.', name: 'BudgetRepository');
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}