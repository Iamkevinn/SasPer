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
    IconData? parsedIcon;
    if (map['icon_name'] != null) {
      // Esta lógica convierte los datos del icono de Supabase a un IconData
      parsedIcon = IconData(
        int.parse(map['icon_name']), // El código del icono
        fontFamily: map['icon_font_family'],
        fontPackage: map['icon_font_package'],
      );
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

  // Método para convertir de vuelta a un mapa para Supabase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'color': color.value,
      'type': type.name,
      'icon_name': icon?.codePoint.toString(),
      'icon_font_family': icon?.fontFamily,
      'icon_font_package': icon?.fontPackage,
      // user_id se establece en el repositorio
    };
  }
}