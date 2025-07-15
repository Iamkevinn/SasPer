import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../models/transaction_models.dart';
import '../shared/empty_state_card.dart';
import '../shared/transaction_tile.dart';

class RecentTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  // CAMBIO CLAVE: Los callbacks han desaparecido del constructor.
  const RecentTransactionsSection({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context) {
    return AnimationLimiter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Movimientos Recientes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          if (transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 32.0),
              child: Center(
                child: EmptyStateCard(
                  title: "Sin Movimientos",
                  message: "Cuando añadas una transacción, aparecerá aquí.",
                  icon: Icons.receipt_long,
                ),
              ),  
            )
          else
            ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                return AnimationConfiguration.staggeredList(
                  position: index,
                  duration: const Duration(milliseconds: 400),
                  child: SlideAnimation(
                    verticalOffset: 50.0,
                    child: FadeInAnimation(
                      // CAMBIO FINAL: TransactionTile ya no necesita los callbacks.
                      child: TransactionTile(
                        transaction: transactions[index],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}