// lib/models/debt_model.dart

import 'package:equatable/equatable.dart';

// El enum para el tipo de deuda ya estaba perfecto.
enum DebtType { debt, loan }

// 1. Creamos un enum para el estado.
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

// Enum para el tipo de impacto del dinero
enum DebtImpactType {
  liquid,
  restricted,
  direct;

  static DebtImpactType fromString(String? type) {
    switch (type?.toLowerCase()) {
      case 'liquid':
        return DebtImpactType.liquid;
      case 'restricted':
        return DebtImpactType.restricted;
      case 'direct':
        return DebtImpactType.direct;
      default:
        return DebtImpactType.liquid;
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
  final DebtImpactType impactType;
  final DateTime createdAt;
  
  // NUEVO: La "Bolsa Virtual" de dinero disponible para gastar de este préstamo
  final double spendingFund; 

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
    required this.impactType,
    required this.createdAt,
    required this.spendingFund, // NUEVO
  });

  factory Debt.empty() {
    return Debt(
      id: '',
      userId: '',
      name: 'Cargando deuda...',
      type: DebtType.debt,
      initialAmount: 1000.0,
      currentBalance: 500.0,
      status: DebtStatus.active,
      impactType: DebtImpactType.liquid,
      createdAt: DateTime.now(),
      spendingFund: 0.0, // <--- FALTABA ESTO
      entityName: null,
      contactId: null,
      dueDate: null,
      interestRate: 0.0,
    );
  }
  
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
        impactType: DebtImpactType.fromString(map['impact_type'] as String?),
        createdAt: DateTime.parse(map['created_at'] as String),
        // Leemos la bolsa virtual de la BD
        spendingFund: (map['spending_fund'] as num? ?? 0.0).toDouble(), 
      );
    } catch (e) {
      throw FormatException('Error al parsear Debt: $e', map);
    }
  }

  // 4. Método `copyWith` actualizado.
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
    DebtImpactType? impactType,
    DateTime? createdAt,
    double? spendingFund, // <--- FALTABA AGREGARLO AQUÍ
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
      impactType: impactType ?? this.impactType,
      createdAt: createdAt ?? this.createdAt,
      spendingFund: spendingFund ?? this.spendingFund, // <--- Y AQUÍ
    );
  }

  // Los getters computados son muy útiles.
  double get progress {
    if (initialAmount <= 0) return 1.0;
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
        impactType,
        createdAt,
        spendingFund, // <--- FALTABA AGREGARLO AQUÍ
      ];
}