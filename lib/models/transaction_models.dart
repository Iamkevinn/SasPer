// lib/models/transaction_models.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

class Transaction extends Equatable {
  final int id;
  final String userId;
  final String? accountId;
  final String type;
  final String? category;
  final String? description;
  final double amount;
  final DateTime transactionDate;
  final int? budgetId;
  final String? debtId;
  final String? goalId;
  final String? transferId;

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

  // --- NUEVO CONSTRUCTOR AÑADIDO ---
  /// Crea una instancia "vacía" de Transaction.
  /// Ideal para usar como placeholder en estados de carga, como en Skeletonizer.
  /// No puede ser `const` porque usa `DateTime.now()`.
  factory Transaction.empty() {
    return Transaction(
      id: 0,
      userId: '', // Proporciona un valor por defecto para el campo requerido
      accountId: '',
      type: 'Gasto',
      category: 'Categoría',
      description: 'Cargando descripción...',
      amount: 0.0,
      transactionDate: DateTime.now(),
      budgetId: null,
      debtId: null,
      goalId: null,
      transferId: null,
    );
  }
  // --- FIN DEL CÓDIGO AÑADIDO ---
  
  Map<String, dynamic> toJson() => {
        // Tu método toJson actual parece incompleto, podría necesitar más campos.
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
        budgetId: map['budget_id'] as int?,
        debtId: map['debt_id'] as String?,
        goalId: map['goal_id'] as String?,
        transferId: map['transfer_id'] as String?,
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