// lib/models/budget_models.dart (VERSIÓN ADAPTADA Y MEJORADA)

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// Tu Enum de estado se mantiene, es una excelente idea.
enum BudgetStatus { onTrack, warning, exceeded }

// Renombramos la clase para reflejar que es el modelo completo del presupuesto.
class Budget extends Equatable {
  final int id;
  final String category; // Mantenemos String por ahora para simplicidad.
  final double amount;
  final double spentAmount;

  // --- CAMPOS NUEVOS ---
  final DateTime startDate;
  final DateTime endDate;
  final String periodicity;
  final bool isActive;
  final int daysLeft;

  const Budget({
    required this.id,
    required this.category,
    required this.amount,
    required this.spentAmount,
    required this.startDate,
    required this.endDate,
    required this.periodicity,
    required this.isActive,
    required this.daysLeft,
  });

  // --- TUS GETTERS ANTERIORES (INTACTOS Y FUNCIONALES) ---

  // El progreso ahora viene pre-calculado desde la DB, pero lo dejamos como getter por si acaso.
  double get progress => (amount > 0) ? (spentAmount / amount) : 0.0;
  double get remainingAmount => amount - spentAmount;

  BudgetStatus get status {
    final currentProgress = progress;
    if (currentProgress >= 1.0) return BudgetStatus.exceeded;
    if (currentProgress >= 0.8) return BudgetStatus.warning;
    return BudgetStatus.onTrack;
  }

  // --- NUEVOS GETTERS PARA LA UI ---

  // Devuelve un texto legible para el periodo del presupuesto
  String get periodText {
    // Si es un presupuesto mensual clásico, muestra solo el mes.
    if (periodicity == 'monthly') {
      return DateFormat.yMMMM('es_CO').format(startDate);
    }
    // Para otros, muestra el rango.
    final start = DateFormat.MMMd('es_CO').format(startDate);
    final end = DateFormat.yMMMd('es_CO').format(endDate);
    return '$start - $end';
  }

  // --- MÉTODOS DE FÁBRICA Y SERIALIZACIÓN ---

  // Un constructor de fábrica para un estado de carga o vacío.
  factory Budget.empty() {
    final now = DateTime.now();
    return Budget(
      id: 0,
      category: 'Cargando...',
      amount: 1000,
      spentAmount: 0,
      startDate: DateTime(now.year, now.month, 1),
      endDate: DateTime(now.year, now.month + 1, 0),
      periodicity: 'monthly',
      isActive: true,
      daysLeft: 30,
    );
  }

    // --- ¡MÉTODO AÑADIDO! ---
  /// Convierte el objeto Budget a un mapa JSON para ser guardado.
  Map<String, dynamic> toJson() => {
        'id': id,
        'category_name': category,
        'amount': amount,
        'spent_amount': spentAmount,
        'progress': progress, // Usamos el getter para incluir el progreso
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'periodicity': periodicity,
        'is_active': isActive,
        'days_left': daysLeft,
      };

  // El factory `fromMap` ahora lee las nuevas columnas de la RPC.
  factory Budget.fromMap(Map<String, dynamic> map) {
    try {
      // Leemos el spent_amount que viene del mapa. Lo guardamos en positivo.
      final spent = (map['spent_amount'] as num? ?? 0).toDouble();
      // --- LÓGICA DE SEGURIDAD ---
      // Si las fechas no vienen, usamos valores por defecto (ej: el mes actual).
      final now = DateTime.now();
      final startDate = map['start_date'] != null ? DateTime.parse(map['start_date']) : DateTime(now.year, now.month, 1);
      final endDate = map['end_date'] != null ? DateTime.parse(map['end_date']) : DateTime(now.year, now.month + 1, 0);

      return Budget(
        id: map['id'] as int? ?? 0,
        category: map['category_name'] as String? ?? map['category'] as String? ?? 'Sin Categoría', // Acepta ambas claves
        amount: (map['amount'] as num? ?? map['budget_amount'] as num? ?? 0).toDouble(), // Acepta ambas claves
        spentAmount: spent.abs(), // Siempre guardamos el gasto como positivo

        // --- Mapeo de nuevos campos con valores por defecto ---
        startDate: startDate,
        endDate: endDate,
        periodicity: map['periodicity'] as String? ?? 'monthly', // Por defecto 'monthly'
        isActive: map['is_active'] as bool? ?? (now.isAfter(startDate) && now.isBefore(endDate)), // Calcula si no viene
        daysLeft: map['days_left'] as int? ?? endDate.difference(now).inDays, // Calcula si no viene
      );
    } catch (e) {
      debugPrint('🔥 ERROR en Budget.fromMap: $e, Mapa con error: $map');
      throw FormatException('Error al parsear Budget. Revisa las claves del mapa. $e', map);
    }
  }

  @override
  List<Object?> get props => [id, category, amount, spentAmount, startDate, endDate];
}

// Tu extensión se mantiene, es perfecta.
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