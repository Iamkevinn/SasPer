// lib/data/budget_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/budget_models.dart';

class BudgetRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---

  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! BudgetRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---

  final _streamController = StreamController<List<BudgetProgress>>.broadcast();
  RealtimeChannel? _channel;
  bool _isInitialized = false;

  BudgetRepository._privateConstructor();
  static final BudgetRepository instance = BudgetRepository._privateConstructor();

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] BudgetRepository Singleton Initialized and Client Injected.', name: 'BudgetRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<BudgetProgress>> getBudgetsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushData();
    return _streamController.stream;
  }

  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for budgets & transactions...', name: 'BudgetRepository');
    _channel = client
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

  Future<void> refreshData() async {
    await _fetchAndPushData();
  }

  Future<List<BudgetProgress>> _fetchBudgetsProgress() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");
      
      final response = await client.rpc('get_budgets_progress_for_user', params: {'p_user_id': userId});
      
      if (response is List && response.isNotEmpty) {
        if (kDebugMode) {
          print('===== VERDAD ABSOLUTA DE SUPABASE =====');
          print('Datos crudos del primer presupuesto: ${response.first}');
          print('=======================================');
        }
      }

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
    final userId = client.auth.currentUser!.id;
    try {
      await client.from('budgets').upsert({
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
      await client
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
      await client.rpc(
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
      client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}