// lib/models/recurring_transaction_model.dart (NUEVO ARCHIVO)

import 'package:equatable/equatable.dart';
enum RecurringStatus { active, paused }
class RecurringTransaction extends Equatable {
  final String id;
  final String userId;
  final String description;
  final double amount;
  final String type;
  final String category;
  final String accountId;
  final String frequency;
  final int interval;
  final DateTime startDate;
  final DateTime nextDueDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final RecurringStatus status;

  const RecurringTransaction({
    required this.id,
    required this.userId,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.accountId,
    required this.frequency,
    required this.interval,
    required this.startDate,
    required this.nextDueDate,
    this.endDate,
    required this.createdAt,
    required this.status,
  });

  /// Crea una instancia "vacía" de RecurringTransaction.
  /// Ideal para usar como placeholder en Skeletonizer.
  /// No puede ser `const` porque usa DateTime.now().
  factory RecurringTransaction.empty() {
    return RecurringTransaction(
      id: '',
      userId: '',
      description: 'Cargando gasto fijo...',
      amount: 0.0,
      type: 'Gasto',
      category: 'Categoría',
      accountId: '',
      frequency: 'mensual',
      interval: 1,
      startDate: DateTime.now(),
      nextDueDate: DateTime.now(),
      createdAt: DateTime.now(),
      status: RecurringStatus.active,
    );
  }
  
  
  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      description: map['description'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String,
      category: map['category'] as String,
      accountId: map['account_id'] as String,
      frequency: map['frequency'] as String,
      interval: map['interval'] as int,
      startDate: DateTime.parse(map['start_date'] as String),
      nextDueDate: DateTime.parse(map['next_due_date'] as String),
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
          status: map['status'] == 'paused' ? RecurringStatus.paused : RecurringStatus.active,
    );
  }

  // ---- AÑADIMOS MÉTODO toJson ----
  Map<String, dynamic> toJson() {
    return {
      'description': description,
      'amount': amount,
      'type': type,
      'category': category,
      'account_id': accountId,
      'frequency': frequency,
      'interval': interval,
      'start_date': startDate.toIso8601String(),
      'next_due_date': nextDueDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }
  
  // ---- MÉTODO copyWith CORREGIDO Y COMPLETO ----
  RecurringTransaction copyWith({
    String? id,
    String? description,
    double? amount,
    String? type,
    String? category,
    String? accountId,
    String? frequency,
    int? interval,
    DateTime? startDate,
    DateTime? nextDueDate,
    DateTime? endDate,
    DateTime? createdAt,
    RecurringStatus? status, // <-- 1. AÑADIR status A LOS PARÁMETROS
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      userId: this.userId, // CORREGIDO: Usar this.userId
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      accountId: accountId ?? this.accountId,
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      startDate: startDate ?? this.startDate, // CORREGIDO: Usar this y permitir cambio
      nextDueDate: nextDueDate ?? this.nextDueDate, // CORREGIDO: Usar this y permitir cambio
      endDate: endDate ?? this.endDate, // CORREGIDO: Usar this y permitir cambio
      createdAt: createdAt ?? this.createdAt, // CORREGIDO: Usar this y permitir cambio
      status: status ?? this.status, // <-- 2. AÑADIR ARGUMENTO PARA status
    );
  }
  
  @override
  List<Object?> get props => [id, userId, description, amount, type, category, accountId, frequency, interval, startDate, nextDueDate, endDate, createdAt,status];
}