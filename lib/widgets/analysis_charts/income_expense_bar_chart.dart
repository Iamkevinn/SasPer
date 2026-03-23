// lib/widgets/analysis_charts/income_expense_bar_chart.dart
//
// iOS: barras agrupadas verde/rojo sin gradientes, sin headers redundantes,
// tooltip que muestra el mes y ambos valores.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

const _kGreen = Color(0xFF34C759);
const _kRed   = Color(0xFFFF3B30);

class IncomeExpenseBarChart extends StatefulWidget {
  final List<MonthlyIncomeExpenseSummaryData> data;
  const IncomeExpenseBarChart({super.key, required this.data});

  @override
  State<IncomeExpenseBarChart> createState() => _IncomeExpenseBarChartState();
}

class _IncomeExpenseBarChartState extends State<IncomeExpenseBarChart> {
  int _touched = -1;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _grid   => _isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final fmtFull = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final allValues = widget.data.expand((d) => [d.totalIncome, d.totalExpense]);
    final maxY = allValues.reduce((a, b) => a > b ? a : b) * 1.25;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 20),
      child: Column(
        children: [
          // Panel del mes seleccionado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _touched >= 0
                ? Padding(
                    key: ValueKey(_touched),
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          DateFormat.yMMMM('es_CO').format(widget.data[_touched].monthStart),
                          style: TextStyle(fontSize: 13, color: _label3),
                        ),
                        const Spacer(),
                        _miniPill(_kGreen, fmtFull.format(widget.data[_touched].totalIncome)),
                        const SizedBox(width: 8),
                        _miniPill(_kRed, fmtFull.format(widget.data[_touched].totalExpense)),
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
                        child: Text(fmt.format(v),
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
                final d = widget.data[i];
                final isTouched = i == _touched;
                final w = isTouched ? 14.0 : 11.0;
                return BarChartGroupData(
                  x: i,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: d.totalIncome,
                      color: _kGreen.withOpacity(isTouched ? 1.0 : 0.75),
                      width: w,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                    ),
                    BarChartRodData(
                      toY: d.totalExpense,
                      color: _kRed.withOpacity(isTouched ? 1.0 : 0.75),
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
                _legendDot(_kGreen, 'Ingresos'),
                const SizedBox(width: 16),
                _legendDot(_kRed, 'Gastos'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniPill(Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(_isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
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