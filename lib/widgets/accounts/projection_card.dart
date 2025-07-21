// lib/widgets/accounts/projection_card.dart (REFACTORIZADO)

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';

class ProjectionCard extends StatelessWidget {
  // 1. Recibe el número de días directamente. Ya no necesita el accountId.
  final double daysLeft;

  const ProjectionCard({super.key, required this.daysLeft});

  // La lógica de formato es una responsabilidad de este widget, está bien aquí.
  String _formatDays(double days) {
    if (days == -1) return "Fondos estables";
    if (days <= 0) return "Fondos agotados";
    if (days < 30) return "${days.toStringAsFixed(0)} días";
    
    final months = days / 30;
    if (months < 12) return "${months.toStringAsFixed(1)} meses";
    
    final years = months / 12;
    return "${years.toStringAsFixed(1)} años";
  }

  @override
  Widget build(BuildContext context) {
    // 2. No más FutureBuilder. El widget asume que no se renderizará
    // si no hay datos (la pantalla contenedora se encargará de eso).
    if (daysLeft == 0) {
      return const SizedBox.shrink(); // No mostrar nada si la proyección es 0
    }

    final projectionText = _formatDays(daysLeft);
    final isStable = daysLeft == -1;
    final color = isStable ? Colors.blue.shade300 : Colors.orange.shade400;

    return Container(
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isStable ? Iconsax.shield_tick : Iconsax.timer_1, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isStable ? projectionText : "Proyección: $projectionText restantes",
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 3. El Shimmer se convierte en un constructor estático para que
  // la pantalla contenedora pueda usarlo fácilmente.
  static Widget buildShimmer(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.only(top: 8, left: 16, right: 16),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}