// lib/models/budget_models.dart (VERSIÓN FINAL LIMPIA)

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

enum BudgetStatus { onTrack, warning, exceeded }

class BudgetProgress extends Equatable {
  final int budgetId;
  final String category;
  final double budgetAmount;
  final double spentAmount;

  const BudgetProgress({
    required this.budgetId,
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
  });

  double get progress => (budgetAmount > 0) ? (spentAmount / budgetAmount) : 0.0;
  double get remainingAmount => budgetAmount - spentAmount;

  BudgetStatus get status {
    final currentProgress = progress;
    if (currentProgress >= 1.0) return BudgetStatus.exceeded;
    if (currentProgress >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.onTrack;
  }
  
  Map<String, dynamic> toJson() => {
        'budgetId': budgetId,
        'category': category,
        'budgetAmount': budgetAmount,
        'spentAmount': spentAmount,
        'progress': progress,
      };

  factory BudgetProgress.fromMap(Map<String, dynamic> map) {
    if (kDebugMode) {
      print('DEBUG [BudgetProgress.fromMap]: Mapa recibido para procesar: $map');
    }
    try {
      // Leemos el spent_amount que viene del mapa.
      double originalSpentAmount = (map['spent_amount'] as num? ?? 0).toDouble();
      return BudgetProgress(

        // Leemos las claves 'budget_id' (del RPC) O 'id' (de otra parte del código)
        // Supabase puede devolver la clave del RPC en minúsculas 'budgetid'.
        budgetId: map['budget_id'] as int? ?? map['budgetid'] as int? ?? map['id'] as int? ?? 0,
        
        category: map['category'] as String? ?? 'Sin Categoría',

        // Leemos la clave 'budget_amount' del RPC
        budgetAmount: (map['budget_amount'] as num? ?? map['amount'] as num? ?? 0).toDouble(),
        
        // Leemos la clave 'spent_amount' del RPC
        //spentAmount: (map['spent_amount'] as num? ?? 0).toDouble(),
        spentAmount: originalSpentAmount.abs(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔥 ERROR en BudgetProgress.fromMap: $e, Mapa con error: $map');
      }
      throw FormatException('Error al parsear BudgetProgress. Revisa las claves del mapa. $e', map);
    }
  }

  @override
  List<Object?> get props => [budgetId, category, budgetAmount, spentAmount];
}

extension BudgetStatusX on BudgetStatus {
  Color getColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (this) {
      case BudgetStatus.onTrack:
        return colors.primary;
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