// lib/widgets/analysis_charts/mood_by_day_chart.dart
//
// iOS: barras apiladas por día de la semana, cada mood con su color semántico,
// sin Card anidada, leyenda compacta en fila.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/models/mood_by_day_analysis_model.dart';

class MoodByDayChart extends StatefulWidget {
  final List<MoodByDayAnalysis> analysisData;
  const MoodByDayChart({super.key, required this.analysisData});

  @override
  State<MoodByDayChart> createState() => _MoodByDayChartState();
}

class _MoodByDayChartState extends State<MoodByDayChart> {
  int _touched = -1;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _grid   => _isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  static const _moodColors = {
    TransactionMood.necesario:   Color(0xFF636366),
    TransactionMood.planificado: Color(0xFF007AFF),
    TransactionMood.impulsivo:   Color(0xFFFF3B30),
    TransactionMood.social:      Color(0xFFAF52DE),
    TransactionMood.emocional:   Color(0xFFFF9F0A),
  };

  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // Calcular total por día para maxY
    final Map<int, double> totals = {};
    for (final item in widget.analysisData) {
      totals[item.dayOfWeek] = (totals[item.dayOfWeek] ?? 0) + item.totalSpent.abs();
    }
    final maxY = totals.isEmpty ? 100.0 : totals.values.reduce((a, b) => a > b ? a : b) * 1.3;
    final moods = _moodColors.keys.toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Detalle del día tocado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _touched >= 0
                ? Padding(
                    key: ValueKey(_touched),
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dayNames[(_touched - 1).clamp(0, 6)],
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _label),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: moods.map((mood) {
                            final dayData = widget.analysisData
                                .where((d) => d.dayOfWeek == _touched && d.mood == mood)
                                .firstOrNull;
                            if (dayData == null || dayData.totalSpent == 0) {
                              return const SizedBox.shrink();
                            }
                            final color = _moodColors[mood]!;
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(_isDark ? 0.15 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${mood.displayName}: ${fmt.format(dayData.totalSpent.abs())}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey(-1), height: 0),
          ),

          SizedBox(
            height: 200,
            child: BarChart(BarChartData(
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
                    _touched = resp!.spot!.touchedBarGroupIndex + 1;
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
                    reservedSize: 28,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt() - 1;
                      if (i < 0 || i >= _dayLabels.length) return const SizedBox.shrink();
                      final isSelected = (v.toInt()) == _touched;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _dayLabels[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? _label : _label3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(7, (dayIndex) {
                final day = dayIndex + 1;
                final isSelected = day == _touched;
                return BarChartGroupData(
                  x: day,
                  barRods: moods.map((mood) {
                    final item = widget.analysisData
                        .where((d) => d.dayOfWeek == day && d.mood == mood)
                        .firstOrNull;
                    final color = _moodColors[mood]!;
                    return BarChartRodData(
                      toY: item?.totalSpent.abs() ?? 0,
                      color: color.withOpacity(isSelected ? 1.0 : 0.7),
                      width: isSelected ? 7 : 5,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                    );
                  }).toList(),
                );
              }),
            )),
          ),

          const SizedBox(height: 16),

          // Leyenda compacta
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Wrap(
              spacing: 14,
              runSpacing: 8,
              children: _moodColors.entries.map((e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: e.value, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(e.key.displayName, style: TextStyle(fontSize: 11, color: _label3)),
                ],
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}