// lib/data/budget_repository.dart

import 'dart:async';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/budget_models.dart';

class BudgetRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  // ¡CAMBIO CLAVE! El stream ahora maneja el nuevo modelo `Budget`.
  final _streamController = StreamController<List<Budget>>.broadcast();
  RealtimeChannel? _channel;

  BudgetRepository._internal();
  static final BudgetRepository instance = BudgetRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
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

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de los presupuestos.
  Stream<List<Budget>> getBudgetsStream() {
    _fetchAndPushData();
    return _streamController.stream;
  }

  /// Vuelve a cargar los datos de los presupuestos.
  Future<void> refreshData() => _fetchAndPushData();

  /// Obtiene una lista única de los presupuestos activos.
  Future<List<Budget>> getBudgets() => _fetchBudgets();

  /// Añade un nuevo presupuesto con fechas flexibles.
  Future<void> addBudget({
    required String categoryName, // Ahora usamos ID para mayor robustez
    required double amount,
    required DateTime startDate,
    required DateTime endDate,
    required String periodicity,
  }) async {
    developer.log('💾 [Repo] Guardando presupuesto para categoría ID $categoryName', name: 'BudgetRepository');
    final userId = client.auth.currentUser!.id;
    try {
      await client.from('budgets').insert({
        'user_id': userId,
        'category': categoryName,
        'amount': amount,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'periodicity': periodicity,
      });
      developer.log('✅ [Repo] Presupuesto guardado con éxito.', name: 'BudgetRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error guardando presupuesto: $e', name: 'BudgetRepository');
      rethrow; // Propagamos el error para que la UI pueda manejarlo.
    }
  }

  /// Actualiza un presupuesto existente.
  Future<void> updateBudget({
    required int budgetId,
    required String categoryName,
    required double amount,
    required DateTime startDate,
    required DateTime endDate,
    required String periodicity,
  }) async {
    developer.log('🔄 [Repo] Actualizando presupuesto $budgetId', name: 'BudgetRepository');
    try {
      await client
          .from('budgets')
          .update({
            'amount': amount,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'periodicity': periodicity,
          })
          .eq('id', budgetId);
      developer.log('✅ [Repo] Presupuesto actualizado con éxito.', name: 'BudgetRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error actualizando presupuesto: $e', name: 'BudgetRepository');
      rethrow;
    }
  }

  
  /// Obtiene y calcula el resumen total de todos los presupuestos activos.
  ///
  /// Devuelve un récord con el presupuesto total y el gasto total.
  Future<(double totalBudget, double totalSpent)> getOverallBudgetSummary() async {
    try {
      // 1. Reutilizamos la función existente para obtener todos los presupuestos.
      final List<Budget> activeBudgets = await _fetchBudgets();

      // 2. Si no hay presupuestos, devolvemos cero para evitar errores.
      if (activeBudgets.isEmpty) {
        return (0.0, 0.0);
      }

      // 3. Usamos fold para sumarizar los valores de forma segura y eficiente.
      final double totalBudget = activeBudgets.fold(0.0, (sum, budget) => sum + budget.amount);
      // Asumimos que tu modelo `Budget` tiene una propiedad `spent` que viene del RPC.
      final double totalSpent = activeBudgets.fold(0.0, (sum, budget) => sum + budget.spentAmount);
      
      developer.log('📊 [Repo] Resumen de presupuesto calculado: Total \$${totalBudget.toStringAsFixed(2)}, Gastado \$${totalSpent.toStringAsFixed(2)}', name: 'BudgetRepository');

      return (totalBudget, totalSpent);
    } catch (e) {
      developer.log('🔥 [Repo] Error calculando el resumen del presupuesto: $e', name: 'BudgetRepository');
      // Devolvemos cero en caso de error para que la UI no se rompa.
      return (0.0, 0.0);
    }
  }

  /// Llama a un RPC para eliminar un presupuesto de forma segura.
  Future<void> deleteBudgetSafely(int budgetId) async {
    developer.log('🗑️ [Repo] Eliminando presupuesto con id $budgetId', name: 'BudgetRepository');
    try {
      await client.rpc(
        'delete_budget_safely', // Asegúrate de que esta RPC exista en tu DB
        params: {'budget_id_to_delete': budgetId},
      );
    } catch (e) {
      developer.log('🔥 [Repo] Error en RPC delete_budget_safely: $e', name: 'BudgetRepository');
      rethrow;
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de BudgetRepository.', name: 'BudgetRepository');
    _channel?.unsubscribe();
    _channel = null;
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
    developer.log('🔄 [Repo] Refrescando datos de presupuestos para el stream...', name: 'BudgetRepository');
    try {
      final data = await _fetchBudgets();
      if (!_streamController.isClosed) {
        _streamController.add(data);
      }
    } catch (e) {
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  /// Llama a la nueva RPC para obtener los presupuestos con su progreso calculado.
  Future<List<Budget>> _fetchBudgets() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Usuario no autenticado");

      // ¡CAMBIO CLAVE! Llamamos a la nueva RPC.
      final response = await client.rpc(
        'get_active_budgets_with_progress',
        params: {'p_user_id': userId}
      );

      final budgets = (response as List)
          .map((data) => Budget.fromMap(data))
          .toList();
          
      developer.log('✅ [Repo] Obtenidos ${budgets.length} presupuestos vía RPC.', name: 'BudgetRepository');
      return budgets;
    } catch (e) {
      developer.log('🔥 [Repo] Error en RPC get_active_budgets_with_progress: $e', name: 'BudgetRepository');
      throw Exception('Falló al obtener los presupuestos.');
    }
  }
}