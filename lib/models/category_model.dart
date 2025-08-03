// lib/models/category_model.dart (CÓDIGO FINAL Y ROBUSTO)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

enum CategoryType { income, expense }

class Category extends Equatable {
  final String id;
  final String userId;
  final String name;
  final IconData? icon;
  final Color color;
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

  @override
  List<Object?> get props => [id, name, icon, color, type];

  factory Category.fromMap(Map<String, dynamic> map) {
    if (kDebugMode) {
      print('--- Parseando categoría: "${map['name']}" ---');
      print('Datos recibidos del mapa: $map');
    }
    IconData? parsedIcon;
    if (map['icon_name'] != null && map['icon_name'].toString().isNotEmpty) {
      try {
        // =================================================================
        //                       LA LÍNEA CORREGIDA
        // .toString() convierte el dato a String sin importar si es int o String,
        // permitiendo que int.parse() siempre funcione.
        // =================================================================
        parsedIcon = IconData(
          int.parse(map['icon_name'].toString()), // <-- ESTA ES LA MAGIA
          fontFamily: map['icon_font_family'],
          fontPackage: map['icon_font_package'],
        );
        if (kDebugMode) {
          print('>>> ÉXITO: Icono parseado para "${map['name']}" es: $parsedIcon');
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al parsear el icono para "${map['name']}": $e');
        }
      }
    }else {
    if (kDebugMode) {
      print('No se encontró icon_name para "${map['name']}", se asignará null.');
    }
  }
    
    return Category(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
      icon: parsedIcon,
      color: Color(map['color'] as int),
      type: (map['type'] as String) == 'income' ? CategoryType.income : CategoryType.expense,
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  // El método toMap no necesita cambios, ya está bien.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color.value,
      'type': type.name,
      'icon_name': icon?.codePoint.toString(),
      'icon_font_family': icon?.fontFamily,
      'icon_font_package': icon?.fontPackage,
    };
  }
}