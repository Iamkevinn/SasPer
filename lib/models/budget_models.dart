import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

enum BudgetStatus { onTrack, warning, exceeded }

class BudgetProgress {
  final String category;
  final double budgetAmount;
  final double spentAmount;

  BudgetProgress({
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
  });

  double get progress => budgetAmount > 0 ? (spentAmount / budgetAmount) : 0.0;

  BudgetStatus get status {
    if (progress >= 1.0) return BudgetStatus.exceeded;
    if (progress >= 0.75) return BudgetStatus.warning;
    return BudgetStatus.onTrack;
  }

  factory BudgetProgress.fromJson(Map<String, dynamic> json) {
    return BudgetProgress(
      category: json['category'] as String,
      budgetAmount: (json['budget_amount'] as num).toDouble(),
      spentAmount: (json['spent_amount'] as num).toDouble(),
    );
  }
}

// Usando una extensión para mantener la lógica de UI fuera del modelo.
extension BudgetStatusX on BudgetStatus {
  Color getColor(BuildContext context) {
    switch (this) {
      case BudgetStatus.onTrack:
        return Colors.green.shade400;
      case BudgetStatus.warning:
        return Colors.orange.shade400;
      case BudgetStatus.exceeded:
        return Colors.red.shade400;
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