// lib/models/debt_model.dart

import 'package:equatable/equatable.dart';

// El enum para el tipo de deuda ya estaba perfecto.
enum DebtType { debt, loan }

// 1. Creamos un enum para el estado, igual que hicimos con Goal.
enum DebtStatus {
  active,
  paid,
  archived;

  static DebtStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return DebtStatus.active;
      case 'paid':
        return DebtStatus.paid;
      case 'archived':
        return DebtStatus.archived;
      default:
        return DebtStatus.active;
    }
  }
}


// 2. Hacemos la clase inmutable y comparable.
class Debt extends Equatable {
  final String id;
  final String userId;
  final String name;
  final DebtType type;
  final String? entityName;
  final String? contactId;
  final double initialAmount;
  final double currentBalance;
  final DateTime? dueDate;
  final double interestRate;
  final DebtStatus status;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    this.entityName,
    this.contactId,
    required this.initialAmount,
    required this.currentBalance,
    this.dueDate,
    this.interestRate = 0.0,
    required this.status,
    required this.createdAt,
  });

  // 3. Método `fromMap` robustecido.
  factory Debt.fromMap(Map<String, dynamic> map) {
    try {
      return Debt(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        name: map['name'] as String? ?? 'Deuda sin nombre',
        type: (map['type'] as String? ?? 'debt') == 'debt' ? DebtType.debt : DebtType.loan,
        entityName: map['entity_name'] as String?,
        contactId: map['contact_id'] as String?,
        initialAmount: (map['initial_amount'] as num? ?? 0.0).toDouble(),
        currentBalance: (map['current_balance'] as num? ?? 0.0).toDouble(),
        dueDate: map['due_date'] != null ? DateTime.parse(map['due_date'] as String) : null,
        interestRate: (map['interest_rate'] as num? ?? 0.0).toDouble(),
        status: DebtStatus.fromString(map['status'] as String?),
        createdAt: DateTime.parse(map['created_at'] as String),
      );
    } catch (e) {
      throw FormatException('Error al parsear Debt: $e', map);
    }
  }

  // 4. Método `copyWith` para actualizaciones inmutables.
  Debt copyWith({
    String? id,
    String? userId,
    String? name,
    DebtType? type,
    String? entityName,
    String? contactId,
    double? initialAmount,
    double? currentBalance,
    DateTime? dueDate,
    double? interestRate,
    DebtStatus? status,
    DateTime? createdAt,
  }) {
    return Debt(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      entityName: entityName ?? this.entityName,
      contactId: contactId ?? this.contactId,
      initialAmount: initialAmount ?? this.initialAmount,
      currentBalance: currentBalance ?? this.currentBalance,
      dueDate: dueDate ?? this.dueDate,
      interestRate: interestRate ?? this.interestRate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // Los getters computados son muy útiles.
  double get progress {
    if (initialAmount <= 0) return 1.0; // Si no había monto inicial, está "pagada".
    final double paidAmount = initialAmount - currentBalance;
    return (paidAmount / initialAmount).clamp(0.0, 1.0);
  }

  double get paidAmount => initialAmount - currentBalance;

  // 5. Propiedades para Equatable.
  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        type,
        entityName,
        contactId,
        initialAmount,
        currentBalance,
        dueDate,
        interestRate,
        status,
        createdAt,
      ];
}