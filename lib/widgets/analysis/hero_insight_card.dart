// lib/widgets/analysis/hero_insight_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/models/insight_model.dart';

class HeroInsightCard extends StatelessWidget {
  final Insight insight;
  const HeroInsightCard({super.key, required this.insight});

  /// Devuelve el texto del botón de acción basado en el TIPO de insight.
  String _getActionTextForType(InsightType type) {
    switch (type) {
      case InsightType.budget_exceeded:
        return 'Ajustar Presupuesto';
      case InsightType.goal_milestone:
        return 'Ver Meta';
      case InsightType.low_balance_warning:
        return 'Ver Cuentas';
      case InsightType.upcoming_payment:
        return 'Ver Pagos';
      default:
        return 'Ver Detalles';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Usamos la extensión que ya creaste en tu modelo para obtener el icono y el color. ¡Excelente!
    final IconData displayIcon = insight.severity.icon;
    final Color displayColor = insight.severity.getColor(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  displayColor.withOpacity(0.3),
                  theme.colorScheme.tertiaryContainer.withOpacity(0.3)
                ]
              : [
                  displayColor,
                  theme.colorScheme.tertiary
                ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: displayColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(displayIcon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Insight Destacado',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            insight.title,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            insight.description,
            style: GoogleFonts.poppins(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Ignorar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: displayColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(_getActionTextForType(insight.type)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}