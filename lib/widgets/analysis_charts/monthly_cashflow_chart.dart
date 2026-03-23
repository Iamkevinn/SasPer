// lib/widgets/analysis_charts/monthly_cashflow_chart.dart
//
// iOS: barras con colores semánticos (verde/rojo), sin headers redundantes,
// tooltip limpio, grid .5px, sin bordes.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

const _kGreen  = Color(0xFF34C759);
const _kRed    = Color(0xFFFF3B30);
const _kOrange = Color(0xFFFF9F0A);

class MonthlyCashflowChart extends StatefulWidget {
  final List<MonthlyCashflowData> data;
  const MonthlyCashflowChart({super.key, required this.data});

  @override
  State<MonthlyCashflowChart> createState() => _MonthlyCashflowChartState();
}

class _MonthlyCashflowChartState extends State<MonthlyCashflowChart> {
  int _touched = -1;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _grid => _isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  Color _barColor(double v) {
    if (v > 0) return _kGreen;
    if (v < 0) return _kRed;
    return _kOrange;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final fmtCompact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final values = widget.data.map((d) => d.cashFlow).toList();
    final minY = (values.reduce((a, b) => a < b ? a : b) * 1.25).floorToDouble();
    final maxY = (values.reduce((a, b) => a > b ? a : b) * 1.25).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 20),
      child: Column(
        children: [
          // Indicador del mes tocado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _touched >= 0
                ? Padding(
                    key: ValueKey(_touched),
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _barColor(widget.data[_touched].cashFlow),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat.yMMMM('es_CO').format(widget.data[_touched].monthStart),
                          style: TextStyle(fontSize: 13, color: _label3),
                        ),
                        const Spacer(),
                        Text(
                          fmt.format(widget.data[_touched].cashFlow),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _barColor(widget.data[_touched].cashFlow),
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  )
                : const SizedBox(key: ValueKey(-1), height: 0),
          ),
          SizedBox(
            height: 180,
            child: BarChart(BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: minY,
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
                checkToShowHorizontalLine: (v) => v == 0,
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
                      if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          fmtCompact.format(v),
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
                      if (i >= widget.data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat.MMM('es_CO').format(widget.data[i].monthStart),
                          style: TextStyle(fontSize: 11, color: _label3),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(widget.data.length, (i) {
                final v = widget.data[i].cashFlow;
                final isTouched = i == _touched;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v,
                      color: _barColor(v).withOpacity(isTouched ? 1.0 : 0.75),
                      width: isTouched ? 20 : 16,
                      borderRadius: v >= 0
                          ? const BorderRadius.vertical(top: Radius.circular(6))
                          : const BorderRadius.vertical(bottom: Radius.circular(6)),
                    ),
                  ],
                );
              }),
            )),
          ),
          const SizedBox(height: 16),
          // Leyenda compacta
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                _legendDot(_kGreen, 'Flujo positivo'),
                const SizedBox(width: 16),
                _legendDot(_kRed, 'Flujo negativo'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: _label3)),
      ],
    );
  }
}