// lib/models/simulation_models.dart
//
// CAMBIOS vs original:
// · GoalImpact — meta afectada por el gasto (semanas de retraso reales)
// · RecurringContext — gastos fijos pendientes este mes
// · DebtContext — deudas activas para dar contexto de compromisos
// · SimulationResult ampliado con los tres campos anteriores
// · Todo lo demás permanece idéntico

import 'package:intl/intl.dart';
  import 'dart:math' as math; // Asegúrate de tener este import arriba en el archivo

enum SimulationVerdict { recommended, withCaution, notRecommended }

// ─── RESULTADO PRINCIPAL ──────────────────────────────────────────────────────
class SimulationResult {
  final SimulationVerdict verdict;
  final String verdictMessage;
  final BudgetImpact? budgetImpact;
  final SavingsImpact savingsImpact;

  // Campos nuevos — calculados en Dart con datos reales
  final List<GoalImpact> affectedGoals;
  final RecurringContext recurringContext;
  final DebtContext debtContext;
  final PatrimonioImpact? patrimonioImpact; 

  SimulationResult({
    required this.verdict,
    required this.verdictMessage,
    this.budgetImpact,
    required this.savingsImpact,
    this.affectedGoals = const [],
    RecurringContext? recurringContext,
    DebtContext? debtContext,
    this.patrimonioImpact,
  })  : recurringContext = recurringContext ?? RecurringContext.empty(),
        debtContext = debtContext ?? DebtContext.empty();

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
       patrimonioImpact: map['patrimonioImpact'] != null
          ? PatrimonioImpact.fromMap(
              map['patrimonioImpact'] as Map<String, dynamic>)
          : null,
    );
  }

  // Copia con los campos calculados en Dart añadidos
  SimulationResult withContext({
    required List<GoalImpact> goals,
    required RecurringContext recurring,
    required DebtContext debt,
  }) =>
      SimulationResult(
        verdict: verdict,
        verdictMessage: verdictMessage,
        budgetImpact: budgetImpact,
        savingsImpact: savingsImpact,
        affectedGoals: goals,
        recurringContext: recurring,
        debtContext: debt,
        patrimonioImpact: patrimonioImpact,
      );
}

// ─── IMPACTO EN PRESUPUESTO (sin cambios) ────────────────────────────────────
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

  double get currentProgress =>
      budgetAmount > 0 ? (currentSpent / budgetAmount) : 0;
  double get projectedProgress =>
      budgetAmount > 0 ? (projectedSpent / budgetAmount) : 0;
  double get clampedProjectedProgress =>
      budgetAmount > 0 ? (projectedSpent / budgetAmount).clamp(0.0, 1.0) : 0.0;

  String get formattedProjectedProgress {
    if (budgetAmount <= 0) return 'N/A';
    final progress = projectedSpent / budgetAmount;
    if (progress > 10.0) return '+999%';
    return NumberFormat.percentPattern('es_CO').format(progress);
  }

  factory BudgetImpact.fromMap(Map<String, dynamic> map) => BudgetImpact(
        categoryName: map['categoryName'] as String,
        budgetAmount: (map['budgetAmount'] as num).toDouble(),
        currentSpent: (map['currentSpent'] as num).toDouble(),
        projectedSpent: (map['projectedSpent'] as num).toDouble(),
        willExceed: map['willExceed'] as bool,
      );
}

// ─── IMPACTO EN FLUJO DE CAJA (sin cambios) ──────────────────────────────────
class SavingsImpact {
  final double currentEOMBalance;
  final double projectedEOMBalance;

  SavingsImpact({
    required this.currentEOMBalance,
    required this.projectedEOMBalance,
  });

  factory SavingsImpact.fromMap(Map<String, dynamic> map) => SavingsImpact(
        currentEOMBalance: (map['currentEOMBalance'] as num).toDouble(),
        projectedEOMBalance: (map['projectedEOMBalance'] as num).toDouble(),
      );
}

// ─── IMPACTO EN METAS (NUEVO) ─────────────────────────────────────────────────
// Calculado en Dart, no inventado.
// Lógica: si el usuario destina savings_amount por período a esta meta,
// y el gasto equivale a N períodos de ahorro, la meta se retrasa N períodos.
class GoalImpact {
  final String goalId;
  final String goalName;
  final double targetAmount;
  final double currentAmount;
  final double? savingsAmount;      // savings_amount de la tabla goals
  final DateTime? targetDate;
  final double expenseAmount;        // el monto simulado

