// lib/models/account_model.dart

import 'package:flutter/material.dart';

class Account {
  final String id;
  final String userId;
  final String name;
  final String type;
  double balance; // El balance puede cambiar, así que no es final.
  final double initialBalance; // El balance inicial no cambia.
  final DateTime createdAt;
  final String? iconName;
  final String? color;

  Account({
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

  // Método factory para crear un objeto Account desde un mapa (JSON de Supabase).
  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      // Supabase devuelve el ID como un entero en tu ejemplo, pero debería ser UUID (string).
      // Lo convertimos a String por si acaso.
      id: map['id'].toString(), 
      userId: map['user_id'],
      name: map['name'],
      type: map['type'],
      // Casteo seguro de `numeric` a `double`.
      balance: (map['balance'] as num).toDouble(),
      // 'initial_balance' puede ser nulo en cuentas antiguas, le damos un fallback.
      initialBalance: (map['initial_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(map['created_at']),
      iconName: map['icon_name'],
      color: map['color'],
    );
  }

  // Método para convertir un objeto Account a un mapa (para enviar a Supabase).
  // Útil si implementamos la edición o creación de cuentas desde la app.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'balance': balance,
      'initial_balance': initialBalance,
      'icon_name': iconName,
      'color': color,
      // 'id', 'user_id' y 'created_at' son manejados por Supabase.
    };
  }

  // Helper para obtener el color de la cuenta con un fallback.
  Color get accountColor {
    if (color != null && color!.length >= 6) {
      // Asume que el color está guardado como 'RRGGBB' o '#RRGGBB'
      final hexColor = color!.replaceAll('#', '');
      if (hexColor.length == 6) {
        try {
          return Color(int.parse('FF$hexColor', radix: 16));
        } catch (e) {
          // Si el parseo falla, devuelve el color por defecto.
          return Colors.grey.shade700;
        }
      }
    }
    // Color por defecto si no hay uno especificado o es inválido.
    return Colors.grey.shade700;
  }
}