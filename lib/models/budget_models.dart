// lib/models/budget_models.dart (VERSIÓN FINAL Y COMPLETA)

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

// El enum no necesita cambios. Define los posibles estados de un presupuesto.
enum BudgetStatus { onTrack, warning, exceeded }

class BudgetProgress extends Equatable {
  final int budgetId; // El ID del presupuesto, necesario para editar/eliminar
  final String category;
  final double budgetAmount;
  final double spentAmount;

  const BudgetProgress({
    required this.budgetId,
    required this.category,
    required this.budgetAmount,
    required this.spentAmount,
  });

  // --- Getters computados ---
  // La lógica de negocio vive aquí, en el modelo.
  
  /// Calcula el progreso como un valor entre 0.0 y 1.0.
  /// Si el monto del presupuesto es 0, el progreso es 0.
  double get progress => (budgetAmount > 0) ? (spentAmount / budgetAmount) : 0.0;
  
  /// Calcula el dinero restante del presupuesto. Puede ser negativo si se excede.
  double get remainingAmount => budgetAmount - spentAmount;

  /// Determina el estado del presupuesto (en curso, al límite o excedido) basado en el progreso.
  BudgetStatus get status {
    // Usamos una variable local para evitar recalcular el progreso.
    final currentProgress = progress;
    if (currentProgress >= 1.0) return BudgetStatus.exceeded;
    if (currentProgress >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.onTrack;
  }

  /// Constructor factory para crear una instancia de BudgetProgress desde un mapa JSON
  /// que viene de la API de Supabase.
  factory BudgetProgress.fromMap(Map<String, dynamic> map) {
    try {
      // --- AÑADIMOS PRINT DE DEBUG ---
      if (kDebugMode) {
        print('DEBUG [BudgetProgress.fromMap]: Procesando mapa: $map');
      }

      return BudgetProgress(
        budgetId: map['budget_id'] as int? ?? 0,
        category: map['category'] as String? ?? 'Sin Categoría',
        budgetAmount: (map['budget_amount'] as num? ?? 0).toDouble(),
        spentAmount: (map['spent_amount'] as num? ?? 0).toDouble(),
      );
    } catch (e) {
      if (kDebugMode) {
        print('🔥 ERROR en BudgetProgress.fromMap: $e, Mapa: $map');
      }
      throw FormatException('Error al parsear BudgetProgress desde JSON: $e', map);
    }
  }

  // Define las propiedades que Equatable usará para comparar instancias.
  // Dos objetos BudgetProgress serán iguales si todos estos campos coinciden.
  @override
  List<Object?> get props => [budgetId, category, budgetAmount, spentAmount];
}

/// Extensión sobre el enum BudgetStatus para añadirle funcionalidades
/// relacionadas con la UI, como obtener un color o un icono.
/// Esto mantiene la lógica de la UI separada del modelo principal.
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