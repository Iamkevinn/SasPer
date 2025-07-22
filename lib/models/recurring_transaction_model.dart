// lib/models/recurring_transaction_model.dart (NUEVO ARCHIVO)

import 'package:equatable/equatable.dart';

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
  });

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
    );
  }

  @override
  List<Object?> get props => [id, userId, description, amount, type, category, accountId, frequency, interval, startDate, nextDueDate, endDate, createdAt];
}