// lib/models/transaction_models.dart
import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  // En tu tabla es 'bigint', lo representamos como String para consistencia
  // con los UUIDs de otros modelos, pero lo parseamos desde un número.
  final int  id; 
  final String userId;
  final String? accountId;
  final String type; // En tu tabla es 'text', así que String es correcto.
  final String? category;
  final String? description;
  final double amount; // 'numeric' en SQL se mapea a double en Dart.
  final DateTime transactionDate;
  final String? debtId;
  final String? goalId;
  final String? transferId; // Campo que ya tienes en tu tabla.

  const Transaction({
    required this.id,
    required this.userId,
    this.accountId,
    required this.type,
    this.category,
    this.description,
    required this.amount,
    required this.transactionDate,
    this.debtId,
    this.goalId,
    this.transferId,
  });

  factory Transaction.fromMap(Map<String, dynamic> map) {
    try {
      // Validamos los campos no nulos según tu esquema
      ArgumentError.checkNotNull(map['id'], 'id');
      ArgumentError.checkNotNull(map['user_id'], 'user_id');
      ArgumentError.checkNotNull(map['transaction_date'], 'transaction_date');

      return Transaction(
        // El ID es un bigint, pero lo convertimos a String para la UI.
        id: map['id'] as int, 
        userId: map['user_id'] as String,
        accountId: map['account_id'] as String?,
        // Proporcionamos un valor por defecto si el tipo es nulo
        type: map['type'] as String? ?? 'Gasto', 
        category: map['category'] as String?,
        description: map['description'] as String?,
        // Tu tabla permite 'amount' nulo, así que lo manejamos.
        amount: (map['amount'] as num? ?? 0.0).toDouble(),
        transactionDate: DateTime.parse(map['transaction_date'] as String),
        debtId: map['debt_id'] as String?,
        goalId: map['goal_id'] as String?,
        transferId: map['transfer_id'] as String?,
      );
    } catch (e) {
      throw FormatException('Error al parsear Transaction: $e', map);
    }
  }

  Transaction copyWith({
    int? id,
    String? userId,
    String? accountId,
    String? type,
    String? category,
    String? description,
    double? amount,
    DateTime? transactionDate,
    String? debtId,
    String? goalId,
    String? transferId,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      accountId: accountId ?? this.accountId,
      type: type ?? this.type,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      transactionDate: transactionDate ?? this.transactionDate,
      debtId: debtId ?? this.debtId,
      goalId: goalId ?? this.goalId,
      transferId: transferId ?? this.transferId,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        accountId,
        type,
        category,
        description,
        amount,
        transactionDate,
        debtId,
        goalId,
        transferId,
      ];
}