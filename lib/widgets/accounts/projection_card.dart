// lib/widgets/accounts/projection_card.dart (CÓDIGO FINAL Y LIMPIO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';

class ProjectionCard extends StatelessWidget {
  final double daysLeft;

  const ProjectionCard({super.key, required this.daysLeft});

  // La lógica de formato ya está preparada para manejar el valor 9999
  String _formatDays(double days) {
    if (days >= 9999) return "Sin gastos recientes"; // Caso "infinito"
    if (days <= 0) return "Fondos agotados";
    if (days < 30) return "${days.toStringAsFixed(0)} días restantes";
    
    final months = days / 30;
    if (months < 12) return "${months.toStringAsFixed(1)} meses restantes";
    
    final years = months / 12;
    return "${years.toStringAsFixed(1)} años restantes";
  }

  @override
  Widget build(BuildContext context) {
    // La lógica de la UI decide qué mostrar basado en el valor de daysLeft.
    // La pantalla contenedora ya se encarga de no llamar a este widget si daysLeft es <= 0.
    
    final isStable = daysLeft >= 9999;
    final projectionText = _formatDays(daysLeft);
    final theme = Theme.of(context);
    
    // Asignamos colores e iconos basados en el estado
    final Color color;
    final IconData icon;

    if (isStable) {
      color = Colors.green;
      icon = Iconsax.shield_tick;
    } else if (daysLeft < 30) {
      color = theme.colorScheme.error; // Rojo para proyecciones cortas
      icon = Iconsax.warning_2;
    } else {
      color = Colors.orange.shade600; // Naranja para proyecciones medias
      icon = Iconsax.timer_1;
    }

    return Container(
      // Ya no tiene el color de depuración
      margin: const EdgeInsets.only(top: 8), // El padding lateral ya está en la pantalla
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              projectionText,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface, // Color de texto estándar y legible
              ),
            ),
          ),
        ],
      ),
    );
  }

  // El Shimmer no necesita cambios, está perfecto.
  static Widget buildShimmer(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}