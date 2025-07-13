// Este archivo contendrá las clases para tipar los datos de tus gráficos.
// Esto nos da seguridad de tipos y autocompletado.

// Modelo para el gráfico de pastel de gastos
class ExpenseByCategory {
  final String category;
  final double totalSpent;

  ExpenseByCategory({required this.category, required this.totalSpent});

  factory ExpenseByCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseByCategory(
      category: json['category'] as String? ?? 'Sin Categoría',
      totalSpent: (json['total_spent'] as num? ?? 0).toDouble(),
    );
  }
}

// Modelo para el gráfico de línea de patrimonio
class NetWorthDataPoint {
  final DateTime monthEnd;
  final double netWorth;

  NetWorthDataPoint({required this.monthEnd, required this.netWorth});

  factory NetWorthDataPoint.fromJson(Map<String, dynamic> json) {
    return NetWorthDataPoint(
      monthEnd: DateTime.tryParse((json['month_end']?.toString() ?? '1970-01') + '-01') ?? DateTime.now(),
      netWorth: (json['net_worth'] as num? ?? 0).toDouble(),
    );
  }
}

// Modelo para el gráfico de barras de Flujo de Caja
class MonthlyCashflowData {
  final DateTime monthStart;
  final double income;
  final double expense;
  final double cashFlow;

  MonthlyCashflowData({
    required this.monthStart,
    required this.income,
    required this.expense,
    required this.cashFlow,
  });

  factory MonthlyCashflowData.fromJson(Map<String, dynamic> json) {
    return MonthlyCashflowData(
      monthStart: DateTime.tryParse((json['month_start']?.toString() ?? '1970-01') + '-01') ?? DateTime.now(),
      income: (json['income'] as num? ?? 0).toDouble(),
      expense: (json['expense'] as num? ?? 0).toDouble(),
      cashFlow: (json['cash_flow'] as num? ?? 0).toDouble(),
    );
  }
}

// Modelo para el gráfico de comparación de gastos
class CategorySpendingComparisonData {
  final String category;
  final double currentMonthSpent;
  final double previousMonthSpent;

  CategorySpendingComparisonData({
    required this.category,
    required this.currentMonthSpent,
    required this.previousMonthSpent,
  });

  factory CategorySpendingComparisonData.fromJson(Map<String, dynamic> json) {
    return CategorySpendingComparisonData(
      category: json['category'] as String? ?? 'Sin Categoría',
      currentMonthSpent: (json['current_month_spent'] as num? ?? 0).toDouble(),
      previousMonthSpent: (json['previous_month_spent'] as num? ?? 0).toDouble(),
    );
  }
}

// Modelo para el gráfico de pastel de ingresos
class IncomeByCategory {
    final String category;
    final double totalIncome;

    IncomeByCategory({required this.category, required this.totalIncome});

    factory IncomeByCategory.fromJson(Map<String, dynamic> json) {
        return IncomeByCategory(
            category: json['category'] as String? ?? 'Sin Categoría',
            totalIncome: (json['total_income'] as num? ?? 0).toDouble(),
        );
    }
}

// Modelo para el gráfico de barras de Ingreso vs Gasto
class MonthlyIncomeExpenseSummaryData {
    final DateTime monthStart;
    final double totalIncome;
    final double totalExpense;

    MonthlyIncomeExpenseSummaryData({
        required this.monthStart,
        required this.totalIncome,
        required this.totalExpense,
    });

    factory MonthlyIncomeExpenseSummaryData.fromJson(Map<String, dynamic> json) {
        return MonthlyIncomeExpenseSummaryData(
            monthStart: DateTime.tryParse((json['month_start']?.toString() ?? '1970-01') + '-01') ?? DateTime.now(),
            totalIncome: (json['total_income'] as num? ?? 0).toDouble(),
            totalExpense: (json['total_expense'] as num? ?? 0).toDouble(),
        );
    }
}


// Un modelo contenedor para todos los datos del análisis.
class AnalysisData {
  final List<ExpenseByCategory> expensePieData;
  final List<NetWorthDataPoint> netWorthLineData;
  final List<MonthlyCashflowData> cashflowBarData;
  final List<CategorySpendingComparisonData> categoryComparisonData;
  final List<IncomeByCategory> incomePieData;
  final List<MonthlyIncomeExpenseSummaryData> incomeExpenseBarData;
  final Map<DateTime, int> heatmapData;

  AnalysisData({
    required this.expensePieData,
    required this.netWorthLineData,
    required this.cashflowBarData,
    required this.categoryComparisonData,
    required this.incomePieData,
    required this.incomeExpenseBarData,
    required this.heatmapData,
  });
}