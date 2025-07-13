import 'transaction_models.dart';
import 'budget_models.dart';

class DashboardData {
  final double totalBalance;
  final String fullName;
  final List<Transaction> recentTransactions;
  final List<BudgetProgress> budgetsProgress;

  DashboardData({
    required this.totalBalance,
    required this.fullName,
    required this.recentTransactions,
    required this.budgetsProgress,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    return DashboardData(
      totalBalance: (json['total_balance'] as num? ?? 0).toDouble(),
      fullName: json['full_name'] as String? ?? 'Usuario',
      recentTransactions: (json['recent_transactions'] as List<dynamic>? ?? [])
          .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      budgetsProgress: (json['budgets_progress'] as List<dynamic>? ?? [])
          .map((e) => BudgetProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}