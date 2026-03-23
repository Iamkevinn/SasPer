// lib/widgets/analysis_charts/mood_spending_analysis_card.dart
//
// iOS: selector de mood como chips compactos sin bordes gruesos,
// barras con color semántico del mood, sin Card anidada (el ChartCard del padre la provee).

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/models/mood_analysis_model.dart';

class MoodSpendingAnalysisCard extends StatefulWidget {
  final List<MoodAnalysis> analysisData;
  const MoodSpendingAnalysisCard({super.key, required this.analysisData});

  @override
  State<MoodSpendingAnalysisCard> createState() => _MoodSpendingAnalysisCardState();
}

class _MoodSpendingAnalysisCardState extends State<MoodSpendingAnalysisCard> {
  late List<TransactionMood> _available;
  late TransactionMood _selected;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _label2 => _isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get _grid   => _isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);
  Color get _surface2 => _isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

  static const _moodColors = {
    TransactionMood.necesario:   Color(0xFF636366),
    TransactionMood.planificado: Color(0xFF007AFF),
    TransactionMood.impulsivo:   Color(0xFFFF3B30),
    TransactionMood.social:      Color(0xFFAF52DE),
    TransactionMood.emocional:   Color(0xFFFF9F0A),
  };

  @override
  void initState() {
    super.initState();
    _available = widget.analysisData.map((e) => e.mood).toSet().toList()
      ..sort((a, b) => a.index.compareTo(b.index));
    _selected = _available.isNotEmpty ? _available.first : TransactionMood.necesario;
  }

  Color _colorFor(TransactionMood mood) =>
      _moodColors[mood] ?? const Color(0xFF636366);

  @override
  Widget build(BuildContext context) {
    final filtered = widget.analysisData
        .where((d) => d.mood == _selected)
        .toList()
      ..sort((a, b) => a.totalSpent.compareTo(b.totalSpent));

    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final maxY = filtered.isEmpty
        ? 100.0
        : filtered.map((d) => d.totalSpent.abs()).reduce((a, b) => a > b ? a : b) * 1.3;

    final color = _colorFor(_selected);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Selector de moods — chips compactos iOS
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _available.map((mood) {
                final isSelected = mood == _selected;
                final moodColor = _colorFor(mood);
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selected = mood);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? moodColor.withOpacity(_isDark ? 0.2 : 0.12)
                          : _surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(mood.icon, size: 14,
                            color: isSelected ? moodColor : _label3),
                        const SizedBox(width: 5),
                        Text(
                          mood.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? moodColor : _label3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Sin gastos con estado "${_selected.displayName}"',
                  style: TextStyle(fontSize: 14, color: _label3),
                ),
              ),
            )
          else
            SizedBox(
              height: 200,
              child: BarChart(BarChartData(
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => _isDark
                        ? const Color(0xFF2C2C2E)
                        : Colors.white,
                    tooltipBorder: BorderSide(color: _grid, width: 0.5),
                    tooltipBorderRadius: BorderRadius.circular(8),
                    getTooltipItem: (group, groupIndex, rod, _) {
                      final item = filtered[groupIndex];
                      return BarTooltipItem(
                        item.category,
                        TextStyle(
                          color: _label,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        children: [
                          TextSpan(
                            text: '\n${fmt.format(item.totalSpent.abs())}',
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
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
                      reservedSize: 48,
                      getTitlesWidget: (v, meta) {
                        if (v == 0 || v >= maxY) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '${(v / 1000).abs().toInt()}k',
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
                      reservedSize: 32,
                      getTitlesWidget: (v, meta) {
                        final i = v.toInt();
                        if (i >= filtered.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            filtered[i].category.length > 8
                                ? '${filtered[i].category.substring(0, 7)}…'
                                : filtered[i].category,
                            style: TextStyle(fontSize: 10, color: _label3),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(filtered.length, (i) => BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: filtered[i].totalSpent.abs(),
                      color: color,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                  ],
                )),
              )),
            ),
        ],
      ),
    );
  }
}