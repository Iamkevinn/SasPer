// lib/models/insight_model.dart

// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:developer' as developer;
import 'package:intl/intl.dart';

/// Define la severidad o el tono de un insight.
enum InsightSeverity { info, success, warning, alert }

/// Define el tipo de insight para lógicas específicas.
/// Los nombres coinciden con los strings enviados por los triggers de Supabase.
enum InsightType {
  unknown,
  weeklySpendingComparison,
  monthly_savings_comparison,
  top_spending_category,
  goal_milestone,
  low_balance_warning,
  upcoming_payment,
  budget_exceeded,
  budget_warning,
  large_expense,
  emotional_alert,
  credit_strategy,
  cleanup_reminder,
  savings_opportunity,
  trial_ending,
  test_alert,
  warning,
  end_of_month_projection,
}

class Insight extends Equatable {
  final String id;
  final String userId;
  final DateTime createdAt;
  final InsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final bool isRead;
  final Map<String, dynamic> metadata;

  // 👈 NUEVA PROPIEDAD INTELIGENTE
  String get displayDescription {
    if (type == InsightType.end_of_month_projection) {
      final pending = (metadata['pending'] ?? 0).toDouble();
      final shortfall = (metadata['shortfall'] ?? 0).toDouble();
      final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

      if (description == 'shortfall' || shortfall > 0) {
        return 'Para llegar a fin de mes necesitas: ${fmt.format(pending)}\nTe faltan: ${fmt.format(shortfall)} para cubrir tus gastos fijos.';
      } else {
        return 'Tienes saldo suficiente para cubrir tus gastos recurrentes restantes de este mes (${fmt.format(pending)}).';
      }
    }
    // Si es otro tipo de insight, devuelve la descripción normal de la DB
    return description;
  }
  
  const Insight({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.isRead,
    required this.metadata,
  });

  factory Insight.empty() {
    return Insight(
      id: '',
      userId: '',
      createdAt: DateTime.now(),
      type: InsightType.unknown,
      title: 'Cargando descubrimiento...',
      description: 'Analizando tus datos para encontrar información valiosa.',
      severity: InsightSeverity.info,
      isRead: false,
      metadata: const {},
    );
  }

  /// Constructor Factory para crear una instancia desde el mapa de Supabase.
  factory Insight.fromMap(Map<String, dynamic> map) {
    try {
      return Insight(
        id: map['id']?.toString() ?? 'default_id',
        userId: map['user_id'] ?? '',
        createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),

        type: InsightType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () {
            developer.log(
                "⚠️ Tipo de Insight desconocido: '${map['type']}'. Usando 'unknown'.",
                name: 'InsightModel');
            return InsightType.unknown;
          },
        ),

        title: map['title'] ?? 'Sin Título',
        description: map['description'] ?? 'Sin Descripción',

        severity: InsightSeverity.values.firstWhere(
          (e) => e.name == map['severity'],
          orElse: () => InsightSeverity.info,
        ),

        isRead: map['is_read'] ?? false,
        metadata: (map['metadata'] is Map<String, dynamic>)
            ? map['metadata']
            : <String, dynamic>{},
      );
    } catch (e, st) {
      developer.log(
          '🔥🔥🔥 ERROR FATAL al parsear Insight.',
          name: 'InsightModel',
          error: e,
          stackTrace: st);
      return Insight.empty();
    }
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        createdAt,
        type,
        title,
        description,
        severity,
        isRead,
        metadata
      ];
}

/// Extensiones visuales para la UI
extension InsightSeverityX on InsightSeverity {
  Color getColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (this) {
      case InsightSeverity.info:
        return const Color(0xFF0A84FF); // iOS Blue
      case InsightSeverity.success:
        return const Color(0xFF30D158); // iOS Green
      case InsightSeverity.warning:
        return const Color(0xFFFF9F0A); // iOS Orange
      case InsightSeverity.alert:
        return const Color(0xFFFF453A); // iOS Red
    }
  }

  IconData get icon {
    switch (this) {
      case InsightSeverity.info:
        return Iconsax.info_circle;
      case InsightSeverity.success:
        return Iconsax.like_1;
      case InsightSeverity.warning:
        return Iconsax.warning_2;
      case InsightSeverity.alert:
        return Iconsax.danger;
    }
  }
}