// lib/models/dashboard_data_model.dart (VERSIÓN FINAL Y LIMPIA)

import 'package:equatable/equatable.dart';
import 'transaction_models.dart';
import 'budget_models.dart';
import 'goal_model.dart';
import 'analysis_models.dart';

/// Representa todos los datos necesarios para construir la pantalla del Dashboard.
class DashboardData extends Equatable {
  final double totalBalance;
  final String fullName;
  final List<Transaction> recentTransactions;
  final List<BudgetProgress> budgetsProgress;
  final List<BudgetProgress> featuredBudgets; 
  final List<Goal> goals;
  final bool isLoading; 

  const DashboardData({
    required this.totalBalance,
    required this.fullName,
    required this.recentTransactions,
    required this.budgetsProgress,
    required this.featuredBudgets,
    required this.goals,
    this.isLoading = false,
  });

  /// Crea una instancia de [DashboardData] a partir de un mapa JSON (generalmente de una API).
  factory DashboardData.fromMap(Map<String, dynamic> map) {
    try {
      return DashboardData(
        totalBalance: (map['total_balance'] as num? ?? 0).toDouble(),
        fullName: map['full_name'] as String? ?? 'Usuario',
        recentTransactions: (map['recent_transactions'] as List<dynamic>? ?? [])
            .map((e) => Transaction.fromMap(e as Map<String, dynamic>))
            .toList(),
        budgetsProgress: (map['budgets_progress'] as List<dynamic>? ?? [])
            .map((e) => BudgetProgress.fromMap(e as Map<String, dynamic>))
            .toList(),
        featuredBudgets: (map['featured_budgets'] as List<dynamic>? ?? [])
            .map((e) => BudgetProgress.fromMap(e as Map<String, dynamic>))
            .toList(),
        goals: (map['goals'] as List<dynamic>? ?? [])
            .map((e) => Goal.fromMap(e as Map<String, dynamic>))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      // relanzar el error ayuda a la depuración, pero se puede quitar en producción
      // si se quiere que la app no crashee por datos malformados.
      rethrow; 
    }
  }

  /// Crea una instancia "vacía" o de carga de [DashboardData].
  factory DashboardData.empty() {
    return const DashboardData(
      totalBalance: 0.0,
      fullName: 'Cargando...',
      recentTransactions: [],
      budgetsProgress: [],
      featuredBudgets: [],
      goals: [],
      isLoading: true,
    );
  }

  /// Crea una copia del objeto actual con los valores proporcionados.
  DashboardData copyWith({
    double? totalBalance,
    String? fullName,
    List<Transaction>? recentTransactions,
    List<BudgetProgress>? budgetsProgress,
    List<BudgetProgress>? featuredBudgets,
    List<Goal>? goals,
    bool? isLoading,
  }) {
    return DashboardData(
      totalBalance: totalBalance ?? this.totalBalance,
      fullName: fullName ?? this.fullName,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      budgetsProgress: budgetsProgress ?? this.budgetsProgress,
      featuredBudgets: featuredBudgets ?? this.featuredBudgets,
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
        featuredBudgets,
        goals,
        isLoading,
      ];
}