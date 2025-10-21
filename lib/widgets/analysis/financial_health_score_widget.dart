// lib/widgets/analysis/financial_health_score_widget.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class FinancialHealthScoreWidget extends StatelessWidget {
  final double score;
  final VoidCallback onTap;

  const FinancialHealthScoreWidget({
    super.key,
    required this.score,
    required this.onTap,
  });

  Color _getColorForScore(double s) {
    if (s > 80) return Colors.green.shade400;
    if (s > 60) return Colors.teal.shade400;
    if (s > 40) return Colors.amber.shade500;
    return Colors.red.shade400;
  }

  String _getTextForScore(double s) {
    if (s > 80) return "Excelente";
    if (s > 60) return "Saludable";
    if (s > 40) return "Mejorable";
    return "En Riesgo";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scoreColor = _getColorForScore(score);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: theme.colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              CircularPercentIndicator(
                radius: 35.0,
                lineWidth: 8.0,
                animation: true,
                animationDuration: 1200,
                percent: score / 100,
                center: Text(
                  score.toInt().toString(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: scoreColor,
                  ),
                ),
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                progressColor: scoreColor,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Salud Financiera',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu puntaje es ${_getTextForScore(score).toLowerCase()}. Toca para ver cómo mejorarlo.',
                       style: theme.textTheme.bodyMedium?.copyWith(
                         color: theme.colorScheme.onSurfaceVariant,
                       ),
                    ),
                  ],
                ),
              ),
              Icon(Iconsax.arrow_right_3, color: theme.colorScheme.onSurfaceVariant)
            ],
          ),
        ),
      ),
    );
  }
}