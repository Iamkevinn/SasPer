// lib/models/simulation_models.dart

// Para el veredicto general
enum SimulationVerdict { recommended, withCaution, notRecommended }

// Representa el resultado completo de la simulación
class SimulationResult {
  final SimulationVerdict verdict;
  final String verdictMessage;
  final BudgetImpact? budgetImpact; // Puede ser nulo si no hay presupuesto
  final SavingsImpact savingsImpact;

  SimulationResult({
    required this.verdict,
    required this.verdictMessage,
    this.budgetImpact,
    required this.savingsImpact,
  });

  factory SimulationResult.fromMap(Map<String, dynamic> map) {
    SimulationVerdict parsedVerdict;
    switch (map['verdict'] as String?) {
      case 'recommended':
        parsedVerdict = SimulationVerdict.recommended;
        break;
      case 'with_caution':
        parsedVerdict = SimulationVerdict.withCaution;
        break;
      default:
        parsedVerdict = SimulationVerdict.notRecommended;
    }

    return SimulationResult(
      verdict: parsedVerdict,
      verdictMessage: map['verdictMessage'] as String,
      budgetImpact: map['budgetImpact'] != null
          ? BudgetImpact.fromMap(map['budgetImpact'])
          : null,
      savingsImpact: SavingsImpact.fromMap(map['savingsImpact']),
    );
  }
}

// Representa el impacto en un presupuesto específico
class BudgetImpact {
  final String categoryName;
  final double budgetAmount;
  final double currentSpent;
  final double projectedSpent;
  final bool willExceed;

  BudgetImpact({
    required this.categoryName,
    required this.budgetAmount,
    required this.currentSpent,
    required this.projectedSpent,
    required this.willExceed,
  });

  double get currentProgress => (budgetAmount > 0) ? (currentSpent / budgetAmount) : 0;
  double get projectedProgress => (budgetAmount > 0) ? (projectedSpent / budgetAmount) : 0;

  factory BudgetImpact.fromMap(Map<String, dynamic> map) {
    return BudgetImpact(
      categoryName: map['categoryName'] as String,
      budgetAmount: (map['budgetAmount'] as num).toDouble(),
      currentSpent: (map['currentSpent'] as num).toDouble(),
      projectedSpent: (map['projectedSpent'] as num).toDouble(),
      willExceed: map['willExceed'] as bool,
    );
  }
}

// Representa el impacto en el ahorro/flujo de caja
class SavingsImpact {
  final double currentEOMBalance; // Balance proyectado a fin de mes (EOM = End Of Month)
  final double projectedEOMBalance;

  SavingsImpact({
    required this.currentEOMBalance,
    required this.projectedEOMBalance,
  });

  factory SavingsImpact.fromMap(Map<String, dynamic> map) {
    return SavingsImpact(
      currentEOMBalance: (map['currentEOMBalance'] as num).toDouble(),
      projectedEOMBalance: (map['projectedEOMBalance'] as num).toDouble(),
    );
  }
}