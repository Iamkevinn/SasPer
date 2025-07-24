// lib/data/budget_repository.dart


import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sasper/models/budget_models.dart';

class BudgetRepository {
  final SupabaseClient _client;
  
  // Usamos un StreamController para gestionar el stream de forma controlada
  final _budgetsProgressController = StreamController<List<BudgetProgress>>.broadcast();
  RealtimeChannel? _subscriptionChannel;

  // Constructor con inyección de dependencias para facilitar los tests
  BudgetRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Devuelve un Stream en tiempo real con el progreso de los presupuestos del mes actual.
  /// Se suscribe a los cambios en las tablas 'budgets' y 'transactions'.
  Stream<List<BudgetProgress>> getBudgetsProgressStream() {
    developer.log('📡 [Repo] Subscribing to budgets & transactions stream...');
    
    // Si el canal no ha sido creado, lo configuramos
    _subscriptionChannel ??= _client
        .channel('public:budgets_and_transactions_for_budgets_screen')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'budgets',
          callback: (payload) => _fetchAndPushData(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          callback: (payload) => _fetchAndPushData(),
        )
        .subscribe();
    
    // Hacemos una carga inicial de los datos para que la UI no espere al primer cambio
    _fetchAndPushData();
    
    // Devolvemos el stream del controlador para que la UI lo consuma
    return _budgetsProgressController.stream;
  }
  
  /// Helper privado que obtiene los datos y los añade al stream controller.
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Fetching fresh budget progress data...');
    try {
      final data = await _fetchBudgetsProgress();
      if (!_budgetsProgressController.isClosed) {
        _budgetsProgressController.add(data);
      }
    } catch (e) {
      if (!_budgetsProgressController.isClosed) {
        _budgetsProgressController.addError(e);
      }
    }
  }

  // ---- NUEVO MÉTODO PARA ACTUALIZAR ----
  /// Actualiza el monto de un presupuesto existente.
  Future<void> updateBudget({required int budgetId, required double newAmount}) async {
    developer.log('🔄 [Repo] Updating budget $budgetId with new amount $newAmount');
    try {
      await _client
          .from('budgets')
          .update({'amount': newAmount})
          .eq('id', budgetId);
      developer.log('✅ [Repo] Budget updated successfully.');
    } catch (e) {
      developer.log('🔥 [Repo] Error updating budget: $e');
      throw Exception('No se pudo actualizar el presupuesto.');
    }
  }

  /// ---- MÉTODO DE BORRADO MODIFICADO PARA USAR LA FUNCIÓN SEGURA ----
  /// Llama a la función RPC para eliminar un presupuesto de forma segura.
  /// Lanza una excepción si la función RPC devuelve un error.
  Future<void> deleteBudgetSafely(int budgetId) async {
    developer.log('🗑️ [Repo] Safely deleting budget with id $budgetId');
    try {
      final result = await _client.rpc(
        'delete_budget_safely',
        params: {'budget_id_to_delete': budgetId},
      ) as String;

      // La función RPC devuelve un texto. Si empieza con 'Error:', lanzamos una excepción.
      if (result.startsWith('Error:')) {
        throw Exception(result.replaceFirst('Error: ', ''));
      }
      
      developer.log('✅ [Repo] Budget safely deleted successfully.');
    } catch (e) {
      developer.log('🔥 [Repo] Error in RPC delete_budget_safely: $e');
      // Relanzamos la excepción para que la UI pueda mostrarla.
      throw Exception(e.toString().contains('No se puede eliminar') 
          ? e.toString().replaceFirst('Exception: ', '')
          : 'No se pudo eliminar el presupuesto.');
    }
  }
  
  /// Obtiene los datos de progreso de los presupuestos llamando a la función RPC.
  /// Es privado porque solo se usa dentro de esta clase.
  Future<List<BudgetProgress>> _fetchBudgetsProgress() async {
    try {
      final response = await _client.rpc('get_budgets_progress');
      final budgetsProgress = (response as List)
          .map((data) => BudgetProgress.fromJson(data))
          .toList();
      developer.log('✅ [Repo] Fetched ${budgetsProgress.length} budget progress items via RPC.');
      return budgetsProgress;
    } catch (e) {
      developer.log('🔥 [Repo] Error in RPC get_budgets_progress: $e');
      throw Exception('Failed to fetch budget progress.');
    }
  }

  /// Limpia los recursos (streams y canales) cuando ya no se necesiten.
  /// Debe ser llamado desde el `dispose` del widget que lo usa.
  void dispose() {
    developer.log('❌ [Repo] Disposing BudgetRepository resources.');
    if (_subscriptionChannel != null) {
      _client.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
    }
    _budgetsProgressController.close();
  }

  /// Guarda (crea o actualiza) un presupuesto para el mes y año actuales.
  Future<void> addBudget({
    required String category,
    required double amount,
    required int month, // Añadido para flexibilidad
    required int year,  // Añadido para flexibilidad
  }) async {
    developer.log('💾 [Repo] Adding budget for "$category" with amount $amount');
    final userId = _client.auth.currentUser!.id;

    try {
      // Usamos upsert para crear o actualizar si ya existe.
      await _client.from('budgets').upsert({
        'user_id': userId,
        'category': category,
        'month': month,
        'year': year,
        'amount': amount,
      }, onConflict: 'user_id, category, month, year');

      developer.log('✅ [Repo] Budget added/updated successfully.');
    } catch (e) {
      developer.log('🔥 [Repo] Error adding budget: $e');
      throw Exception('No se pudo guardar el presupuesto.');
    }
  }

  /// Guarda (crea o actualiza) un presupuesto para el mes y año actuales.
  /// Lanza una excepción si la operación falla.
  Future<void> saveBudget({
    required String category,
    required double amount,
  }) async {
    developer.log('💾 [Repo] Saving budget for "$category" with amount $amount');
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;
    final userId = _client.auth.currentUser!.id;

    try {
      await _client.from('budgets').upsert({
        'user_id': userId,
        'category': category,
        'month': currentMonth,
        'year': currentYear,
        'amount': amount,
      }, onConflict: 'user_id, category, month, year');

      developer.log('✅ [Repo] Budget saved successfully.');
      // No es necesario llamar a _fetchAndPushData manualmente,
      // la suscripción `onPostgresChanges` lo hará automáticamente.
    } catch (e) {
      developer.log('🔥 [Repo] Error saving budget: $e');
      throw Exception('No se pudo guardar el presupuesto.');
    }
  }

  /// Elimina un presupuesto.
  Future<void> deleteBudget(int budgetId) async {
    developer.log('🗑️ [Repo] Deleting budget with id $budgetId');
    try {
      await _client.from('budgets').delete().eq('id', budgetId);
      developer.log('✅ [Repo] Budget deleted successfully.');
    } catch (e) {
      developer.log('🔥 [Repo] Error deleting budget: $e');
      throw Exception('No se pudo eliminar el presupuesto.');
    }
  }
}