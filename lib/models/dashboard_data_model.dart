// lib/models/dashboard_data_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/transaction_models.dart';

class CategorySpending {
  final String categoryName;
  final double totalAmount;
  final String color;

  CategorySpending({
    required this.categoryName,
    required this.totalAmount,
    required this.color,
  });
}

class DashboardAlert extends Equatable {
  final String id;
  final String type;
  final String message;

  const DashboardAlert({
    required this.id,
    required this.type,
    required this.message,
  });

  factory DashboardAlert.fromMap(Map<String, dynamic> map) {
    return DashboardAlert(
      id: map['id'] as String? ?? '',
      type: map['type'] as String? ?? 'general',
      message: map['message'] as String? ?? 'Alerta no especificada',
    );
  }
  
  @override
  List<Object?> get props => [id, type, message];
}

class DashboardData extends Equatable {
  final double totalBalance;    // Activos Totales (Bancos)
  final double availableBalance; // Disponible Real (Operativo)
  final double totalDebt;       // Pasivos Totales
  
  // --- 👇 NUEVAS VARIABLES DE DESGLOSE ---
  final double savingsBalance;   // Dinero en Metas (Voluntario)
  final double obligatedBalance; // Dinero de Préstamos Restringidos (Obligatorio)
  final double netWorth;         // Patrimonio Neto (Activos - Pasivos)
  // ---------------------------------------

  final String fullName;
  final double healthScore;
  final List<DashboardAlert> alerts;
  final List<Transaction> recentTransactions;
  final List<Budget> budgets;
  final List<Budget> featuredBudgets;
  final List<Goal> goals;
  final List<ExpenseByCategory> expenseSummaryForWidget;
  final bool isLoading;
  final List<CategorySpending> categorySpendingSummary;
  final double monthlyProjection;

  // Getter auxiliar para compatibilidad si usabas restrictedBalance antes
  double get restrictedBalance => savingsBalance + obligatedBalance;

  const DashboardData({
    required this.totalBalance,
    required this.availableBalance,
    required this.savingsBalance,   // NUEVO
    required this.obligatedBalance, // NUEVO
    required this.netWorth,         // NUEVO
    required this.totalDebt,
    required this.fullName,
    required this.healthScore,
    required this.alerts,
    required this.recentTransactions,
    required this.budgets,
    required this.featuredBudgets,
    required this.goals,
    required this.expenseSummaryForWidget,
    this.isLoading = false,
    this.categorySpendingSummary = const [],
    required this.monthlyProjection,
  });

  factory DashboardData.fromPartialMap(Map<String, dynamic> map, {bool loadingDetails = true}) {
    final tBalance = (map['total_balance'] as num?)?.toDouble() ?? 0.0;
    
    return DashboardData(
      fullName: map['full_name'] as String? ?? 'Usuario',
      totalBalance: tBalance,
      availableBalance: tBalance,
      
      savingsBalance: 0.0,    // Inicializar en 0
      obligatedBalance: 0.0,  // Inicializar en 0
      netWorth: tBalance,     // Inicialmente Patrimonio = Activos (asumiendo deuda 0)
      totalDebt: 0.0,
      
      healthScore: (map['health_score'] as num?)?.toDouble() ?? 0.0,
      monthlyProjection: (map['monthly_projection'] as num?)?.toDouble() ?? 0.0,
      alerts: const [],
      goals: const [],
      recentTransactions: const [],
      budgets: const [],
      featuredBudgets: const [],
      expenseSummaryForWidget: const [],
      isLoading: loadingDetails,
      categorySpendingSummary: const [],
    );
  }

