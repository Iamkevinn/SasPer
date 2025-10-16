// lib/widgets/debts/debt_card.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/debt_model.dart';

// 1. El enum ya está correctamente actualizado
enum DebtCardAction { registerPayment, edit, delete, share }

class DebtCard extends StatelessWidget {
  final Debt debt;
  final Function(DebtCardAction) onActionSelected;
  
  const DebtCard({
    super.key,
    required this.debt,
    required this.onActionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Simplificamos la lógica de presentación
    final isDebt = debt.type == DebtType.debt;
    final progressColor = isDebt ? colorScheme.primary : colorScheme.secondary;
    final title = debt.name; // Usamos el nombre directo

    return Card(
      elevation: 0.5,
      margin: const EdgeInsets.only(bottom: 12.0), // Margen estándar para cada tarjeta
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: colorScheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onActionSelected(DebtCardAction.registerPayment),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, title),
              const SizedBox(height: 16),
              _buildProgressSection(context, progressColor),
              const SizedBox(height: 12),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS HELPER ---

  Widget _buildHeader(BuildContext context, String title) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (debt.entityName != null && debt.entityName!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  debt.entityName!,
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        
        // --- POPUPMENU ACTUALIZADO ---
        PopupMenuButton<DebtCardAction>(
          onSelected: onActionSelected,
          icon: Icon(Iconsax.more, color: colorScheme.onSurfaceVariant),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<DebtCardAction>>[
            const PopupMenuItem<DebtCardAction>(
              value: DebtCardAction.registerPayment,
              child: ListTile(
                leading: Icon(Iconsax.wallet_add_1),
                title: Text('Registrar Pago/Cobro'),
              ),
            ),
            const PopupMenuItem<DebtCardAction>(
              value: DebtCardAction.edit,
              child: ListTile(
                leading: Icon(Iconsax.edit),
                title: Text('Editar Información'),
              ),
            ),
            // 2. AÑADIMOS LA OPCIÓN DE COMPARTIR
            const PopupMenuItem<DebtCardAction>(
              value: DebtCardAction.share,
              child: ListTile(
                leading: Icon(Iconsax.share),
                title: Text('Compartir Resumen'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<DebtCardAction>(
              value: DebtCardAction.delete,
              child: ListTile(
                leading: Icon(Iconsax.trash, color: Colors.red),
                title: Text('Eliminar', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildProgressSection(BuildContext context, Color progressColor) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: textTheme.bodyLarge,
            children: [
              TextSpan(
                text: currencyFormat.format(debt.paidAmount),
                style: TextStyle(fontWeight: FontWeight.bold, color: progressColor),
              ),
              TextSpan(
                text: ' / ${currencyFormat.format(debt.initialAmount)}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: debt.progress,
          backgroundColor: colorScheme.surfaceContainerHighest,
          color: progressColor,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isOverdue = debt.dueDate != null && debt.status == DebtStatus.active && debt.dueDate!.isBefore(DateTime.now());

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Restante: ${currencyFormat.format(debt.currentBalance)}',
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (debt.dueDate != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isOverdue ? colorScheme.errorContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.calendar_1,
                  size: 14,
                  color: isOverdue ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Vence: ${DateFormat.yMMMd('es_CO').format(debt.dueDate!)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: isOverdue ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}