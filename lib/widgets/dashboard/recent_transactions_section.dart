// lib/widgets/dashboard/recent_transactions_section.dart (CORREGIDO Y COMPLETO)

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';

class RecentTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onViewAllPressed;
  
  // 1. AÑADIDO: Callbacks para manejar las acciones de los tiles.
  final void Function(Transaction transaction) onTransactionTapped;
  final Future<bool> Function(Transaction transaction) onTransactionDeleted;


  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    this.onViewAllPressed,
    // Los hacemos requeridos en el constructor
    required this.onTransactionTapped,
    required this.onTransactionDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: transactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(context), // Pasamos el contexto
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Movimientos Recientes',
            style: GoogleFonts.poppins(
              textStyle: Theme.of(context).textTheme.titleLarge,
              fontWeight: FontWeight.bold
            ),
          ),
          if (onViewAllPressed != null)
            TextButton(
              onPressed: onViewAllPressed,
              child: const Text('Ver Todos'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      key: ValueKey('empty_state'),
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Center(
        child: EmptyStateCard(
          title: "Sin Movimientos",
          message: "Cuando añadas tu primera transacción, aparecerá aquí.",
          icon: Iconsax.receipt,
        ),
      ),
    );
  }

  Widget _buildTransactionList(BuildContext context) {
    return AnimationLimiter(
      key: const ValueKey('transaction_list'),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length > 5 ? 5 : transactions.length, // Mostramos un máximo de 5
        itemBuilder: (context, index) {
          final transaction = transactions[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 400),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: TransactionTile(
                  transaction: transaction,
                  // 2. Pasamos la función correspondiente al tile.
                  // Se crea una función anónima que llama al callback con la transacción actual.
                  onTap: () => onTransactionTapped(transaction),
                  
                  // 2. Hacemos lo mismo para la función de borrado.
                  onDeleted: () => onTransactionDeleted(transaction),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}