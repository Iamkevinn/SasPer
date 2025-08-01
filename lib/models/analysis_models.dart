// lib/models/analysis_models.dart
import 'package:equatable/equatable.dart';

// --- MODELOS INDIVIDUALES PARA CADA GRÁFICO ---

// Usamos el mixin Equatable en lugar de extenderlo para clases más simples.
class ExpenseByCategory with EquatableMixin {
  final String category;
  final double totalSpent;

  const ExpenseByCategory({required this.category, required this.totalSpent});

  factory ExpenseByCategory.fromJson(Map<String, dynamic> json) {
    try {
      return ExpenseByCategory(
        category: json['category'] as String? ?? 'Sin Categoría',
        totalSpent: (json['total_spent'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      throw FormatException('Error al parsear ExpenseByCategory: $e', json);
    }
  }

  @override
  List<Object?> get props => [category, totalSpent];
}

class NetWorthDataPoint with EquatableMixin {
  final DateTime monthEnd;
  final double totalBalance;

  const NetWorthDataPoint({required this.monthEnd, required this.totalBalance});

  factory NetWorthDataPoint.fromJson(Map<String, dynamic> json) {
    try {
      return NetWorthDataPoint(
        monthEnd: DateTime.parse(json['month_end_text'] as String),
        totalBalance: (json['total_balance'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      throw FormatException('Error al parsear NetWorthDataPoint: $e', json);
    }
  }

  @override
  List<Object?> get props => [monthEnd, totalBalance];
}

class MonthlyCashflowData with EquatableMixin {
  final DateTime monthStart;
  final double income;
  final double expense;
  final double cashFlow;

  const MonthlyCashflowData({
    required this.monthStart,
    required this.income,
    required this.expense,
    required this.cashFlow,
  });

  factory MonthlyCashflowData.fromJson(Map<String, dynamic> json) {
    try {
      return MonthlyCashflowData(
        monthStart: DateTime.parse(json['month_start'] as String),
        income: (json['total_income'] as num? ?? 0).toDouble(),
        expense: (json['total_expense'] as num? ?? 0).toDouble(),
        cashFlow: (json['cash_flow'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      throw FormatException('Error al parsear MonthlyCashflowData: $e', json);
    }
  }
  
  @override
  List<Object?> get props => [monthStart, income, expense, cashFlow];
}

class CategorySpendingComparisonData with EquatableMixin {
  final String category;
  final double currentMonthSpent;
  final double previousMonthSpent;

  const CategorySpendingComparisonData({
    required this.category,
    required this.currentMonthSpent,
    required this.previousMonthSpent,
  });

  factory CategorySpendingComparisonData.fromJson(Map<String, dynamic> json) {
    try {
      return CategorySpendingComparisonData(
        category: json['category'] as String? ?? 'Sin Categoría',
        currentMonthSpent: (json['current_month_spent'] as num? ?? 0).toDouble(),
        previousMonthSpent: (json['previous_month_spent'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      throw FormatException('Error al parsear CategorySpendingComparisonData: $e', json);
    }
  }
  
  @override
  List<Object?> get props => [category, currentMonthSpent, previousMonthSpent];
}

class IncomeByCategory with EquatableMixin {
    final String category;
    final double totalIncome;

    const IncomeByCategory({required this.category, required this.totalIncome});

    factory IncomeByCategory.fromJson(Map<String, dynamic> json) {
      try {
        return IncomeByCategory(
            category: json['category'] as String? ?? 'Sin Categoría',
            totalIncome: (json['total_income'] as num? ?? 0).toDouble(),
        );
      } catch (e) {
        throw FormatException('Error al parsear IncomeByCategory: $e', json);
      }
    }

    @override
    List<Object?> get props => [category, totalIncome];
}

class MonthlyIncomeExpenseSummaryData with EquatableMixin {
    final DateTime monthStart;
    final double totalIncome;
    final double totalExpense;

    const MonthlyIncomeExpenseSummaryData({
        required this.monthStart,
        required this.totalIncome,
        required this.totalExpense,
    });

    factory MonthlyIncomeExpenseSummaryData.fromJson(Map<String, dynamic> json) {
      try {
        return MonthlyIncomeExpenseSummaryData(
            monthStart: DateTime.parse(json['month_start'] as String),
            totalIncome: (json['total_income'] as num? ?? 0).toDouble(),
            totalExpense: (json['total_expense'] as num? ?? 0).toDouble(),
        );
      } catch (e) {
        throw FormatException('Error al parsear MonthlyIncomeExpenseSummaryData: $e', json);
      }
    }

    @override
    List<Object?> get props => [monthStart, totalIncome, totalExpense];
}


// --- MODELO CONTENEDOR PRINCIPAL ---

class AnalysisData extends Equatable {
  final List<ExpenseByCategory> expensePieData;
  final List<NetWorthDataPoint> netWorthLineData;
  final List<MonthlyCashflowData> cashflowBarData;
  final List<CategorySpendingComparisonData> categoryComparisonData;
  final List<IncomeByCategory> incomePieData;
  final List<MonthlyIncomeExpenseSummaryData> incomeExpenseBarData;
  final Map<DateTime, int> heatmapData;

  const AnalysisData({
    required this.expensePieData,
    required this.netWorthLineData,
    required this.cashflowBarData,
    required this.categoryComparisonData,
    required this.incomePieData,
    required this.incomeExpenseBarData,
    required this.heatmapData,
  });

  // Constructor "vacío" para usar en estados iniciales o de carga.
  // Esto es muy útil para evitar nulos en la UI.
  factory AnalysisData.empty() {
    return const AnalysisData(
      expensePieData: [],
      netWorthLineData: [],
      cashflowBarData: [],
      categoryComparisonData: [],
      incomePieData: [],
      incomeExpenseBarData: [],
      heatmapData: {},
    );
  }

  @override
  List<Object?> get props => [
        expensePieData,
        netWorthLineData,
        cashflowBarData,
        categoryComparisonData,
        incomePieData,
        incomeExpenseBarData,
        heatmapData,
      ];
}