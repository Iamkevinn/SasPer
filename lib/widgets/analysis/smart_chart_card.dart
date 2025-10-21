// lib/widgets/analysis/smart_chart_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartChartCard extends StatelessWidget {
  final String title;
  final String summary;
  final String actionButtonText;
  final VoidCallback onAction;
  final Widget child;

  const SmartChartCard({
    super.key,
    required this.title,
    required this.summary,
    required this.actionButtonText,
    required this.onAction,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            summary,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            // Damos una altura fija al contenedor del gráfico para consistencia
            height: 200,
            child: child,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onAction,
              child: Text(actionButtonText),
            ),
          )
        ],
      ),
    );
  }
}