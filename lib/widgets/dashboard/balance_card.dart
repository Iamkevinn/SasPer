// lib/widgets/dashboard/balance_card.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// 1. EL ENUM SE MANTIENE, pero la lógica se moverá a una extensión.
enum BalanceStatus { positive, negative, neutral }

// 2. EXTENSIÓN SOBRE EL ENUM para encapsular la lógica de presentación.
extension BalanceStatusX on BalanceStatus {
  Color getColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (this) {
      case BalanceStatus.positive:
        // Usamos el color primario del tema para positivo.
        return colorScheme.primary; 
      case BalanceStatus.negative:
        // Usamos el color de error del tema para negativo.
        return colorScheme.error; 
      case BalanceStatus.neutral:
        // Usamos un color secundario o variante para neutro.
        return colorScheme.onSurfaceVariant;
    }
  }

  IconData get icon {
    switch (this) {
      case BalanceStatus.positive:
        return Iconsax.trend_up;
      case BalanceStatus.negative:
        return Iconsax.trend_down;
      case BalanceStatus.neutral:
        return Iconsax.wallet_money;
    }
  }
}

class BalanceCard extends StatelessWidget {
  final double totalBalance;

  const BalanceCard({super.key, required this.totalBalance});
  
  // 3. El GETTER para el estado ahora es más simple.
  BalanceStatus get _status => totalBalance > 0
      ? BalanceStatus.positive
      : totalBalance < 0
          ? BalanceStatus.negative
          : BalanceStatus.neutral;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Obtenemos los atributos visuales desde la extensión del enum
    final statusColor = _status.getColor(context);
    final statusIcon = _status.icon;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      // Usamos un color de fondo más sutil del tema
      color: colorScheme.surface.withAlpha(100), 
      child: Container(
        // La barra lateral de color se mantiene, es un gran detalle de diseño
        decoration: BoxDecoration(
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
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Icon(statusIcon, color: statusColor, size: 24),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(totalBalance),
              style: textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
                letterSpacing: -1, // Un kerning negativo sutil para números grandes
              ),
            ),
          ],
        ),
      ),
    );
  }
}