  DashboardData copyWithDetails(Map<String, dynamic> map) {
    final List<Budget> allBudgets = (map['budgets_progress'] as List<dynamic>?)
        ?.map((b) => Budget.fromMap(b as Map<String, dynamic>))
        .toList() ?? budgets;

    return DashboardData(
      fullName: fullName,
      totalBalance: totalBalance,
      
      // Mapeamos los nuevos campos
      availableBalance: (map['available_balance'] as num?)?.toDouble() ?? availableBalance,
      savingsBalance: (map['savings_balance'] as num?)?.toDouble() ?? savingsBalance,
      obligatedBalance: (map['obligated_balance'] as num?)?.toDouble() ?? obligatedBalance,
      netWorth: (map['net_worth'] as num?)?.toDouble() ?? netWorth,
      totalDebt: (map['total_debt'] as num?)?.toDouble() ?? totalDebt,
      
      healthScore: (map['health_score'] as num?)?.toDouble() ?? healthScore,
      monthlyProjection: (map['monthly_projection'] as num?)?.toDouble() ?? monthlyProjection,
      
      alerts: (map['alerts'] as List<dynamic>?)
          ?.map((a) => DashboardAlert.fromMap(a as Map<String, dynamic>))
          .toList() ?? alerts,

      goals: (map['goals'] as List<dynamic>?)
          ?.map((g) => Goal.fromMap(g as Map<String, dynamic>))
          .toList() ?? goals,
      
      recentTransactions: (map['recent_transactions'] as List<dynamic>?)
          ?.map((t) => Transaction.fromMap(t as Map<String, dynamic>)) 
          .toList() ?? recentTransactions,
      
      budgets: allBudgets,
      featuredBudgets: allBudgets.where((b) => b.isActive).take(2).toList(),
      expenseSummaryForWidget: (map['expense_summary_for_widget'] as List<dynamic>?)
          ?.map((e) => ExpenseByCategory.fromMap(e as Map<String, dynamic>))
          .toList() ?? expenseSummaryForWidget,
      
      isLoading: false, 
      categorySpendingSummary: const [],
    );
  }

  factory DashboardData.empty() {
    return const DashboardData(
      totalBalance: 0.0,
      availableBalance: 0.0,
      savingsBalance: 0.0,
      obligatedBalance: 0.0,
      netWorth: 0.0,
      totalDebt: 0.0,
      fullName: 'Cargando...',
      healthScore: 0.0,
      monthlyProjection: 0.0,
      alerts: [],
      recentTransactions: [],
      budgets: [],
      featuredBudgets: [],
      goals: [],
      expenseSummaryForWidget: [],
      isLoading: true, 
      categorySpendingSummary: [],
    );
  }

  DashboardData copyWith({
    double? totalBalance,
    double? availableBalance,
    double? savingsBalance,   // NUEVO
    double? obligatedBalance, // NUEVO
    double? netWorth,         // NUEVO
    double? totalDebt,
    String? fullName,
    double? healthScore,
    List<DashboardAlert>? alerts,
    List<Transaction>? recentTransactions,
    List<Budget>? budgets,
    List<Budget>? featuredBudgets,
    List<Goal>? goals,
    List<ExpenseByCategory>? expenseSummaryForWidget,
    bool? isLoading,
    List<CategorySpending>? categorySpendingSummary,
    double? monthlyProjection,
  }) {
    return DashboardData(
      totalBalance: totalBalance ?? this.totalBalance,
      availableBalance: availableBalance ?? this.availableBalance,
      savingsBalance: savingsBalance ?? this.savingsBalance,
      obligatedBalance: obligatedBalance ?? this.obligatedBalance,
      netWorth: netWorth ?? this.netWorth,
      totalDebt: totalDebt ?? this.totalDebt,
      fullName: fullName ?? this.fullName,
      healthScore: healthScore ?? this.healthScore,
      alerts: alerts ?? this.alerts,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      budgets: budgets ?? this.budgets,
      featuredBudgets: featuredBudgets ?? this.featuredBudgets,
      goals: goals ?? this.goals,
      expenseSummaryForWidget: expenseSummaryForWidget ?? this.expenseSummaryForWidget,
      isLoading: isLoading ?? this.isLoading, 
      categorySpendingSummary: categorySpendingSummary ?? this.categorySpendingSummary, 
      monthlyProjection: monthlyProjection ?? this.monthlyProjection,
    );
  }

  @override
  List<Object?> get props => [
        totalBalance,
        availableBalance,
        savingsBalance,
        obligatedBalance,
        netWorth,
        totalDebt,
        fullName,
        healthScore,
        alerts,
        recentTransactions,
        budgets,
        featuredBudgets,
        goals,
        expenseSummaryForWidget,
        isLoading,
        categorySpendingSummary,
        monthlyProjection,
      ];
}