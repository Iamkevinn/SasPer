// lib/widgets/shared/budget_card.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/budget_models.dart';

class BudgetCard extends StatelessWidget {
  final BudgetProgress budget;
  // 1. AÑADIMOS UN CALLBACK OPCIONAL para cuando se toca la tarjeta
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const BudgetCard({
    super.key, 
    required this.budget,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final status = budget.status;
    final statusColor = status.getColor(context);

    // Formateadores de moneda para no repetirlos
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final spentText = currencyFormat.format(budget.spentAmount);
    final totalText = currencyFormat.format(budget.budgetAmount);

    return Card(
      // 2. Usamos un Card en lugar de un Container para obtener elevación y forma del tema.
      // El tamaño fijo se elimina para hacerlo más flexible. La pantalla que lo use definirá el tamaño.
      elevation: 0,
      margin: EdgeInsets.zero, // El espaciado lo debe gestionar el ListView
      color: statusColor.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias, // Asegura que el InkWell no se salga de los bordes
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20), // Para que el splash coincida con la forma
        hoverColor: statusColor.withOpacity(0.05), // Feedback visual en web/escritorio
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Usamos Expanded para que el texto no se desborde si es muy largo
                  Expanded(
                    child: Text(
                      budget.category,
                      // 3. Usamos el estilo del tema para un mejor contraste y consistencia
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // --- AÑADIMOS EL MENÚ DE OPCIONES ---
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') onEdit?.call();
                      if (value == 'delete') onDelete?.call();
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(leading: Icon(Iconsax.edit), title: Text('Editar Monto')),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(leading: Icon(Iconsax.trash), title: Text('Eliminar')),
                      ),
                    ],
                    icon: Icon(Iconsax.more, color: colorScheme.onSurfaceVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(spentText, style: textTheme.titleSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                  Text(totalText, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: budget.progress, // clamp ya no es necesario si el modelo lo hace
                borderRadius: BorderRadius.circular(8),
                backgroundColor: statusColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 10,
              ),
            ],
          ),
        ),
      ),
    );
  }
}