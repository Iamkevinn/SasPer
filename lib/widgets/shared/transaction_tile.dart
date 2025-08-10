// lib/widgets/shared/transaction_tile.dart (VERSIÓN FINAL Y RESTAURADA)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart'; 

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onTap;
  final Future<bool> Function()? onDeleted;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.onDeleted,
  });

  Future<void> _showDebtLinkedWarning(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          title: Text('Acción no permitida', style: GoogleFonts.poppins()),
          content: Text(
            "Esta transacción está vinculada a una deuda o préstamo.\n\nPara gestionarla, ve a la sección de Deudas.",
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

@override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String amountText;

    final String title = transaction.description?.isNotEmpty == true
        ? transaction.description!
        : transaction.category ?? 'Sin Descripción';
    
    final String mainSubtitle = transaction.category ?? 'Transferencia';
    
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '');
    
    // NOVEDAD: Definimos el widget del estado de ánimo para reutilizarlo.
    Widget? moodWidget;
    if (transaction.type == 'Gasto' && transaction.mood != null) {
      moodWidget = Padding(
        padding: const EdgeInsets.only(top: 4.0), // Espacio entre subtítulos
        child: Row(
          mainAxisSize: MainAxisSize.min, // Para que el Row no ocupe todo el ancho
          children: [
            Icon(
              transaction.mood!.icon,
              size: 14,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(
              transaction.mood!.displayName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    switch (transaction.type) {
      case 'Ingreso':
        icon = Iconsax.arrow_up_1;
        color = Colors.green.shade600;
        amountText = '+${currencyFormat.format(transaction.amount)}';
        break;
      case 'Gasto':
        icon = Iconsax.arrow_down_2;
        color = Colors.red.shade400;
        amountText = '-${currencyFormat.format(transaction.amount.abs())}';
        break;
      case 'goal_contribution':
        icon = Iconsax.flag;
        color = Theme.of(context).colorScheme.secondary;
        amountText = currencyFormat.format(transaction.amount);
        break;
      default:
        icon = Iconsax.refresh;
        color = Colors.blue.shade400;
        amountText = currencyFormat.format(transaction.amount);
    }

    final tileContent = InkWell(
      onTap: onTap,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        leading: Icon(icon, color: color, size: 28),
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        
        // NOVEDAD: Construimos el subtítulo dinámicamente.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mainSubtitle, style: GoogleFonts.poppins()),
            // Si el widget de mood fue creado, lo añadimos aquí.
            if (moodWidget != null) moodWidget, 
          ],
        ),

        trailing: Text(
          amountText,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: color),
        ),
      ),
    );

    if (onDeleted != null) {
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
          if (transaction.debtId != null) {
            await _showDebtLinkedWarning(context);
            return false;
          }
          return await onDeleted!();
        },
        child: tileContent,
      );
    } else {
      return tileContent;
    }
  }
}