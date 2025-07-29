// lib/data/analysis_repository.dart

import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/analysis_models.dart';

class AnalysisRepository {
  // 1. Cliente 'late final'.
  late final SupabaseClient _client;

  // 2. Constructor privado.
  AnalysisRepository._privateConstructor();

  // 3. Instancia estática.
  static final AnalysisRepository instance = AnalysisRepository._privateConstructor();

  // 4. Método de inicialización.
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
  /// Ejecuta todas las consultas en paralelo y maneja errores individuales.
  Future<AnalysisData> fetchAllAnalysisData() async {
    developer.log("📈 [Repository] Fetching all analysis data...", name: 'AnalysisRepository');
    try {
      final today = DateTime.now();
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        developer.log("⚠️ [Repository] No user ID found, returning empty analysis data.", name: 'AnalysisRepository');
        return AnalysisData.empty();
      }

      final startDate = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 120)));
      final endDate = DateFormat('yyyy-MM-dd').format(today);
      final clientDate = DateFormat('yyyy-MM-dd').format(today);

      final results = await Future.wait([
        _client.rpc('get_expense_summary_by_category', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) {
          developer.log('🔥 Error en get_expense_summary_by_category: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_net_worth_trend', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) {
          developer.log('🔥 Error en get_net_worth_trend: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_monthly_cash_flow', params: {'p_user_id': userId}).catchError((e) {
          developer.log('🔥 Error en get_monthly_cash_flow: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_category_spending_comparison', params: {'p_user_id': userId}).catchError((e) {
          developer.log('🔥 Error en get_category_spending_comparison: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_income_summary_by_category', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) {
          developer.log('🔥 Error en get_income_summary_by_category: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_monthly_income_expense_summary', params: {'p_user_id': userId, 'client_date': clientDate}).catchError((e) {
          developer.log('🔥 Error en get_monthly_income_expense_summary: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_daily_net_flow', params: {'p_user_id': userId, 'start_date': startDate, 'end_date': endDate}).catchError((e) {
          developer.log('🔥 Error en get_daily_net_flow: $e', name: 'AnalysisRepository');
          return [];
        }),
      ]);

      final analysisData = AnalysisData(
        expensePieData: (results[0] as List).map((e) => ExpenseByCategory.fromJson(e)).toList(),
        netWorthLineData: (results[1] as List).map((e) => NetWorthDataPoint.fromJson(e)).toList(),
        cashflowBarData: (results[2] as List).map((e) => MonthlyCashflowData.fromJson(e)).toList(),
        categoryComparisonData: (results[3] as List).map((e) => CategorySpendingComparisonData.fromJson(e)).toList(),
        incomePieData: (results[4] as List).map((e) => IncomeByCategory.fromJson(e)).toList(),
        incomeExpenseBarData: (results[5] as List).map((e) => MonthlyIncomeExpenseSummaryData.fromJson(e)).toList(),
        heatmapData: {
          for (var item in (results[6] as List))
            DateTime.parse(item['day']): (item['net_amount'] as num).toInt()
        },
      );
      
      developer.log("✅ [Repository] Data fetched and parsed successfully.", name: 'AnalysisRepository');
      return analysisData;

    } catch (e, stackTrace) {
      developer.log("🔥 [Repository] CRITICAL ERROR fetching data: $e", name: 'AnalysisRepository', error: e, stackTrace: stackTrace);
      return AnalysisData.empty();
    }
  }
}