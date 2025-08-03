// lib/models/upcoming_payment_model.dart

//import 'package:flutter/foundation.dart';

enum UpcomingPaymentType { debt, recurring }

class UpcomingPayment {
  final String id;
  final String concept;
  final double amount;
  final DateTime nextDueDate;
  final UpcomingPaymentType type;
  final String? iconName; // Para mostrar un ícono representativo

  UpcomingPayment({
    required this.id,
    required this.concept,
    required this.amount,
    required this.nextDueDate,
    required this.type,
    this.iconName,
  });

  // Método para serializar a JSON, crucial para pasar los datos a Kotlin
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'concept': concept,
      'amount': amount,
      'nextDueDate': nextDueDate.toIso8601String(),
      'type': type.name, // 'debt' o 'recurring'
      'iconName': iconName,
    };
  }
}