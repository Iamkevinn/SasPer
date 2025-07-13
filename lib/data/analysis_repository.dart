import 'dart:developer' as developer;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/analysis_models.dart';

class AnalysisRepository {
  final SupabaseClient _client = Supabase.instance.client;

  Future<AnalysisData> fetchAllAnalysisData() async {
    developer.log("📈 [Repository] Fetching all analysis data...", name: 'AnalysisRepository');
    try {
      final today = DateTime.now();
      final startDate = DateFormat('yyyy-MM-dd').format(today.subtract(const Duration(days: 120)));
      final endDate = DateFormat('yyyy-MM-dd').format(today);
      final clientDate = DateFormat('yyyy-MM-dd').format(today);

      // Llamadas en paralelo, una sola vez.
      final results = await Future.wait([
        _client.rpc('get_expense_summary_by_category'),
        _client.rpc('get_net_worth_trend', params: {'client_date': clientDate}),
        _client.rpc('get_monthly_cash_flow'),
        _client.rpc('get_category_spending_comparison'),
        _client.rpc('get_income_summary_by_category'),
        _client.rpc('get_monthly_income_expense_summary', params: {'client_date': clientDate}),
        _client.rpc('get_daily_net_flow', params: {'start_date': startDate, 'end_date': endDate}),
      ]);

      // Parseo seguro y fuertemente tipado.
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
      developer.log("🔥 [Repository] ERROR fetching data: $e", name: 'AnalysisRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}