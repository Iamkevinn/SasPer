// lib/models/category_model.dart (CÓDIGO CORREGIDO Y DINÁMICO)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:iconsax/iconsax.dart';

// NO es necesario importar 'line_awesome_flutter' aquí, ya que los iconos se manejarán dinámicamente.

enum CategoryType { income, expense }

class Category extends Equatable {
  final String id;
  final String userId;
  final String name;
  final IconData? icon;
  final String color;
  final CategoryType type;
  final DateTime createdAt;

  const Category({
    required this.id,
    required this.userId,
    required this.name,
    this.icon,
    required this.color,
    required this.type,
    required this.createdAt,
  });

  Color get colorAsObject {
    try {
      final hex = color.startsWith('#') ? color.substring(1) : color;
      final buffer = StringBuffer();
      if (hex.length == 6) buffer.write('ff');
      buffer.write(hex.replaceAll('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return Colors.grey;
    }
  }

  static final empty = Category(
    id: '',
    userId: '',
    name: 'Cargando...',
    icon: Iconsax.category,
    color: '#808080',
    type: CategoryType.expense,
    createdAt: DateTime(2024),
  );
  
  @override
  List<Object?> get props => [id, name, icon, color, type];
  
  factory Category.fromMap(Map<String, dynamic> map) {
    IconData? parsedIcon;
    // NOVEDAD: Ahora leemos dinámicamente el nombre, la familia y el paquete del icono.
    if (map['icon_name'] != null && map['icon_name'].toString().isNotEmpty) {
      try {
        parsedIcon = IconData(
          int.parse(map['icon_name'].toString()),
          fontFamily: map['icon_font_family'] as String?, // Leemos la familia de la DB
          fontPackage: map['icon_font_package'] as String?, // Leemos el paquete de la DB
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
      color: map['color'] as String,
      type: (map['type'] as String) == 'income' ? CategoryType.income : CategoryType.expense,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color,
      'type': type.name,
      // NOVEDAD: Ahora guardamos dinámicamente los datos del icono seleccionado.
      'icon_name': icon?.codePoint.toString(),
      'icon_font_family': icon?.fontFamily,
      'icon_font_package': icon?.fontPackage,
    };
  }
}