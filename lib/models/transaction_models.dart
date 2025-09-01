// lib/models/transaction_models.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart'; // NOVEDAD: Importamos el enum

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
  final TransactionMood? mood; // NOVEDAD: Añadimos el nuevo campo.
  final String? locationName;
  final double? latitude;
  final double? longitude;

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
    this.mood, // NOVEDAD: Añadimos al constructor.
    this.locationName,
    this.latitude,
    this.longitude,
  });

  factory Transaction.empty() {
    return Transaction(
      id: 0,
      userId: '',
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
      mood: null, // NOVEDAD: Añadimos el valor por defecto.
    );
  }
  
  // NOVEDAD: Renombramos `toJson` a `toMap` para consistencia y lo completamos.
  // Este mapa se usa para ENVIAR datos a Supabase.
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'account_id': accountId,
        'type': type,
        'category': category,
        'description': description,
        'amount': amount,
        'transaction_date': transactionDate.toIso8601String(),
        'budget_id': budgetId,
        'debt_id': debtId,
        'goal_id': goalId,
        'transfer_id': transferId,
        'mood': mood?.name, // NOVEDAD: Convertimos el enum a texto para Supabase.
      };

  factory Transaction.fromMap(Map<String, dynamic> map) {
    try {
      // NOVEDAD: Lógica para parsear el estado de ánimo desde la base de datos.
      TransactionMood? parsedMood;
      if (map['mood'] != null && map['mood'] is String) {
        try {
          parsedMood = TransactionMood.values.byName(map['mood']);
        } catch (e) {
          // Si el valor en la DB no es un enum válido, se ignora.
          parsedMood = null;
          if (kDebugMode) {
            print("⚠️ Mood desconocido en la DB: '${map['mood']}'. Se establecerá como null.");
          }
        }
      }

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
        mood: parsedMood, // NOVEDAD: Asignamos el mood parseado.
        locationName: map['location_name'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
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
    TransactionMood? mood, // NOVEDAD: Añadimos al copyWith.
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
      mood: mood ?? this.mood, // NOVEDAD: Asignamos el mood en copyWith.
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
        mood, // NOVEDAD: Añadimos a la lista de props para Equatable.
      ];
}