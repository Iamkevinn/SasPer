import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/budget_models.dart';

class BudgetCard extends StatelessWidget {
  final BudgetProgress budget;

  const BudgetCard({super.key, required this.budget});

  @override
  Widget build(BuildContext context) {
    final status = budget.status;
    final statusColor = status.getColor(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget.category,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
              Icon(status.icon, color: statusColor, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            '${NumberFormat.currency(symbol: '\$').format(budget.spentAmount)} de ${NumberFormat.currency(symbol: '\$').format(budget.budgetAmount)}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: budget.progress.clamp(0.0, 1.0),
            borderRadius: BorderRadius.circular(8),
            backgroundColor: statusColor.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            minHeight: 8,
          ),
        ],
      ),
    );
  }
}