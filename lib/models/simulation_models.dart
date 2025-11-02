// lib/models/simulation_models.dart
import 'package:intl/intl.dart';

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

    // --- ¡NUEVOS GETTERS FORMATEADOS PARA LA UI! ---

  /// Devuelve el progreso proyectado como un String formateado (ej: "150%").
  /// Tiene un límite superior para evitar valores absurdos en la UI.
  String get formattedProjectedProgress {
    // Si el presupuesto es 0 o negativo, no tiene sentido calcular un porcentaje.
    if (budgetAmount <= 0) return "N/A";

    final progress = projectedSpent / budgetAmount;
    
    // Si el progreso es extremadamente alto (ej: más de 1000%), lo limitamos visualmente.
    if (progress > 10.0) { // 10.0 equivale a 1000%
      return "+999%";
    }

    // Usamos NumberFormat para formatear el número como un porcentaje limpio.
    return NumberFormat.percentPattern('es_CO').format(progress);
  }

  /// Devuelve un valor de progreso "limitado" para usar en indicadores visuales
  /// como CircularProgressIndicator. El valor siempre estará entre 0.0 y 1.0.
  double get clampedProjectedProgress {
    if (budgetAmount <= 0) return 0.0;
    
    // La función .clamp() asegura que el valor nunca sea menor que 0.0 ni mayor que 1.0.
    return (projectedSpent / budgetAmount).clamp(0.0, 1.0);
  }

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
class FinancialProjection {
  final double newMonthlyContribution;
  final DateTime newEstimatedDate;

  FinancialProjection({
    required this.newMonthlyContribution,
    required this.newEstimatedDate,
  });

   factory FinancialProjection.fromMap(Map<String, dynamic> map) {
    try {
      return FinancialProjection(
        newMonthlyContribution: (map['newMonthlyContribution'] as num? ?? 0).toDouble(),
        newEstimatedDate: DateTime.parse(map['newEstimatedDate'] as String),
      );
    } catch (e) {
      throw FormatException('Error al parsear FinancialProjection desde el mapa: $e', map);
    }
  }
  
  // Opcional: Puedes añadir un factory fromMap si tu API va a devolver este objeto
  // factory FinancialProjection.fromMap(Map<String, dynamic> map) {
  //   return FinancialProjection(
  //     newMonthlyContribution: (map['newMonthlyContribution'] as num).toDouble(),
  //     newEstimatedDate: DateTime.parse(map['newEstimatedDate'] as String),
  //   );
  //}
}