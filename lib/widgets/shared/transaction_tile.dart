import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/transaction_models.dart';
import '../../screens/edit_transaction_screen.dart';
import '../../services/event_service.dart';

class TransactionTile extends StatelessWidget {
  final Transaction transaction;
  const TransactionTile({
    super.key,
    required this.transaction,
  });

  // El diálogo de confirmación está perfecto, no necesita cambios.
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
    // --- NUEVA LÓGICA DE VISUALIZACIÓN ---
    IconData icon;
    Color color;
    String amountText;
    String title = transaction.category ?? 'Sin categoría';
    String subtitle = transaction.description ?? '';
    
    // Usamos el `type` de la transacción para decidir cómo se ve.
    // ¡Asegúrate de que los strings coincidan con los de tu base de datos!
    switch (transaction.type) {
      case 'income': // O 'Ingreso' si usas español
        icon = Iconsax.arrow_up_1;
        color = Colors.green;
        amountText = '+${NumberFormat.currency(symbol: '\$').format(transaction.amount)}';
        break;
      case 'expense': // O 'Gasto'
        icon = Iconsax.arrow_down_2;
        color = Colors.redAccent;
        amountText = '-${NumberFormat.currency(symbol: '\$').format(transaction.amount)}';
        break;
      case 'goal_contribution':
        icon = Iconsax.flag; // Ícono de meta
        color = Theme.of(context).colorScheme.secondary; // Un color distintivo
        title = 'Aportación a Meta'; // Título claro
        subtitle = transaction.description ?? ''; // La descripción dirá "Aportación a meta: [Nombre]"
        // El monto de la transacción ya es negativo en la BD, lo mostramos como tal.
        amountText = NumberFormat.currency(symbol: '\$').format(transaction.amount); 
        break;
      case 'transfer':
        icon = Iconsax.refresh; // Ícono de transferencia
        color = Colors.orange;
        title = 'Transferencia';
        // En una transferencia, el monto puede ser positivo o negativo dependiendo de la cuenta,
        // así que lo mostramos con su signo.
        amountText = NumberFormat.currency(symbol: '\$').format(transaction.amount);
        break;
      default:
        icon = Iconsax.wallet_money;
        color = Colors.grey;
        amountText = NumberFormat.currency(symbol: '\$').format(transaction.amount);
    }
    // --- FIN DE LA NUEVA LÓGICA ---

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
            // La lógica de borrado aquí está bien. El trigger en Supabase hará el trabajo pesado.
            await Supabase.instance.client.from('transactions').delete().match({'id': transaction.id});
            if (context.mounted) {
              EventService.instance.emit(AppEvent.transactionDeleted);
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
        onTap: () {
          // La navegación a la pantalla de edición
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => EditTransactionScreen(transaction: transaction.toJson()),
            ),
          );
        },
        child: ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
          trailing: Text(
            amountText,
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ),
    );
  }
}