// lib/widgets/analysis_charts/base_chart_card.dart

import 'package:flutter/material.dart';

class BaseChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget chart;

  const BaseChartCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28.0),
          child: Text(
            subtitle,
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 24),
        // Contenedor del Gráfico
        Container(
          height: 300,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: chart,
        ),
      ],
    );
  }
}