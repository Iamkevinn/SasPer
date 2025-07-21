// lib/widgets/shared/transaction_tile.dart (VERSIÓN FINAL CORREGIDA)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../../models/transaction_models.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onTap;
  final Future<bool> Function() onDeleted;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDeleted,
  });

  // Este diálogo es específico de este widget, así que está bien que se quede aquí.
  Future<void> _showDebtLinkedWarning(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          title: Text('Acción no permitida', style: GoogleFonts.poppins()),
          content: Text(
            "Esta transacción está vinculada a la deuda o préstamo '${transaction.description}'.\n\nPara gestionarla, ve a la sección de Deudas.",
            style: GoogleFonts.poppins(),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  // 1. ELIMINADO: El método _showDeleteConfirmationDialog se ha quitado.
  // La pantalla padre ahora es responsable de mostrar la confirmación.

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String amountText;
    final String title = transaction.category ?? 'Sin categoría';
    final String subtitle = transaction.description ?? '';

    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    switch (transaction.type) {
      case 'Ingreso':
        icon = Iconsax.arrow_up_1;
        color = Colors.green.shade600;
        amountText = '+${currencyFormat.format(transaction.amount)}';
        break;
      case 'Gasto':
        icon = Iconsax.arrow_down_2;
        color = Colors.red.shade400;
        // 2. CORRECCIÓN: Usamos .abs() para evitar el doble signo negativo.
        amountText = '-${currencyFormat.format(transaction.amount.abs())}';
        break;
      case 'goal_contribution':
        icon = Iconsax.flag;
        color = Theme.of(context).colorScheme.secondary;
        amountText = currencyFormat.format(transaction.amount); // El monto ya es negativo
        break;
      default: // Incluye transferencias y otros tipos no definidos
        icon = Iconsax.refresh;
        color = Colors.blue.shade400;
        amountText = currencyFormat.format(transaction.amount);
    }

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        child: Icon(Iconsax.trash, color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        
        // Primero, comprobamos si la transacción está bloqueada.
        if (transaction.debtId != null) {
          // 3. ACTIVADO: Mostramos la advertencia y prevenimos el borrado.
          await _showDebtLinkedWarning(context);
          return false;
        }
        
        // Si no está bloqueada, delegamos la acción de borrado (que incluye el diálogo) al padre.
        return await onDeleted();
      },
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          leading: Icon(icon, color: color, size: 28),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
          subtitle: subtitle.isNotEmpty ? Text(subtitle, style: GoogleFonts.poppins()) : null,
          trailing: Text(
            amountText,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: color),
          ),
        ),
      ),
    );
  }
}