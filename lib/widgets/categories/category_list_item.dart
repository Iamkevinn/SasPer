// lib/widgets/categories/category_list_item.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/category_model.dart';

class CategoryListItem extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CategoryListItem({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: category.color.withOpacity(0.2),
          child: Icon(category.icon ?? Iconsax.category, color: category.color),
        ),
        title: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: IconButton(
          icon: Icon(Iconsax.trash, color: Theme.of(context).colorScheme.error),
          onPressed: onDelete,
        ),
      ),
    );
  }
}