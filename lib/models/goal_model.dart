// lib/models/goal_model.dart

import 'package:equatable/equatable.dart';

// 1. Creamos un enum para el estado de la meta.
enum GoalStatus {
  active,
  completed,
  archived;

  // Helper para convertir un string a un enum de forma segura.
  static GoalStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return GoalStatus.active;
      case 'completed':
        return GoalStatus.completed;
      case 'archived':
        return GoalStatus.archived;
      default:
        // Valor por defecto si el string no coincide.
        return GoalStatus.active;
    }
  }
}

// 2. Hacemos la clase inmutable y comparable.
class Goal extends Equatable {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final DateTime createdAt;
  final GoalStatus status;
  final String? iconName;

  const Goal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.targetDate,
    required this.createdAt,
    required this.status,
    this.iconName,
  });

  // 3. Método `fromMap` robustecido.
  factory Goal.fromMap(Map<String, dynamic> map) {
    try {
      return Goal(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String? ?? 'Meta sin nombre',
        targetAmount: (map['target_amount'] as num? ?? 0).toDouble(),
        currentAmount: (map['current_amount'] as num? ?? 0).toDouble(),
        targetDate: map['target_date'] != null ? DateTime.parse(map['target_date'] as String) : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        status: GoalStatus.fromString(map['status'] as String?),
        iconName: map['icon_name'] as String?,
      );
    } catch (e) {
      throw FormatException('Error al parsear Goal: $e', map);
    }
  }
  
  // 4. Método `copyWith` para crear copias modificadas.
  Goal copyWith({
    String? id,
    String? userId,
    String? name,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    DateTime? createdAt,
    GoalStatus? status,
    String? iconName,
  }) {
    return Goal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      iconName: iconName ?? this.iconName,
    );
  }

  // Los getters computados son una excelente práctica.
  double get progress => (currentAmount > 0 && targetAmount > 0) 
      ? (currentAmount / targetAmount).clamp(0.0, 1.0) 
      : 0.0;

  double get remainingAmount => targetAmount - currentAmount;

  // 5. Propiedades para Equatable.
  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        targetAmount,
        currentAmount,
        targetDate,
        createdAt,
        status,
        iconName,
      ];
}