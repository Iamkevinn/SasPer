// lib/widgets/analysis_charts/net_worth_trend_chart.dart
//
// iOS: línea curva con área degradada, sin headers redundantes,
// tooltip minimalista, sin bordes, grid sutil.

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

const _kBlue  = Color(0xFF007AFF);
const _kGreen = Color(0xFF34C759);
const _kRed   = Color(0xFFFF3B30);

class NetWorthTrendChart extends StatefulWidget {
  final List<NetWorthDataPoint> data;
  const NetWorthTrendChart({super.key, required this.data});

  @override
  State<NetWorthTrendChart> createState() => _NetWorthTrendChartState();
}

class _NetWorthTrendChartState extends State<NetWorthTrendChart> {
  int _touched = -1;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _grid   => _isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  Color get _lineColor {
    if (widget.data.length < 2) return _kBlue;
    final first = widget.data.first.totalBalance;
    final last  = widget.data.last.totalBalance;
    return last >= first ? _kGreen : _kRed;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) return const SizedBox.shrink();

    final fmt = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final fmtFull = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final spots = List.generate(widget.data.length, (i) =>
        FlSpot(i.toDouble(), widget.data[i].totalBalance));

    final values = widget.data.map((d) => d.totalBalance).toList();
    double minY = values.reduce(min);
    double maxY = values.reduce(max);
    if (minY == maxY) { minY -= 500; maxY += 500; }
    final pad = (maxY - minY) * 0.2;
    minY -= pad; maxY += pad;

    final color = _lineColor;
    final isPositive = widget.data.length < 2 ||
        widget.data.last.totalBalance >= widget.data.first.totalBalance;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 16, 20),
      child: Column(
        children: [
          // Indicador del punto tocado
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _touched >= 0
                ? Padding(
                    key: ValueKey(_touched),
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Row(
                      children: [
                        Text(
                          DateFormat.yMMMM('es_CO').format(widget.data[_touched].monthEnd),
                          style: TextStyle(fontSize: 13, color: _label3),
                        ),
                        const Spacer(),
                        Text(
                          fmtFull.format(widget.data[_touched].totalBalance),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  )
                : Padding(
                    key: const ValueKey(-1),
                    padding: const EdgeInsets.only(left: 16, bottom: 12),
                    child: Row(
                      children: [
                        Text('Patrimonio actual', style: TextStyle(fontSize: 13, color: _label3)),
                        const Spacer(),
                        Icon(
                          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          size: 16, color: color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          fmtFull.format(widget.data.last.totalBalance),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                        ),
                        const SizedBox(width: 16),
                      ],
                    ),
                  ),
          ),
          SizedBox(
            height: 180,
            child: LineChart(LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(color: _grid, strokeWidth: 0.5),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => Colors.transparent,
                  tooltipPadding: EdgeInsets.zero,
                  getTooltipItems: (_) => [],
                ),
                touchCallback: (event, resp) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        resp?.lineBarSpots == null ||
                        resp!.lineBarSpots!.isEmpty) {
                      _touched = -1;
                      return;
                    }
                    HapticFeedback.selectionClick();
                    _touched = resp.lineBarSpots!.first.spotIndex;
                  });
                },
              ),
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
                          fmt.format(v),
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
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.toInt();
                      if (i >= widget.data.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          DateFormat.MMM('es_CO').format(widget.data[i].monthEnd),
                          style: TextStyle(fontSize: 11, color: _label3),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: color,
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
                      radius: i == _touched ? 5 : 0,
                      color: color,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}