  GoalImpact({
    required this.goalId,
    required this.goalName,
    required this.targetAmount,
    required this.currentAmount,
    this.savingsAmount,
    this.targetDate,
    required this.expenseAmount,
  });

  double get remaining => targetAmount - currentAmount;
  double get progressPct => currentAmount / targetAmount;

  // Cuántos períodos de ahorro representa el gasto
  // Solo calculable si savings_amount > 0
  // Cuántos períodos de ahorro representa el gasto
  double? get periodsDelayed {
    if (savingsAmount == null || savingsAmount! <= 0) return null;
    
    // EL FIX: El daño a la meta no puede superar lo que falta para completarla.
    // Usamos el menor valor entre el gasto simulado y lo que falta por ahorrar.
    final effectiveDamage = math.min(expenseAmount, remaining);
    
    return effectiveDamage / savingsAmount!;
  }

  // Días de retraso aproximados (asume período mensual = 30 días)
  int? get daysDelayed {
    final p = periodsDelayed;
    if (p == null) return null;
    return (p * 30).round();
  }

  // Si tiene fecha objetivo, cuánto se correría
  DateTime? get newTargetDate {
    if (targetDate == null || daysDelayed == null) return null;
    return targetDate!.add(Duration(days: daysDelayed!));
  }

  // Solo mostramos la meta si el retraso es >= 3 días (para evitar ruido)
  bool get isSignificant => (daysDelayed ?? 0) >= 3;
}

// ─── CONTEXTO DE GASTOS FIJOS (NUEVO) ────────────────────────────────────────
// Suma de recurring_transactions activas con next_due_date en el mes actual.
class RecurringContext {
  final double pendingThisMonth;   // suma de los gastos fijos que aún no vencen
  final int count;                  // cuántos gastos fijos pendientes
  final List<RecurringItem> items; // los items individuales (máx. 3 para UI)

  RecurringContext({
    required this.pendingThisMonth,
    required this.count,
    required this.items,
  });

  factory RecurringContext.empty() => RecurringContext(
        pendingThisMonth: 0,
        count: 0,
        items: [],
      );

  bool get hasData => count > 0;
}

// Haz la clase pública quitando el guion bajo inicial
class RecurringItem {
  final String description;
  final double amount;
  final DateTime nextDueDate;

  RecurringItem({
    required this.description,
    required this.amount,
    required this.nextDueDate,
  });
}

// ─── CONTEXTO DE DEUDAS (NUEVO) ──────────────────────────────────────────────
// Solo deudas activas — da contexto de compromisos existentes.
class DebtContext {
  final double totalBalance;  // suma de current_balance de deudas activas
  final int count;

  DebtContext({
    required this.totalBalance,
    required this.count,
  });

  factory DebtContext.empty() => DebtContext(totalBalance: 0, count: 0);
  bool get hasData => count > 0;
}

// ─── FinancialProjection (sin cambios — se usa en otro lugar) ─────────────────
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
        newMonthlyContribution:
            (map['newMonthlyContribution'] as num? ?? 0).toDouble(),
        newEstimatedDate:
            DateTime.parse(map['newEstimatedDate'] as String),
      );
    } catch (e) {
      throw FormatException(
          'Error al parsear FinancialProjection: $e', map);
    }
  }
}
// ─── IMPACTO EN PATRIMONIO (NUEVO) ───────────────────────────────────────────
class PatrimonioImpact {
  final double patrimonioActual;
  final double patrimonioPost;
  final double diferencia;
  final double porcentaje;

  PatrimonioImpact({
    required this.patrimonioActual,
    required this.patrimonioPost,
    required this.diferencia,
    required this.porcentaje,
  });

  bool get quedaNegativo => patrimonioPost < 0;

  factory PatrimonioImpact.fromMap(Map<String, dynamic> map) => PatrimonioImpact(
        patrimonioActual: (map['patrimonioActual'] as num).toDouble(),
        patrimonioPost:   (map['patrimonioPost']   as num).toDouble(),
        diferencia:       (map['diferencia']        as num).toDouble(),
        porcentaje:       (map['porcentaje']        as num).toDouble(),
      );
}