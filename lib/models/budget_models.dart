// lib/models/budget_models.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

// El enum no necesita cambios, está perfecto.
enum BudgetStatus { onTrack, warning, exceeded }

class BudgetProgress extends Equatable {
  final String category;
  final double budgetAmount;
  final double spentAmount;

  // 1. Constructor `const`.
  const BudgetProgress({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
  });

  // Los getters computados ya estaban muy bien.
  double get progress => (budgetAmount > 0) ? (spentAmount / budgetAmount).clamp(0.0, 1.0) : 0.0;
  
  double get remainingAmount => (budgetAmount - spentAmount);

  BudgetStatus get status {
    if (progress >= 1.0) return BudgetStatus.exceeded;
    if (progress >= 0.8) return BudgetStatus.warning; // Ligeramente ajustado a 80%
    return BudgetStatus.onTrack;
  }

  // 2. Método `fromJson` robustecido.
  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    try {
      return BudgetProgress(
        category: json['category'] as String? ?? 'Sin Categoría',
        budgetAmount: (json['budget_amount'] as num? ?? 0).toDouble(),
        spentAmount: (json['spent_amount'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      throw FormatException('Error al parsear BudgetProgress: $e', json);
    }
  }

  // 3. Propiedades para Equatable.
  @override
  List<Object?> get props => [category, budgetAmount, spentAmount];
}


// La extensión ya estaba perfecta, no necesita cambios.
// Es una excelente práctica mantenerla aquí.
extension BudgetStatusX on BudgetStatus {
  Color getColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (this) {
      case BudgetStatus.onTrack:
        return colors.primary; // Usar colores del tema es más adaptable.
      case BudgetStatus.warning:
        return Colors.orange.shade600;
      case BudgetStatus.exceeded:
        return colors.error;
    }
  }

  IconData get icon {
    switch (this) {
      case BudgetStatus.onTrack:
        return Iconsax.shield_tick;
      case BudgetStatus.warning:
        return Iconsax.warning_2;
      case BudgetStatus.exceeded:
        return Iconsax.close_circle;
    }
  }
}