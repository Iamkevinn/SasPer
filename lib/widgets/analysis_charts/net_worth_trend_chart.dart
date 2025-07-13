import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class NetWorthTrendChart extends StatelessWidget {
  final List<NetWorthDataPoint> data;

  const NetWorthTrendChart({super.key, required this.data});

  (double, double) _getMinMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return (0, 100);
    if (spots.length == 1) {
      final y = spots.first.y;
      return (y - 500, y + 500);
    }
    double minY = spots.fold(spots.first.y, (prev, e) => min(prev, e.y));
    double maxY = spots.fold(spots.first.y, (prev, e) => max(prev, e.y));
    if (minY == maxY) return (minY - 500, maxY + 500);
    final padding = (maxY - minY) * 0.20;
    return (minY - padding, maxY + padding);
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((d) => d.netWorth == 0)) {
      return const EmptyStateCard(
        title: 'Evolución de tu Patrimonio',
        message: 'Registra tus transacciones para ver cómo crece tu patrimonio a lo largo del tiempo.',
        icon: Iconsax.trend_up,
      );
    }

    final spots = List.generate(data.length, (index) {
      return FlSpot(index.toDouble(), data[index].netWorth);
    });

    final (minY, maxY) = _getMinMaxY(spots);
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.trend_up, size: 20), const SizedBox(width: 8), Text('Evolución de tu Patrimonio', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.fromLTRB(8, 20, 20, 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= data.length) return const SizedBox.shrink();
                      final title = DateFormat.MMM('es_CO').format(data[value.toInt()].monthEnd);
                      return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(title, style: Theme.of(context).textTheme.bodySmall));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == minY || value == maxY) return const SizedBox.shrink();
                      return Text('${(value / 1000).toStringAsFixed(0)}k');
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => Theme.of(context).colorScheme.primary,
                  getTooltipItems: (spots) => spots.map((spot) {
                    return LineTooltipItem(
                      currencyFormatter.format(spot.y),
                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    );
                  }).toList(),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary.withOpacity(0.3), Theme.of(context).colorScheme.primary.withOpacity(0.0)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}