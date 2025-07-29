// lib/models/dashboard_data_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/transaction_models.dart';

/// Representa el conjunto completo de datos necesarios para el Dashboard.
///
/// Este modelo es inmutable y comparable gracias a `Equatable`.
/// Está diseñado para ser construido en dos etapas para una carga de UI más rápida:
/// 1. `DashboardData.fromPartialMap`: Crea el objeto con datos esenciales.
/// 2. `copyWithDetails`: Puebla el objeto con los datos más pesados.
class DashboardData extends Equatable {
  final double totalBalance;
  final String fullName;
  final List<Transaction> recentTransactions;
  final List<BudgetProgress> budgetsProgress;
  final List<BudgetProgress> featuredBudgets;
  final List<Goal> goals;
  final List<ExpenseByCategory> expenseSummaryForWidget;
  final bool isLoading;

  const DashboardData({
    required this.totalBalance,
    required this.fullName,
    required this.recentTransactions,
    required this.budgetsProgress,
    required this.featuredBudgets,
    required this.goals,
    required this.expenseSummaryForWidget,
    this.isLoading = false,
  });

  /// **ETAPA 1:** Crea una instancia con solo los datos esenciales.
  ///
  /// Las listas se inicializan vacías y `isLoading` se puede establecer en `true`
  /// para indicar que los detalles aún están en camino.
  factory DashboardData.fromPartialMap(Map<String, dynamic> map, {bool loadingDetails = true}) {
    return DashboardData(
      fullName: map['full_name'] as String? ?? 'Usuario',
      totalBalance: (map['total_balance'] as num?)?.toDouble() ?? 0.0,
      goals: const [],
      recentTransactions: const [],
      budgetsProgress: const [],
      featuredBudgets: const [],
      expenseSummaryForWidget: const [],
      isLoading: loadingDetails,
    );
  }

  /// **ETAPA 2:** Crea una copia del objeto actual, pero poblando las listas.
  ///
  /// Este método toma los datos detallados de la segunda llamada a la API
  /// y los usa para rellenar las listas, manteniendo los datos básicos ya cargados.
  /// `isLoading` se establece en `false` para indicar que la carga ha finalizado.
  DashboardData copyWithDetails(Map<String, dynamic> map) {
    return DashboardData(
      // Mantenemos los datos de la Etapa 1
      fullName: fullName,
      totalBalance: totalBalance,

      // Poblamos las listas desde el nuevo mapa de detalles
      goals: (map['goals'] as List<dynamic>?)
          ?.map((g) => Goal.fromMap(g as Map<String, dynamic>))
          .toList() ?? goals,
      recentTransactions: (map['recent_transactions'] as List<dynamic>?)
          ?.map((t) => Transaction.fromMap(t as Map<String, dynamic>)) 
        .toList() ?? recentTransactions,
      budgetsProgress: (map['budgets_progress'] as List<dynamic>?)
          ?.map((b) => BudgetProgress.fromMap(b as Map<String, dynamic>))
          .toList() ?? budgetsProgress,
      featuredBudgets: (map['featured_budgets'] as List<dynamic>?)
          ?.map((b) => BudgetProgress.fromMap(b as Map<String, dynamic>))
          .toList() ?? featuredBudgets,
      expenseSummaryForWidget: (map['expense_summary_for_widget'] as List<dynamic>?)
          ?.map((e) => ExpenseByCategory.fromJson(e as Map<String, dynamic>))
        .toList() ?? expenseSummaryForWidget,
      
      isLoading: false, // La carga ha terminado
    );
  }

  /// Crea una instancia "vacía" para el estado inicial o de carga.
  factory DashboardData.empty() {
    return const DashboardData(
      totalBalance: 0.0,
      fullName: 'Cargando...',
      recentTransactions: [],
      budgetsProgress: [],
      featuredBudgets: [],
      goals: [],
      expenseSummaryForWidget: [],
      isLoading: true,
    );
  }

  /// Método `copyWith` genérico para crear copias modificadas.
  /// No debe confundirse con `copyWithDetails`.
  DashboardData copyWith({
    double? totalBalance,
    String? fullName,
    List<Transaction>? recentTransactions,
    List<BudgetProgress>? budgetsProgress,
    List<BudgetProgress>? featuredBudgets,
    List<Goal>? goals,
    List<ExpenseByCategory>? expenseSummaryForWidget,
    bool? isLoading,
  }) {
    return DashboardData(
      totalBalance: totalBalance ?? this.totalBalance,
      fullName: fullName ?? this.fullName,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      budgetsProgress: budgetsProgress ?? this.budgetsProgress,
      featuredBudgets: featuredBudgets ?? this.featuredBudgets,
      goals: goals ?? this.goals,
      expenseSummaryForWidget: expenseSummaryForWidget ?? this.expenseSummaryForWidget,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // Las propiedades para que `Equatable` pueda comparar instancias.
  @override
  List<Object?> get props => [
        totalBalance,
        fullName,
        recentTransactions,
        budgetsProgress,
        featuredBudgets,
        goals,
        expenseSummaryForWidget,
        isLoading,
      ];
}