// lib/widgets/analysis_charts/average_analysis_section.dart
//
// iOS: número grande con contexto, lista de categorías con barra de progreso
// proporcional, sin Card anidada ni google_fonts.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

class AverageAnalysisSection extends StatelessWidget {
  final MonthlyAverageResult monthlyData;
  final List<CategoryAverageResult> categoryData;

  const AverageAnalysisSection({
    super.key,
    required this.monthlyData,
    required this.categoryData,
  });

  bool _isDark(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark;
  Color _label(BuildContext ctx) => _isDark(ctx) ? Colors.white : const Color(0xFF1C1C1E);
  Color _label2(BuildContext ctx) => _isDark(ctx) ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color _label3(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color _sep(BuildContext ctx) => _isDark(ctx) ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  Color _hexToColor(String? code) {
    if (code == null || code.isEmpty) return const Color(0xFF636366);
    try {
      return Color(int.parse(code.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (_) {
      return const Color(0xFF636366);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final fmtCompact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    // El máximo para escalar las barras de progreso
    final maxAvg = categoryData.isEmpty
        ? 1.0
        : categoryData.map((c) => c.averageAmount).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Promedio mensual total ────────────────────────────────────
          Center(
            child: Column(
              children: [
                Text(
                  'Gasto mensual promedio',
                  style: TextStyle(fontSize: 13, color: _label3(context)),
                ),
                const SizedBox(height: 6),
                Text(
                  fmt.format(monthlyData.averageSpending),
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF007AFF),
                    letterSpacing: -1,
                  ),
                ),
                if (monthlyData.monthCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Basado en ${monthlyData.monthCount} ${monthlyData.monthCount == 1 ? 'mes' : 'meses'}',
                    style: TextStyle(fontSize: 12, color: _label3(context)),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          Divider(height: 0.5, thickness: 0.5, color: _sep(context)),

          const SizedBox(height: 20),

          Text(
            'POR CATEGORÍA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: _label3(context),
            ),
          ),

          const SizedBox(height: 12),

          ...categoryData.map((item) {
            final color = _hexToColor(item.color);
            final ratio = maxAvg > 0 ? (item.averageAmount / maxAvg).clamp(0.0, 1.0) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.categoryName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _label2(context),
                          ),
                        ),
                      ),
                      Text(
                        fmtCompact.format(item.averageAmount),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _label(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Barra de progreso proporcional
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 3,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.7)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}