import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

enum BalanceStatus { positive, negative, neutral }

class BalanceCard extends StatelessWidget {
  final double totalBalance;

  const BalanceCard({super.key, required this.totalBalance});

  BalanceStatus get _status => totalBalance > 0
      ? BalanceStatus.positive
      : totalBalance < 0
          ? BalanceStatus.negative
          : BalanceStatus.neutral;

  Color _getStatusColor(BuildContext context) {
    switch (_status) {
      case BalanceStatus.positive:
        return Colors.green.shade400;
      case BalanceStatus.negative:
        return Colors.red.shade400;
      case BalanceStatus.neutral:
        return Theme.of(context).colorScheme.primary;
    }
  }

  IconData get _statusIcon {
    switch (_status) {
      case BalanceStatus.positive:
        return Iconsax.trend_up;
      case BalanceStatus.negative:
        return Iconsax.trend_down;
      case BalanceStatus.neutral:
        return Iconsax.wallet_money;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          border: Border(left: BorderSide(color: statusColor, width: 6)),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Saldo Total Actual',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 16,
                  ),
                ),
                Icon(_statusIcon, color: statusColor, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(totalBalance),
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: statusColor),
            ),
          ],
        ),
      ),
    );
  }
}