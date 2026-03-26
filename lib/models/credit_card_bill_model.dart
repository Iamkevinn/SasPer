// lib/models/credit_card_bill_model.dart

import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';

class CreditCardBill {
  final Account card;
  final double totalAmount;
  final DateTime dueDate;
  final List<Transaction> installments; // El desglose de las compras

  CreditCardBill({
    required this.card,
    required this.totalAmount,
    required this.dueDate,
    required this.installments,
  });

  factory CreditCardBill.fromMap(Map<String, dynamic> map) {
    return CreditCardBill(
      card: Account.fromMap(map['card']),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      dueDate: DateTime.parse(map['dueDate']),
      installments: (map['installments'] as List)
          .map((txMap) => Transaction.fromMap(txMap))
          .toList(),
    );
  }
}