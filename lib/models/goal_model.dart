// lib/models/goal_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/category_model.dart'; 

enum GoalTimeframe {
  short,
  medium,
  long, custom;

  static GoalTimeframe fromString(String? timeframe) {
    switch (timeframe?.toLowerCase()) {
      case 'short': return GoalTimeframe.short;
      case 'medium': return GoalTimeframe.medium;
      case 'long': return GoalTimeframe.long;
      default: return GoalTimeframe.short;
    }
  }
}

enum GoalPriority {
  low,
  medium,
  high;

  static GoalPriority fromString(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low': return GoalPriority.low;
      case 'medium': return GoalPriority.medium;
      case 'high': return GoalPriority.high;
      default: return GoalPriority.medium;
    }
  }
}

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
  final GoalTimeframe timeframe;
  final GoalPriority priority;
  final String? categoryId;
  final Category? category; // Para almacenar el objeto completo de la categoría
  
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
    required this.timeframe,
    required this.priority,
    this.categoryId,
    this.category,
  });

  /// Crea una instancia "vacía" de Goal.
  /// Ideal para usar como placeholder en Skeletonizer.
  /// Puede ser `const` porque no usa `DateTime.now()`.
  factory Goal.empty() {
    return Goal(
      id: '',
      userId: '',
      name: 'Cargando meta...',
      targetAmount: 1000,
      currentAmount: 0,
      createdAt: DateTime.now(), // <-- Usamos el valor real, no una referencia
      status: GoalStatus.active,
      iconName: null,
      targetDate: null,
      timeframe: GoalTimeframe.short,
      priority: GoalPriority.medium,
      categoryId: null,
      category: null,
    );
  }

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
        timeframe: GoalTimeframe.fromString(map['timeframe'] as String?),
        priority: GoalPriority.fromString(map['priority'] as String?),
        categoryId: map['category_id'] as String?,
        // Si la consulta de Supabase incluye la categoría, la parseamos aquí.
        category: map['categories'] != null ? Category.fromMap(map['categories']) : null,
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
    GoalTimeframe? timeframe,
    GoalPriority? priority,
    String? categoryId,
    Category? category,
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
      timeframe: timeframe ?? this.timeframe,
      priority: priority ?? this.priority,
      categoryId: categoryId ?? this.categoryId,
      category: category ?? this.category,
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
        timeframe,
        priority,
        categoryId,
        category,
      ];
}