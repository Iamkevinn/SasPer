// lib/data/analysis_repository.dart

import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/analysis_models.dart';

class AnalysisRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Constructor privado para forzar el uso del Singleton `instance`.
  AnalysisRepository._internal();
  static final AnalysisRepository instance = AnalysisRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  /// Se ejecuta automáticamente la primera vez que se accede al cliente de Supabase.
  void _ensureInitialized() {
    // Esta lógica solo se ejecuta una vez en todo el ciclo de vida de la app.
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      developer.log('✅ AnalysisRepository inicializado PEREZOSAMENTE.', name: 'AnalysisRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  /// Activa la inicialización perezosa cuando es necesario.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para AnalysisRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient client) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Obtiene solo el resumen de gastos, ideal para widgets o cargas rápidas.
  Future<List<ExpenseByCategory>> getExpenseSummaryForWidget() async {
    developer.log("📈 [Repo] Obteniendo resumen de gastos para widget...", name: 'AnalysisRepository');
    try {
      // Todos los métodos ahora usan el getter `client` que asegura la inicialización.
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final clientDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final result = await client.rpc(
        'get_expense_summary_by_category',
        params: {'p_user_id': userId, 'client_date': clientDate}
      );
      
      // Aseguramos que el resultado sea una lista antes de mapear.
      if (result is List) {
        return result.map((e) => ExpenseByCategory.fromMap(e)).toList();
      }
      return [];

    } catch (e) {
      developer.log('🔥 Error en getExpenseSummaryForWidget: $e', name: 'AnalysisRepository');
      return [];
    }
  }
  
  /// Obtiene el conjunto completo de datos para la pantalla de análisis.
  Future<AnalysisData> fetchAllAnalysisData() async {
    developer.log("📈 [Repo] Obteniendo todos los datos de análisis...", name: 'AnalysisRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return AnalysisData.empty();
      }

      final today = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 120)));
      final endDate = DateFormat('yyyy-MM-dd').format(today);
      final clientDate = DateFormat('yyyy-MM-dd').format(today);

      // Usamos Future.wait para eficiencia.
      // El .catchError en cada futuro previene que un solo error detenga todas las demás peticiones.
      final results = await Future.wait([
        client.rpc('get_expense_summary_by_category', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((_) => []),
        client.rpc('get_net_worth_trend', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((_) => []),
        client.rpc('get_monthly_cash_flow', params: {'p_user_id': userId}).catchError((_) => []),
        client.rpc('get_category_spending_comparison', params: {'p_user_id': userId}).catchError((_) => []),
        client.rpc('get_income_summary_by_category', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((_) => []),
        client.rpc('get_monthly_income_expense_summary', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((_) => []),
        client.rpc('get_daily_net_flow', params: {'p_user_id': userId, 'start_date': startDate, 'end_date': endDate}).catchError((_) => []),
      ]);
      
      // Función auxiliar robusta para parsear los resultados de Future.wait.
      List<T> _parseResult<T>(dynamic result, T Function(Map<String, dynamic>) fromJson) {
        if (result is List) {
          return result.map((e) => fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      }

      return AnalysisData(
        expensePieData: _parseResult(results[0], ExpenseByCategory.fromMap),
        netWorthLineData: _parseResult(results[1], NetWorthDataPoint.fromJson),
        cashflowBarData: _parseResult(results[2], MonthlyCashflowData.fromJson),
        categoryComparisonData: _parseResult(results[3], CategorySpendingComparisonData.fromJson),
        incomePieData: _parseResult(results[4], IncomeByCategory.fromJson),
        incomeExpenseBarData: _parseResult(results[5], MonthlyIncomeExpenseSummaryData.fromJson),
        heatmapData: {
          if (results[6] is List)
            for (var item in (results[6] as List))
              // Parseo seguro con `tryParse` para evitar errores con formatos de fecha inesperados.
              if(DateTime.tryParse(item['day']) != null)
                DateTime.parse(item['day']): (item['net_amount'] as num).toInt()
        },
      );
      
    } catch (e, stackTrace) {
      developer.log("🔥 [Repo] ERROR CRÍTICO obteniendo datos de análisis: $e", name: 'AnalysisRepository', error: e, stackTrace: stackTrace);
      return AnalysisData.empty();
    }
  }
}