// lib/widgets/dashboard/recent_transactions_section.dart (VERSIÓN SIN ANIMACIONES PARA DEPURACIÓN FINAL)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';

class RecentTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  final VoidCallback? onViewAllPressed;
  final void Function(Transaction transaction) onTransactionTapped;
  final Future<bool> Function(Transaction transaction) onTransactionDeleted;

  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    this.onViewAllPressed,
    required this.onTransactionTapped,
    required this.onTransactionDeleted,
  });

  @override
  Widget build(BuildContext context) {
    // La estructura del Column y el AnimatedSwitcher se mantiene
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: transactions.isEmpty
              ? _buildEmptyState()
              // Llamamos a la nueva versión de _buildTransactionList
              : _buildTransactionListWithoutAnimations(), 
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    // El header no es el problema
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Movimientos Recientes',
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(context).textTheme.titleLarge,
                  fontWeight: FontWeight.bold)),
          if (onViewAllPressed != null)
            TextButton(onPressed: onViewAllPressed, child: const Text('Ver Todos')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    // El estado vacío no es el problema
    return const Padding(
      key: ValueKey('empty_state'),
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
      child: Center(
          child: EmptyStateCard(
              title: "Sin Movimientos",
              message: "Cuando añadas tu primera transacción, aparecerá aquí.",
              icon: Iconsax.receipt)),
    );
  }

  // --- MÉTODO DE PRUEBA: SE HAN ELIMINADO TODAS LAS ANIMACIONES ---
  Widget _buildTransactionListWithoutAnimations() {
    final recent = transactions.take(5).toList();

    // Usamos un Column simple que genera los TransactionTile directamente.
    // SIN AnimationLimiter, SIN AnimationConfiguration, SIN SlideAnimation.
    return Column(
      key: const ValueKey('transaction_list'), // Key para el AnimatedSwitcher
      children: recent.map((transaction) {
        // Mapeamos cada transacción a un TransactionTile
        return TransactionTile(
          transaction: transaction,
          onTap: () => onTransactionTapped(transaction),
          onDeleted: () => onTransactionDeleted(transaction),
        );
      }).toList(), // Convertimos el resultado del map en una lista de widgets
    );
  }
}