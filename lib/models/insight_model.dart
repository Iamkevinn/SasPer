// lib/models/insight_model.dart

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:iconsax/iconsax.dart';

/// Define la severidad o el tono de un insight.
enum InsightSeverity {
  info,     // Neutral, un dato interesante.
  success,  // Positivo, una celebración.
  warning,  // Una advertencia, algo a lo que prestar atención.
  alert     // Crítico, requiere acción.
}

/// Define el tipo de insight para agruparlos o para lógicas específicas.
enum InsightType {
  unknown,
  weeklySpendingComparison,
  monthlySpendingComparison,
  topSpendingCategory,
  goalProgress,
  unusualTransaction,
  lowBalance,
}

/// Representa una única pieza de información o "descubrimiento" generado por el sistema.
/// Es inmutable y comparable gracias a `Equatable`.
class Insight extends Equatable {
  final String id;
  final String userId;
  final DateTime createdAt;
  final InsightType type;
  final String title;
  final String description;
  final InsightSeverity severity;
  final bool isRead;
  final Map<String, dynamic> metadata; // Para datos extra como IDs de transacciones, etc.

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

  /// Constructor Factory para crear una instancia de Insight desde un mapa (ej. JSON de Supabase).
  factory Insight.fromMap(Map<String, dynamic> map) {
    return Insight(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      // Convierte el string de la DB al enum correspondiente.
      type: InsightType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InsightType.unknown,
      ),
      title: map['title'] as String,
      description: map['description'] as String,
      severity: InsightSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => InsightSeverity.info,
      ),
      isRead: map['is_read'] as bool,
      metadata: map['metadata'] as Map<String, dynamic>,
    );
  }
  
  @override
  List<Object?> get props => [id, userId, createdAt, type, title, description, severity, isRead, metadata];
}


/// Extensiones para añadir propiedades visuales a los enums, manteniendo el modelo limpio.
extension InsightSeverityX on InsightSeverity {
  /// Devuelve el color asociado a cada tipo de severidad.
  Color getColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    switch (this) {
      case InsightSeverity.info:
        return colors.secondary;
      case InsightSeverity.success:
        return Colors.green.shade600;
      case InsightSeverity.warning:
        return Colors.orange.shade700;
      case InsightSeverity.alert:
        return colors.error;
    }
  }

  /// Devuelve el icono asociado a cada tipo de severidad.
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
}// TODO Implement this library.