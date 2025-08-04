// lib/models/insight_model.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:developer' as developer;


/// Define la severidad o el tono de un insight.
enum InsightSeverity {
  info,
  success,
  warning,
  alert
}

/// Define el tipo de insight para agruparlos o para lógicas específicas.
enum InsightType {
  unknown,
  weeklySpendingComparison,
  monthly_savings_comparison, // Corregido para coincidir con el backend
  top_spending_category,    // Corregido para coincidir con el backend
  goal_milestone,
  low_balance_warning,      // Corregido para coincidir con el backend
  upcoming_payment,
  budget_exceeded,
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

  /// Constructor Factory a prueba de fallos para crear una instancia desde un mapa.
  factory Insight.fromMap(Map<String, dynamic> map) {
    try {
      return Insight(
        id: map['id'] ?? 'default_id',
        userId: map['user_id'] ?? '',
        createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
        
        type: InsightType.values.firstWhere(
          (e) => e.name == map['type'],
          orElse: () {
            developer.log("⚠️ Tipo de Insight desconocido: '${map['type']}'. Usando 'unknown'.", name: 'InsightModel');
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
        
        // --- CORRECCIÓN CLAVE ---
        // Maneja el caso en que `metadata` sea nulo o no sea un mapa.
        metadata: (map['metadata'] is Map<String, dynamic>) 
                  ? map['metadata'] 
                  : <String, dynamic>{},
      );
    } catch (e, st) {
      developer.log(
        '🔥🔥🔥 ERROR FATAL al parsear Insight. Revisa el mapa de datos.',
        name: 'InsightModel',
        error: e,
        stackTrace: st,
        // Imprime el mapa que causó el error para facilitar la depuración.
        level: 1000, // Usa un nivel alto para que sea visible
        zone: Zone.current.fork(
          zoneValues: {'map_data': map}
        )
      );
      // Devuelve un "Insight de error" para no romper la UI.
      return Insight(
        id: 'error_id', userId: '', createdAt: DateTime.now(),
        type: InsightType.unknown, title: 'Error al cargar',
        description: 'Hubo un problema al procesar este descubrimiento.',
        severity: InsightSeverity.alert, isRead: false, metadata: {},
      );
    }
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