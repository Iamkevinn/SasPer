
// lib/models/transaction_models.dart (VERSIÓN FINAL CORREGIDA)

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class Transaction extends Equatable {
  final int id; // ID de la transacción, es un bigint -> int
  final String userId;
  final String? accountId; // UUID -> String
  final String type;
  final String? category;
  final String? description;
  final double amount;
  final DateTime transactionDate;
  
  // --- CORRECCIÓN CRÍTICA DE TIPOS DE DATOS ---
  // Las claves foráneas a otras tablas (goals, debts, transfers)
  // son de tipo UUID en la base de datos, por lo tanto, deben ser String? en Dart.
  final int? budgetId; // Este es bigint -> int?, estaba correcto.
  final String? debtId; // UUID -> String?
  final String? goalId; // UUID -> String?
  final String? transferId; // UUID -> String?

  const Transaction({
    required this.id,
    required this.userId,
    this.accountId,
    required this.type,
    this.category,
    this.description,
    required this.amount,
    required this.transactionDate,
    this.budgetId,
    this.debtId,
    this.goalId,
    this.transferId,
  });

  Map<String, dynamic> toJson() => {
     'description': description,
     'amount': amount,
     'type': type,
     'category': category,
   };

  factory Transaction.fromMap(Map<String, dynamic> map) {
    try {
      return Transaction(
        id: map['id'] as int,
        userId: map['user_id'] as String,
        accountId: map['account_id'] as String?,
        type: map['type'] as String? ?? 'Gasto',
        category: map['category'] as String?,
        description: map['description'] as String?,
        amount: (map['amount'] as num? ?? 0.0).toDouble(),
        transactionDate: DateTime.parse(map['transaction_date'] as String),

        // --- CORRECCIÓN DE CASTEO ---
        // Ahora casteamos a los tipos correctos.
        budgetId: map['budget_id'] as int?, // Correcto
        debtId: map['debt_id'] as String?, // Corregido a String?
        goalId: map['goal_id'] as String?, // Corregido a String?
        transferId: map['transfer_id'] as String?, // Corregido a String?
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔥🔥🔥 ERROR FATAL al parsear Transaction: $e');
        print('🔥🔥🔥 Mapa que causó el error: $map');
        print('🔥🔥🔥 StackTrace: $stackTrace');
      }
      rethrow;
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
    int? budgetId,
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
      budgetId: budgetId ?? this.budgetId,
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
        budgetId,
        debtId,
        goalId,
        transferId,
      ];
}