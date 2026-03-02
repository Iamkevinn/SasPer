// lib/models/transaction_models.dart

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';

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
  final TransactionMood? mood;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  
  // --- NUEVOS CAMPOS PARA CRÉDITO Y CUOTAS ---
  final String? creditCardId;
  final int? installmentsTotal;
  final int? installmentsCurrent;
  final bool isInstallment;
  final bool isInterestFree;

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
    this.mood,
    this.locationName,
    this.latitude,
    this.longitude,
    // Inicializamos los nuevos campos
    this.creditCardId,
    this.installmentsTotal,
    this.installmentsCurrent,
    this.isInstallment = false,
    this.isInterestFree = false,
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
      mood: null,
      creditCardId: null,
      installmentsTotal: null,
      installmentsCurrent: null,
      isInstallment: false,
      isInterestFree: false,
    );
  }
  
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
        'mood': mood?.name,
        // Añadimos los nuevos campos al JSON
        'credit_card_id': creditCardId,
        'installments_total': installmentsTotal,
        'installments_current': installmentsCurrent,
        'is_installment': isInstallment,
        'is_interest_free': isInterestFree,
      };

  factory Transaction.fromMap(Map<String, dynamic> map) {
    try {
      TransactionMood? parsedMood;
      if (map['mood'] != null && map['mood'] is String) {
        try {
          parsedMood = TransactionMood.values.byName(map['mood']);
        } catch (e) {
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
        mood: parsedMood,
        locationName: map['location_name'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        // Parseamos los nuevos campos desde Supabase
        creditCardId: map['credit_card_id'] as String?,
        installmentsTotal: map['installments_total'] as int?,
        installmentsCurrent: map['installments_current'] as int?,
        isInstallment: map['is_installment'] as bool? ?? false,
        isInterestFree: map['is_interest_free'] as bool? ?? false,
      );
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('🔥🔥🔥 ERROR FATAL al parsear Transaction: $e');
        print('🔥🔥🔥 Mapa que causó el error: $map');
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
    TransactionMood? mood,
    // Nuevos campos en el copyWith
    String? creditCardId,
    int? installmentsTotal,
    int? installmentsCurrent,
    bool? isInstallment,
    bool? isInterestFree,
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
      mood: mood ?? this.mood,
      creditCardId: creditCardId ?? this.creditCardId,
      installmentsTotal: installmentsTotal ?? this.installmentsTotal,
      installmentsCurrent: installmentsCurrent ?? this.installmentsCurrent,
      isInstallment: isInstallment ?? this.isInstallment,
      isInterestFree: isInterestFree ?? this.isInterestFree,
    );
  }

  @override
  List<Object?> get props =>[
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
        mood,
        locationName,
        latitude,
        longitude,
        // Nuevos campos
        creditCardId,
        installmentsTotal,
        installmentsCurrent,
        isInstallment,
        isInterestFree,
      ];
}