// lib/widgets/analysis_charts/income_pie_chart.dart
//
// iOS: mismo patrón que expense_pie_chart pero paleta verde/azul para ingresos.

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

const _kColors = [
  Color(0xFF34C759),
  Color(0xFF007AFF),
  Color(0xFF5AC8FA),
  Color(0xFFAF52DE),
  Color(0xFF30B0C7),
  Color(0xFF32ADE6),
  Color(0xFF636366),
];

class IncomePieChart extends StatefulWidget {
  final List<IncomeByCategory> data;
  const IncomePieChart({super.key, required this.data});

  @override
  State<IncomePieChart> createState() => _IncomePieChartState();
}

class _IncomePieChartState extends State<IncomePieChart> {
  int _touched = -1;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _label  => _isDark ? Colors.white : const Color(0xFF1C1C1E);
  Color get _label3 => _isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get _label2 => _isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);

  @override
  Widget build(BuildContext context) {
    final total = widget.data.fold<double>(0, (s, e) => s + e.totalIncome);
    if (total == 0) return const SizedBox.shrink();

    final fmt = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final fmtFull = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    final sorted = [...widget.data]..sort((a, b) => b.totalIncome.compareTo(a.totalIncome));
    final top = sorted.take(6).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 54,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, resp) {
                      setState(() {
                        if (!event.isInterestedForInteractions || resp?.touchedSection == null) {
                          _touched = -1;
                          return;
                        }
                        HapticFeedback.selectionClick();
                        _touched = resp!.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  sections: List.generate(top.length, (i) {
                    final isTouched = i == _touched;
                    final pct = top[i].totalIncome / total * 100;
                    return PieChartSectionData(
                      color: _kColors[i % _kColors.length],
                      value: top[i].totalIncome,
                      radius: isTouched ? 56 : 46,
                      title: pct > 8 ? '${pct.toStringAsFixed(0)}%' : '',
                      titleStyle: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white,
                      ),
                    );
                  }),
                )),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _touched >= 0 ? fmt.format(top[_touched].totalIncome) : fmt.format(total),
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                        color: _touched >= 0 ? _kColors[_touched % _kColors.length] : _label,
                      ),
                    ),
                    Text(
                      _touched >= 0 ? top[_touched].category : 'Total ingresos',
                      style: TextStyle(fontSize: 11, color: _label3),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(top.length, (i) {
            final item = top[i];
            final color = _kColors[i % _kColors.length];
            final pct = item.totalIncome / total * 100;
            final isHl = i == _touched;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _touched = _touched == i ? -1 : i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: isHl ? color.withOpacity(_isDark ? 0.15 : 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(item.category,
                        style: TextStyle(fontSize: 14, fontWeight: isHl ? FontWeight.w600 : FontWeight.w400, color: _label2),
                      ),
                    ),
                    Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _label3)),
                    const SizedBox(width: 12),
                    Text(fmtFull.format(item.totalIncome),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isHl ? color : _label),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}