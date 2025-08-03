// lib/data/analysis_repository.dart

import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/analysis_models.dart';

class AnalysisRepository {
  // 1. Mantenemos el cliente 'late final' para una inicialización segura.
  late final SupabaseClient _client;

  // 2. Constructor privado.
  AnalysisRepository._privateConstructor();

  // 3. Instancia estática.
  static final AnalysisRepository instance = AnalysisRepository._privateConstructor();

  // 4. Método de inicialización, igual que en los otros repositorios.
  void initialize(SupabaseClient client) {
    _client = client;
  }

  /// Obtiene solo el resumen de gastos, ideal para widgets o cargas rápidas.
  Future<List<ExpenseByCategory>> getExpenseSummaryForWidget() async {
    developer.log("📈 [Repository] Fetching expense summary for widget...", name: 'AnalysisRepository');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return [];

      final clientDate = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final result = await _client.rpc(
        'get_expense_summary_by_category', 
        params: {'p_user_id': userId, 'client_date': clientDate}
      );
      
      return (result as List).map((e) => ExpenseByCategory.fromJson(e)).toList();

    } catch (e) {
      developer.log('🔥 Error en getExpenseSummaryForWidget: $e', name: 'AnalysisRepository');
      return [];
    }
  }
  
  /// Obtiene el conjunto completo de datos para la pantalla de análisis.
  Future<AnalysisData> fetchAllAnalysisData() async {
    developer.log("📈 [Repository] Fetching all analysis data...", name: 'AnalysisRepository');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return AnalysisData.empty();
      }

      final today = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 120)));
      final endDate = DateFormat('yyyy-MM-dd').format(today);
      final clientDate = DateFormat('yyyy-MM-dd').format(today);

      // Usamos Future.wait para eficiencia.
      // El parseo ahora es seguro gracias a la corrección en la pantalla.
      final results = await Future.wait([
        _client.rpc('get_expense_summary_by_category', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) => []),
        _client.rpc('get_net_worth_trend', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) => []),
        _client.rpc('get_monthly_cash_flow', params: {'p_user_id': userId}).catchError((e) => []),
        _client.rpc('get_category_spending_comparison', params: {'p_user_id': userId}).catchError((e) => []),
        _client.rpc('get_income_summary_by_category', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) => []),
        _client.rpc('get_monthly_income_expense_summary', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) => []),
        _client.rpc('get_daily_net_flow', params: {'p_user_id': userId, 'start_date': startDate, 'end_date': endDate}).catchError((e) => []),
      ]);
      
      // Parseo seguro (asumiendo que la UI ya comprueba si las listas están vacías)
      List<T> _parseResult<T>(int index, T Function(Map<String, dynamic>) fromJson) {
        if (index < results.length && results[index] is List) {
          return (results[index] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      }

      return AnalysisData(
        expensePieData: _parseResult(0, ExpenseByCategory.fromJson),
        netWorthLineData: _parseResult(1, NetWorthDataPoint.fromJson),
        cashflowBarData: _parseResult(2, MonthlyCashflowData.fromJson),
        categoryComparisonData: _parseResult(3, CategorySpendingComparisonData.fromJson),
        incomePieData: _parseResult(4, IncomeByCategory.fromJson),
        incomeExpenseBarData: _parseResult(5, MonthlyIncomeExpenseSummaryData.fromJson),
        heatmapData: {
          if (6 < results.length && results[6] is List)
            for (var item in (results[6] as List))
              DateTime.parse(item['day']): (item['net_amount'] as num).toInt()
        },
      );
      
    } catch (e, stackTrace) {
      developer.log("🔥 [Repository] CRITICAL ERROR fetching data: $e", name: 'AnalysisRepository', error: e, stackTrace: stackTrace);
      return AnalysisData.empty();
    }
  }
}