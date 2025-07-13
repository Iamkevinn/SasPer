import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/transaction_models.dart';
import '../../screens/edit_transaction_screen.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;

  const TransactionTile({
    super.key,
    required this.transaction,
  });

  Future<bool?> _showDeleteConfirmationDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
            title: const Text('Confirmar eliminación'),
            content: const Text('Esta acción no se puede deshacer. ¿Estás seguro?'),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'Gasto';
    final color = isExpense ? Colors.redAccent : Colors.green;

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
        final confirmed = await _showDeleteConfirmationDialog(context);
        if (confirmed == true) {
          try {
            await Supabase.instance.client.from('transactions').delete().match({'id': transaction.id});
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transacción eliminada'), backgroundColor: Colors.green),
              );
            }
            return true;
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Theme.of(context).colorScheme.error),
              );
            }
          }
        }
        return false;
      },
      child: InkWell(
        onTap: () async {
          // Navegamos a la pantalla de edición
          await Navigator.of(context).push(
            MaterialPageRoute(
              // --- ¡AQUÍ ESTÁ LA CORRECCIÓN! ---
              builder: (context) => EditTransactionScreen(transaction: transaction.toJson()),
            ),
          );
        },
        child: ListTile(
          leading: Icon(
            isExpense ? Iconsax.arrow_down_2 : Iconsax.arrow_up_1,
            color: color,
          ),
          title: Text(transaction.category ?? 'Transferencia'),
          subtitle: (transaction.description != null && transaction.description!.isNotEmpty)
              ? Text(transaction.description!)
              : null,
          trailing: Text(
            '${isExpense ? '-' : '+'}${NumberFormat.currency(symbol: '\$').format(transaction.amount)}',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ),
    );
  }
}