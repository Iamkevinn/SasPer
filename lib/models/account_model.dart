// lib/models/account_model.dart

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:iconsax/iconsax.dart';

enum AccountStatus { active, archived }

class Account extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String type;
  final double balance;
  final double initialBalance;
  final DateTime createdAt;
  final String? iconName;
  final String? color;
  final AccountStatus status;

  // --- NUEVOS CAMPOS PARA TARJETA DE CRÉDITO ---
  final double creditLimit;    // Cupo total
  final int? closingDay;       // Día de corte (1-31)
  final int? dueDay;           // Día de pago (1-31)
  final double interestRate;   // Tasa de interés efectiva anual
  final double maintenanceFee;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.balance,
    required this.initialBalance,
    required this.createdAt,
    this.iconName,
    this.color,
    required this.status,
    // Inicializamos los nuevos campos
    this.creditLimit = 0.0,
    this.closingDay,
    this.dueDay,
    this.interestRate = 0.0,
    this.maintenanceFee = 0.0,
  });

  IconData get icon {
    return _iconMap[iconName?.toLowerCase()] ?? Iconsax.wallet;
  }

  static const Map<String, IconData> _iconMap = {
    'money_3': Iconsax.money_3,
    'building_4': Iconsax.building_4,
    'card': Iconsax.card,
    'safe_home': Iconsax.safe_home,
    'chart_1': Iconsax.chart_1,
    'wallet': Iconsax.wallet,
    'bank': Iconsax.bank,
    'dollar_circle': Iconsax.dollar_circle,
  };
  
  factory Account.empty() {
    return Account(
      id: '',
      userId: '',
      name: 'Cargando...',
      type: 'Efectivo',
      balance: 0.0,
      initialBalance: 0.0,
      createdAt: DateTime.now(),
      status: AccountStatus.active,
      creditLimit: 0.0,
      interestRate: 0.0,
    );
  }

  // --- fromMap ACTUALIZADO PARA LEER DE SUPABASE ---
  factory Account.fromMap(Map<String, dynamic> map) {
    try {
      final currentBalance = (map['current_balance'] as num? ?? map['balance'] as num? ?? 0.0).toDouble();

      return Account(
        id: map['id'].toString(),
        userId: map['user_id'].toString(),
        name: map['name'] as String? ?? 'Cuenta sin nombre',
        type: map['type'] as String? ?? 'Sin tipo',
        balance: currentBalance,
        initialBalance: (map['initial_balance'] as num? ?? 0.0).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        iconName: map['icon_name'] as String?,
        color: map['color'] as String?,
        status: map['status'] == 'archived' ? AccountStatus.archived : AccountStatus.active,
        
        // Mapeo de los nuevos campos desde la BD
        creditLimit: (map['credit_limit'] as num? ?? 0.0).toDouble(),
        closingDay: map['closing_day'] as int?,
        dueDay: map['due_day'] as int?,
        interestRate: (map['interest_rate'] as num? ?? 0.0).toDouble(),
        maintenanceFee: (map['maintenance_fee'] as num? ?? 0.0).toDouble(),
      );
    } catch (e) {
      throw FormatException('Error al parsear Account desde el mapa: $e', map);
    }
  }
  
  // --- copyWith ACTUALIZADO ---
  Account copyWith({
    String? id,
    String? userId,
    String? name,
    String? type,
    double? balance,
    double? initialBalance,
    DateTime? createdAt,
    String? iconName,
    String? color,
    double? creditLimit,
    int? closingDay,
    int? dueDay,
    double? interestRate,
    double? maintenanceFee,
  }) {
    return Account(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      initialBalance: initialBalance ?? this.initialBalance,
      createdAt: createdAt ?? this.createdAt,
      iconName: iconName ?? this.iconName,
      color: color ?? this.color,
      status: status,
      creditLimit: creditLimit ?? this.creditLimit,
      closingDay: closingDay ?? this.closingDay,
      dueDay: dueDay ?? this.dueDay,
      interestRate: interestRate ?? this.interestRate,
      maintenanceFee: maintenanceFee ?? this.maintenanceFee,
    );
  }

  Color get accountColor {
    if (color != null && color!.length >= 6) {
      final hexColor = color!.replaceAll('#', '');
      if (hexColor.length == 6) {
        try {
          return Color(int.parse('FF$hexColor', radix: 16));
        } catch (_) {
          return Colors.grey.shade700;
        }
      }
    }
    return Colors.grey.shade700;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        name,
        type,
        balance,
        initialBalance,
        createdAt,
        iconName,
        color,
        status,
        // Añadimos a props para que Equatable sepa comparar estos campos
        creditLimit,
        closingDay,
        dueDay,
        interestRate,
        maintenanceFee,
      ];
}