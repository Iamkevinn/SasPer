// Dentro de lib/widgets/categories/category_list_item.dart

import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart'; // Asegúrate de importar esto
import 'package:sasper/models/category_model.dart';

class CategoryListItem extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategoryListItem({
    Key? key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // =================================================================
    //                       DIAGNÓSTICO FINAL
    // =================================================================
    print('Construyendo item para "${category.name}". El objeto IconData es: ${category.icon}');
    print(LineAwesomeIcons.utensils.codePoint);
    // =================================================================

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: category.color,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icono real desde la base de datos
            if (category.icon != null)
              Icon(category.icon, color: Colors.white, size: 20),

            // Icono de prueba FIJO para comparar
            // Icon(LineAwesomeIcons.pizza_slice, color: Colors.yellow, size: 10), 
          ],
        )
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.edit), onPressed: onEdit),
          IconButton(icon: Icon(Icons.delete), onPressed: onDelete),
        ],
      ),
    );
  }
}