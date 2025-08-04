// lib/widgets/analysis/insight_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/models/insight_model.dart';

class InsightCard extends StatelessWidget {
  final Insight insight;
  final VoidCallback? onTap; // Para futuras interacciones

  const InsightCard({
    super.key,
    required this.insight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = insight.severity.getColor(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      // Usamos `ClipRRect` y `Container` con gradiente para un efecto más premium
      // que una simple `Card`. Esto se alinea con tu estilo Glassmorphism/Material You.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey.withOpacity(0.3),
          width: 1,
        ),
        gradient: LinearGradient(
          colors: [
            cardColor.withOpacity(isDark ? 0.15 : 0.4),
            cardColor.withOpacity(isDark ? 0.05 : 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono con un círculo de fondo para mayor impacto visual
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: cardColor.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    insight.severity.icon,
                    color: cardColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                // Contenido de texto expandido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insight.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}// TODO Implement this library.