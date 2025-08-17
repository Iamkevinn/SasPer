// lib/widgets/shared/budget_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/budget_models.dart'; // ¡Importa el nuevo modelo `Budget`!

class BudgetCard extends StatelessWidget {
  // --- ¡CAMBIO CLAVE! El widget ahora espera un objeto `Budget` ---
  final Budget budget;
  final VoidCallback? onTap;
  final VoidCallback? onEdit; // Lo mantenemos por si lo necesitas en el futuro
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

    // La lógica para obtener el estado y el color sigue funcionando gracias a los getters del modelo.
    final status = budget.status;
    final statusColor = status.getColor(context);

    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final spentText = currencyFormat.format(budget.spentAmount);
    final totalText = currencyFormat.format(budget.amount);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      // Hacemos que las tarjetas inactivas se vean diferentes.
      color: budget.isActive ? statusColor.withOpacity(0.1) : theme.cardColor.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: budget.isActive ? statusColor.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
          width: 1
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        hoverColor: statusColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.category,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // --- ¡NUEVO! Mostramos el periodo del presupuesto ---
                        Text(
                          budget.periodText,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onEdit != null || onDelete != null)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(leading: Icon(Iconsax.edit), title: Text('Editar')),
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
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(spentText, style: textTheme.titleSmall?.copyWith(color: statusColor, fontWeight: FontWeight.bold)),
                  Text(totalText, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: budget.progress.clamp(0.0, 1.0), // Clamp para evitar que la barra se pase de 100%
                borderRadius: BorderRadius.circular(8),
                backgroundColor: statusColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 10,
              ),
              // --- ¡NUEVO! Mostramos los días restantes si el presupuesto está activo ---
              if (budget.isActive) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Iconsax.clock, size: 12, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Quedan ${budget.daysLeft} ${budget.daysLeft == 1 ? "día" : "días"}',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    )
                  ],
                )
              ]
            ],
          ),
        ),
      ),
    );
  }
}