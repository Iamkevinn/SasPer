// lib/widgets/shared/budget_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget_models.dart';

class BudgetCard extends StatelessWidget {
  final BudgetProgress budget;
  // 1. AÑADIMOS UN CALLBACK OPCIONAL para cuando se toca la tarjeta
  final VoidCallback? onTap;

  const BudgetCard({
    super.key, 
    required this.budget,
    this.onTap,
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
                  Icon(status.icon, color: statusColor, size: 20),
                ],
              ),
              const Spacer(), // Ocupa el espacio disponible para empujar el resto hacia abajo
              Text.rich(
                TextSpan(
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  children: [
                    TextSpan(
                      text: spentText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    TextSpan(text: ' de $totalText'),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: budget.progress, // clamp ya no es necesario si el modelo lo hace
                borderRadius: BorderRadius.circular(8),
                backgroundColor: statusColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                minHeight: 8,
              ),
            ],
          ),
        ),
      ),
    );
  }
}