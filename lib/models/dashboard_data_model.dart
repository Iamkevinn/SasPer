// lib/models/dashboard_data_model.dart

import 'package:equatable/equatable.dart';
import 'transaction_models.dart';
import 'budget_models.dart';
import 'goal_model.dart';

class DashboardData extends Equatable {
  final double totalBalance;
  final String fullName;
  final List<Transaction> recentTransactions;
  final List<BudgetProgress> budgetsProgress;
  final List<Goal> goals;
  final bool isLoading; 

  const DashboardData({
    required this.totalBalance,
    required this.fullName,
    required this.recentTransactions,
    required this.budgetsProgress,
    required this.goals,
    this.isLoading = false,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    try {
      return DashboardData(
        totalBalance: (json['total_balance'] as num? ?? 0).toDouble(),
        fullName: json['full_name'] as String? ?? 'Usuario',
        recentTransactions: (json['recent_transactions'] as List<dynamic>? ?? [])
            .map((e) => Transaction.fromMap(e as Map<String, dynamic>))
            .toList(),
        budgetsProgress: (json['budgets_progress'] as List<dynamic>? ?? [])
            .map((e) => BudgetProgress.fromJson(e as Map<String, dynamic>))
            .toList(),
        goals: (json['goals'] as List<dynamic>? ?? [])
            .map((e) => Goal.fromMap(e as Map<String, dynamic>))
            .toList(),
        isLoading: false, // <-- LA CORRECCIÓN ESTÁ AQUÍ
      );
    } catch (e) {
      throw FormatException('Error al parsear DashboardData: $e', json);
    }
  }

  factory DashboardData.empty() {
    return const DashboardData(
      totalBalance: 0.0,
      fullName: 'Cargando...',
      recentTransactions: [],
      budgetsProgress: [],
      goals: [],
      isLoading: true,
    );
  }

  DashboardData copyWith({
    double? totalBalance,
    String? fullName,
    List<Transaction>? recentTransactions,
    List<BudgetProgress>? budgetsProgress,
    List<Goal>? goals,
    bool? isLoading,
  }) {
    return DashboardData(
      totalBalance: totalBalance ?? this.totalBalance,
      fullName: fullName ?? this.fullName,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      budgetsProgress: budgetsProgress ?? this.budgetsProgress,
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [
        totalBalance,
        fullName,
        recentTransactions,
        budgetsProgress,
        goals,
        isLoading,
      ];
}