// lib/models/budget_models.dart (VERSIÓN FINAL Y CORREGIDA)

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

enum BudgetStatus { onTrack, warning, exceeded }

class BudgetProgress extends Equatable {
  // Mantenemos 'budgetId' para consistencia con tu preferencia.
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

  // --- Getters computados (estos ya estaban perfectos) ---
  
  double get progress => (budgetAmount > 0) ? (spentAmount / budgetAmount) : 0.0;
  double get remainingAmount => budgetAmount - spentAmount;
  BudgetStatus get status {
    final currentProgress = progress;
    if (currentProgress >= 1.0) return BudgetStatus.exceeded;
    if (currentProgress >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.onTrack;
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'budgetAmount': budgetAmount,
    'spentAmount': spentAmount,
    'progress': progress,
  };
  
  factory BudgetProgress.fromMap(Map<String, dynamic> map) {
    try {
      if (kDebugMode) {
        print('DEBUG [BudgetProgress.fromMap]: Procesando mapa: $map');
      }

      return BudgetProgress(
        // --- LA CORRECCIÓN CLAVE ESTÁ AQUÍ ---
        // Leemos el campo 'budgetid' que ahora nos devuelve la función SQL.
        // El nombre de la columna viene en minúsculas desde la base de datos.
        budgetId: map['budgetid'] as int? ?? 0, 
        
        category: map['category'] as String? ?? 'Sin Categoría',
        budgetAmount: (map['amount'] as num? ?? 0).toDouble(), // La columna se llama 'amount' en la RPC
        spentAmount: (map['spent_amount'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔥 ERROR en BudgetProgress.fromMap: $e, Mapa: $map');
      }
      throw FormatException('Error al parsear BudgetProgress desde JSON: $e', map);
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