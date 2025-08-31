// lib/models/dashboard_data_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/models/budget_models.dart'; // Mantiene la importación, pero ahora importa la clase `Budget`
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/transaction_models.dart';

// --- NUEVA CLASE PARA LOS DATOS DEL GRÁFICO ---
class CategorySpending {
  final String categoryName;
  final double totalAmount;
  final String color; // Guardaremos el color de la categoría

  CategorySpending({
    required this.categoryName,
    required this.totalAmount,
    required this.color,
  });
}

/// Representa el conjunto completo de datos necesarios para el Dashboard.
class DashboardData extends Equatable {
  final double totalBalance;
  final String fullName;
  final List<Transaction> recentTransactions;
  // --- ¡CORRECCIÓN! Cambiamos BudgetProgress a Budget ---
  final List<Budget> budgets; 
  final List<Budget> featuredBudgets;
  final List<Goal> goals;
  final List<ExpenseByCategory> expenseSummaryForWidget;
  final bool isLoading;
  final List<CategorySpending> categorySpendingSummary;

  const DashboardData({
    required this.totalBalance,
    required this.fullName,
    required this.recentTransactions,
    required this.budgets, // Corregido
    required this.featuredBudgets,
    required this.goals,
    required this.expenseSummaryForWidget,
    this.isLoading = false,
    this.categorySpendingSummary = const [],
  });

  /// **ETAPA 1:** Crea una instancia con solo los datos esenciales.
  factory DashboardData.fromPartialMap(Map<String, dynamic> map, {bool loadingDetails = true}) {
    return DashboardData(
      fullName: map['full_name'] as String? ?? 'Usuario',
      totalBalance: (map['total_balance'] as num?)?.toDouble() ?? 0.0,
      goals: const [],
      recentTransactions: const [],
      budgets: const [], // Corregido
      featuredBudgets: const [],
      expenseSummaryForWidget: const [],
      isLoading: loadingDetails,
      categorySpendingSummary: [],
    );
  }

  /// **ETAPA 2:** Crea una copia del objeto actual, pero poblando las listas.
   DashboardData copyWithDetails(Map<String, dynamic> map) {
    // Parsea la lista completa de presupuestos.
    // ¡CORRECCIÓN! Usa el nuevo `Budget.fromMap`.
    final List<Budget> allBudgets = (map['budgets_progress'] as List<dynamic>?)
        ?.map((b) => Budget.fromMap(b as Map<String, dynamic>))
        .toList() ?? budgets; // Usa la lista vieja como fallback

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
      
      budgets: allBudgets, // ¡CORRECCIÓN! Guardamos la lista completa en `budgets`
      
      // La lógica para destacar presupuestos ahora filtra los que están activos y toma los 2 primeros.
      featuredBudgets: allBudgets.where((b) => b.isActive).take(2).toList(),
      
      expenseSummaryForWidget: (map['expense_summary_for_widget'] as List<dynamic>?)
          ?.map((e) => ExpenseByCategory.fromMap(e as Map<String, dynamic>))
          .toList() ?? expenseSummaryForWidget,
      
      isLoading: false, 
      categorySpendingSummary: [], // La carga ha terminado
    );
  }

  /// Crea una instancia "vacía" para el estado inicial o de carga.
  factory DashboardData.empty() {
    return const DashboardData(
      totalBalance: 0.0,
      fullName: 'Cargando...',
      recentTransactions: [],
      budgets: [], // Corregido
      featuredBudgets: [],
      goals: [],
      expenseSummaryForWidget: [],
      isLoading: true, 
      categorySpendingSummary: [],
    );
  }

  /// Método `copyWith` genérico para crear copias modificadas.
  DashboardData copyWith({
    double? totalBalance,
    String? fullName,
    List<Transaction>? recentTransactions,
    List<Budget>? budgets,
    List<Budget>? featuredBudgets,
    List<Goal>? goals,
    List<ExpenseByCategory>? expenseSummaryForWidget,
    bool? isLoading,
    List<CategorySpending>? categorySpendingSummary, // <-- Parámetro añadido
  }) {
    return DashboardData(
      totalBalance: totalBalance ?? this.totalBalance,
      fullName: fullName ?? this.fullName,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      budgets: budgets ?? this.budgets, // Corregido
      featuredBudgets: featuredBudgets ?? this.featuredBudgets,
      goals: goals ?? this.goals,
      expenseSummaryForWidget: expenseSummaryForWidget ?? this.expenseSummaryForWidget,
      isLoading: isLoading ?? this.isLoading, 
      categorySpendingSummary: categorySpendingSummary ?? this.categorySpendingSummary, 
    );
  }

  // Las propiedades para que `Equatable` pueda comparar instancias.
  @override
  List<Object?> get props => [
        totalBalance,
        fullName,
        recentTransactions,
        budgets, // Corregido
        featuredBudgets,
        goals,
        expenseSummaryForWidget,
        isLoading,
        categorySpendingSummary,
      ];
}