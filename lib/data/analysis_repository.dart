import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analysis_models.dart';

class AnalysisRepository {
  final SupabaseClient _client;

  // 1. INYECTAMOS LA DEPENDENCIA para facilitar los tests.
  AnalysisRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<AnalysisData> fetchAllAnalysisData() async {
    developer.log("📈 [Repository] Fetching all analysis data...", name: 'AnalysisRepository');
    try {
      final today = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 120)));
      final endDate = DateFormat('yyyy-MM-dd').format(today);
      final clientDate = DateFormat('yyyy-MM-dd').format(today);

      // 2. HACEMOS LAS LLAMADAS RESILIENTES. Si una falla, no rompe todo.
      final results = await Future.wait([
        _client.rpc('get_expense_summary_by_category').catchError((e) {
          developer.log('🔥 Error en get_expense_summary_by_category: $e', name: 'AnalysisRepository');
          return []; // Devuelve un valor por defecto en caso de error
        }),
        _client.rpc('get_net_worth_trend', params: {'client_date': clientDate}).catchError((e) {
          developer.log('🔥 Error en get_net_worth_trend: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_monthly_cash_flow').catchError((e) {
          developer.log('🔥 Error en get_monthly_cash_flow: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_category_spending_comparison').catchError((e) {
          developer.log('🔥 Error en get_category_spending_comparison: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_income_summary_by_category').catchError((e) {
          developer.log('🔥 Error en get_income_summary_by_category: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_monthly_income_expense_summary', params: {'client_date': clientDate}).catchError((e) {
          developer.log('🔥 Error en get_monthly_income_expense_summary: $e', name: 'AnalysisRepository');
          return [];
        }),
        _client.rpc('get_daily_net_flow', params: {'start_date': startDate, 'end_date': endDate}).catchError((e) {
          developer.log('🔥 Error en get_daily_net_flow: $e', name: 'AnalysisRepository');
          return [];
        }),
      ]);

      // El parseo no necesita cambios, ya que ahora simplemente recibirá listas vacías en caso de fallo.
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
      
      developer.log("✅ [Repository] Data fetched and parsed successfully (some parts may be empty due to errors).", name: 'AnalysisRepository');
      return analysisData;

    } catch (e, stackTrace) {
      // Este catch ahora solo se activará si hay un error muy grave que no sea de una RPC individual.
      developer.log("🔥 [Repository] CRITICAL ERROR fetching data: $e", name: 'AnalysisRepository', error: e, stackTrace: stackTrace);
      // En lugar de rethrow, devolvemos un estado vacío para que la UI no se rompa.
      return AnalysisData.empty();
    }
  }
}