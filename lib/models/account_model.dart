// lib/models/account_model.dart

import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

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
  });

  factory Account.empty() {
  return Account(
    id: '',
    userId: '',
    name: 'Nombre de Cuenta',
    type: 'Efectivo',
    balance: 0.0,
    initialBalance: 0.0,
    createdAt: DateTime.now(),
  );
}
  // 2. Método factory `fromMap` mejorado para ser más estricto.
  factory Account.fromMap(Map<String, dynamic> map) {
    try {
      // Usamos 'ArgumentError.checkNotNull' para fallar rápido si faltan datos críticos.
      ArgumentError.checkNotNull(map['id'], 'id');
      ArgumentError.checkNotNull(map['user_id'], 'user_id');

      final currentBalance = (map['current_balance'] as num?);
      final initialBalance = (map['initial_balance'] as num? ?? 0.0);

      return Account(
        id: map['id'].toString(),
        userId: map['user_id'].toString(),
        name: map['name'] as String? ?? 'Cuenta sin nombre',
        type: map['type'] as String? ?? 'Sin tipo',
        balance: (currentBalance ?? initialBalance).toDouble(),
        initialBalance: initialBalance.toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        iconName: map['icon_name'] as String?,
        color: map['color'] as String?,
      );
    } catch (e) {
      // Si algo falla (un campo nulo, un parseo incorrecto), lanzamos un error claro.
      // Esto hace que la depuración sea 100 veces más fácil.
      throw FormatException('Error al parsear Account desde el mapa: $e', map);
    }
  }

  /// Constructor alternativo para parsear desde la tabla 'accounts' directamente,
  /// que no siempre tiene el 'current_balance' calculado por la función RPC.
  factory Account.fromMapSimple(Map<String, dynamic> map) {
    try {
      ArgumentError.checkNotNull(map['id'], 'id');
      ArgumentError.checkNotNull(map['user_id'], 'user_id');

      return Account(
        id: map['id'].toString(),
        userId: map['user_id'].toString(),
        name: map['name'] as String? ?? 'Cuenta sin nombre',
        type: map['type'] as String? ?? 'Sin tipo',
        // Para el 'balance', usamos el que viene en la tabla, o el inicial como fallback.
        balance: (map['balance'] as num? ?? map['initial_balance'] as num? ?? 0.0).toDouble(),
        initialBalance: (map['initial_balance'] as num? ?? 0.0).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
        iconName: map['icon_name'] as String?,
        color: map['color'] as String?,
      );
    } catch (e) {
      throw FormatException('Error al parsear Account desde el mapa simple: $e', map);
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
      ];
}