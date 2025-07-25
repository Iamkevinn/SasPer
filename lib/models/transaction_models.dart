// lib/models/transaction_models.dart (CORREGIDO)
import 'package:equatable/equatable.dart';

class Transaction extends Equatable {
  final int id; 
  final String userId;
  final String? accountId; // UUID, correcto como String
  final String type;
  final String? category;
  final String? description;
  final double amount;
  final DateTime transactionDate;

  // --- CORRECCIÓN DE TIPOS DE DATOS ---
  // Los IDs de otras tablas son numéricos (bigint), por lo tanto, 'int' en Dart.
  final int? debtId;
  final int? goalId;
  final int? transferId;

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
      // Esta validación no es estrictamente necesaria si el catch es bueno, pero la mantenemos.
      ArgumentError.checkNotNull(map['id'], 'id');
      ArgumentError.checkNotNull(map['user_id'], 'user_id');
      ArgumentError.checkNotNull(map['transaction_date'], 'transaction_date');

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
        // Ahora casteamos a 'int?' para que coincida con el tipo de la propiedad.
        debtId: map['debt_id'] as int?,
        goalId: map['goal_id'] as int?,
        transferId: map['transfer_id'] as int?,
      );
    } catch (e, stackTrace) {
      // Un catch más informativo para depuración futura.
      print('🔥🔥🔥 ERROR FATAL al parsear Transaction: $e');
      print('🔥🔥🔥 Mapa que causó el error: $map');
      print('🔥🔥🔥 StackTrace: $stackTrace');
      rethrow;
    }
  }

  // El método copyWith también debe ser actualizado con los nuevos tipos.
  Transaction copyWith({
    int? id,
    String? userId,
    String? accountId,
    String? type,
    String? category,
    String? description,
    double? amount,
    DateTime? transactionDate,
    int? debtId, // <-- tipo corregido
    int? goalId, // <-- tipo corregido
    int? transferId, // <-- tipo corregido
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