// lib/models/dashboard_data_model.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'transaction_models.dart';
import 'budget_models.dart';
import 'goal_model.dart';

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

  factory DashboardData.fromMap(Map<String, dynamic> map) {
    // --- AÑADIMOS PRINT DE DEBUG ---
    if (kDebugMode) {
      print('DEBUG [DashboardData.fromMap]: Mapa recibido: $map');
    }
    if (kDebugMode) {
      print('DEBUG [DashboardData.fromMap]: Tipo de budgets_progress: ${map['budgets_progress'].runtimeType}');
    }
    
    try {
      return DashboardData(
        totalBalance: (map['total_balance'] as num? ?? 0).toDouble(),
        fullName: map['full_name'] as String? ?? 'Usuario',
        recentTransactions: (map['recent_transactions'] as List<dynamic>? ?? [])
            .map((e) => Transaction.fromMap(e as Map<String, dynamic>))
            .toList(),
        // --- Usamos el nuevo nombre del método: BudgetProgress.fromMap ---
        budgetsProgress: (map['budgets_progress'] as List<dynamic>? ?? [])
            .map((e) => BudgetProgress.fromMap(e as Map<String, dynamic>))
            .toList(),
        goals: (map['goals'] as List<dynamic>? ?? [])
            .map((e) => Goal.fromMap(e as Map<String, dynamic>))
            .toList(),
         // --- 3. AÑADE EL MAPEO PARA LA NUEVA LISTA ---
        featuredBudgets: (map['featured_budgets'] as List<dynamic>? ?? [])
            .map((e) => BudgetProgress.fromMap(e as Map<String, dynamic>))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔥 ERROR en DashboardData.fromMap: $e, Mapa: $map');
      }
      throw FormatException('Error al parsear DashboardData: $e', map);
    }
  }

  factory DashboardData.empty() {
    return const DashboardData(
      totalBalance: 0.0,
      fullName: 'Cargando...',
      recentTransactions: [],
      budgetsProgress: [],
      goals: [],
      featuredBudgets: [],
      isLoading: true,
    );
  }

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