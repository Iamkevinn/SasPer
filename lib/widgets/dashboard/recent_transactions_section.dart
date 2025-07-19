// lib/widgets/dashboard/recent_transactions_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/transaction_models.dart';
// Asumimos que MainScreen tiene un callback o método para cambiar de pestaña
// import '../../screens/main_screen.dart'; 
import '../shared/empty_state_card.dart';
import '../shared/transaction_tile.dart';

class RecentTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  // 1. AÑADIMOS UN CALLBACK para navegar a la pestaña de transacciones
  final VoidCallback? onViewAllPressed;

  const RecentTransactionsSection({
    super.key,
    required this.transactions,
    this.onViewAllPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        // Usamos un AnimatedSwitcher para una transición suave si la lista pasa de vacía a tener datos
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: transactions.isEmpty
              ? _buildEmptyState()
              : _buildTransactionList(),
        ),
      ],
    );
  }

  // --- WIDGETS HELPER PARA MEJORAR LA ESTRUCTURA ---

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Movimientos Recientes',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          // 2. AÑADIMOS EL BOTÓN "VER TODOS"
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
      key: ValueKey('empty_state'), // Key para el AnimatedSwitcher
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

  Widget _buildTransactionList() {
    return AnimationLimiter(
      key: const ValueKey('transaction_list'), // Key para el AnimatedSwitcher
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: transactions.length,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}