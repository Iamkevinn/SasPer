// lib/models/account_model.dart

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

enum AccountStatus { active, archived }

// 1. Hacemos que la clase extienda Equatable para simplificar la comparación.
class Account extends Equatable {
  final String id;
  final String userId;
  final String name;
  final String type;
  final double balance; // Mantenemos el balance como el único campo mutable si es necesario.
  final double initialBalance;
  final DateTime createdAt;
  final String? iconName;
  final String? color;
  final AccountStatus status;
  
  // El constructor ahora es `const`.
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
  });

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
    );
  }

  // 2. Método factory `fromMap` mejorado para ser más estricto.
   // --- CONSTRUCTOR fromMap SIMPLIFICADO Y CORREGIDO ---
  factory Account.fromMap(Map<String, dynamic> map) {
    try {
      // El RPC nos da 'current_balance'. La tabla nos da 'balance'.
      // Aceptamos cualquiera de los dos para máxima compatibilidad.
      final currentBalance = (map['current_balance'] as num? ?? map['balance'] as num? ?? 0.0).toDouble();

      return Account(
        id: map['id'].toString(),
        userId: map['user_id'].toString(),
        name: map['name'] as String? ?? 'Cuenta sin nombre',
        type: map['type'] as String? ?? 'Sin tipo',
        balance: currentBalance, // Usamos el saldo calculado o el de la tabla
        initialBalance: (map['initial_balance'] as num? ?? 0.0).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        iconName: map['icon_name'] as String?,
        color: map['color'] as String?,
        status: map['status'] == 'archived' ? AccountStatus.archived : AccountStatus.active,
      );
    } catch (e) {
      throw FormatException('Error al parsear Account desde el mapa: $e', map);
    }
  }
  
  // 3. Método `copyWith` para facilitar la creación de copias modificadas.
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
    );
  }

  // El getter de color ya estaba perfecto.
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

  // 4. Propiedades para Equatable. Dos cuentas son "iguales" si todos estos campos coinciden.
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
        status 
      ];
}