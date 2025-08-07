// lib/models/category_model.dart (CÓDIGO CORREGIDO Y ESTANDARIZADO)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:iconsax/iconsax.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

enum CategoryType { income, expense }

class Category extends Equatable {
  final String id;
  final String userId;
  final String name;
  final IconData? icon;
  final String color; // <--- CAMBIO 1: De Color a String
  final CategoryType type;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    required this.color, // <--- CAMBIO 2: Ahora es un String
    required this.type,
    required this.createdAt,
  });

  /// Getter conveniente para usar el color en la UI.
  /// Convierte el String hexadecimal (ej: '#FF4CAF50') en un objeto Color.
  Color get colorAsObject {
    try {
      final hex = color.startsWith('#') ? color.substring(1) : color;
      final buffer = StringBuffer();
      if (hex.length == 6) buffer.write('ff'); // Añade opacidad total si no está presente
      buffer.write(hex.replaceAll('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      // Si el color guardado es inválido, devuelve un color por defecto.
      return Colors.grey;
    }
  }

  static final empty = Category(
    id: '',
    userId: '',
    name: 'Cargando...',
    icon: Iconsax.category,
    color: '#808080', // <--- CAMBIO 3: Color como String
    type: CategoryType.expense,
    createdAt: DateTime(2024),
  );
  
  @override
  List<Object?> get props => [id, name, icon, color, type];

  factory Category.fromMap(Map<String, dynamic> map) {
    IconData? parsedIcon;
    if (map['icon_name'] != null && map['icon_name'].toString().isNotEmpty) {
      try {
        parsedIcon = IconData(
          int.parse(map['icon_name'].toString()),
          // --- ESTANDARIZACIÓN A LINEAWESOME ---
          fontFamily: 'LineAwesomeIcons', 
          fontPackage: 'line_awesome_flutter',
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error al parsear el icono para "${map['name']}": $e');
        }
      }
    }
    
    return Category(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      icon: parsedIcon,
      color: map['color'] as String, // <--- CAMBIO 4: Se lee como String
      type: (map['type'] as String) == 'income' ? CategoryType.income : CategoryType.expense,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color, // <--- CAMBIO 5: Se guarda el String directamente
      'type': type.name,
      'icon_name': icon?.codePoint.toString(),
      // --- ESTANDARIZACIÓN A LINEAWESOME ---
      'icon_font_family': 'LineAwesomeIcons',
      'icon_font_package': 'line_awesome_flutter',
    };
  }
}