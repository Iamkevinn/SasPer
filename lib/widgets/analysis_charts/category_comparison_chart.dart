// lib/widgets/analysis_charts/category_comparison_chart.dart
//
// iOS: barras agrupadas este mes vs anterior, panel contextual al tocar,
// sin headers redundantes, colores semánticos azul/teal.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

const _kBlue  = Color(0xFF007AFF);
const _kBlue2 = Color(0xFF5AC8FA);

class CategoryComparisonChart extends StatefulWidget {
  final List<CategorySpendingComparisonData> data;
  const CategoryComparisonChart({super.key, required this.data});

  @override
  State<CategoryComparisonChart> createState() => _CategoryComparisonChartState();
}

class _CategoryComparisonChartState extends State<CategoryComparisonChart> {
  int _touched = -1;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _grid   => _isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context) {
    final filtered = widget.data
        .where((d) => d.currentMonthSpent > 0 || d.previousMonthSpent > 0)
        .toList();

    if (filtered.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final fmtCompact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final allValues = filtered.expand((d) => [d.currentMonthSpent, d.previousMonthSpent]);
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.25;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 20),
      child: Column(
        children: [
          // Panel del item tocado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _touched >= 0
                ? Padding(
                    key: ValueKey(_touched),
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            filtered[_touched].category,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _label),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _pill(_kBlue, 'Este mes: ${fmt.format(filtered[_touched].currentMonthSpent)}'),
                            const SizedBox(height: 4),
                            _pill(_kBlue2, 'Anterior: ${fmt.format(filtered[_touched].previousMonthSpent)}'),
                          ],
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey(-1), height: 0),
          ),

          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  getTooltipItem: (_, __, ___, ____) => null,
                ),
                touchCallback: (event, resp) {
                  setState(() {
                    if (!event.isInterestedForInteractions || resp?.spot == null) {
                      _touched = -1;
                      return;
                    }
                    HapticFeedback.selectionClick();
                    _touched = resp!.spot!.touchedBarGroupIndex;
                  });
                },
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: _grid, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 52,
                    getTitlesWidget: (v, meta) {
                      if (v == 0 || v == meta.max) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(fmtCompact.format(v),
                          style: TextStyle(fontSize: 10, color: _label3),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i >= filtered.length) return const SizedBox.shrink();
                      final cat = filtered[i].category;
                      final lbl = cat.length > 5 ? '${cat.substring(0, 4)}.' : cat;
                      final isHl = i == _touched;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(lbl, style: TextStyle(
                          fontSize: 10,
                          fontWeight: isHl ? FontWeight.w700 : FontWeight.w400,
                          color: isHl ? _label : _label3,
                        )),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(filtered.length, (i) {
                final d = filtered[i];
                final isHl = i == _touched;
                final w = isHl ? 14.0 : 11.0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: d.currentMonthSpent,
                      color: _kBlue.withOpacity(isHl ? 1.0 : 0.8),
                      width: w,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                    BarChartRodData(
                      toY: d.previousMonthSpent,
                      color: _kBlue2.withOpacity(isHl ? 1.0 : 0.7),
                      width: w,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ],
                );
              }),
            )),
          ),

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                _dot(_kBlue, 'Este mes'),
                const SizedBox(width: 16),
                _dot(_kBlue2, 'Mes anterior'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(Color color, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(_isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
  );

  Widget _dot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12, color: _label3)),
    ],
  );
}