// lib/widgets/analysis_charts/net_worth_trend_chart.dart

import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class NetWorthTrendChart extends StatelessWidget {
  final List<NetWorthDataPoint> data;

  const NetWorthTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty || data.every((d) => d.totalBalance == 0)) {
      return const EmptyStateCard(
        title: 'Evolución de tu Patrimonio',
        message: 'Registra tus transacciones para ver cómo crece tu patrimonio a lo largo del tiempo.',
        icon: Iconsax.trend_up,
      );
    }

    final spots = List.generate(data.length, (index) {
      return FlSpot(index.toDouble(), data[index].totalBalance);
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildChartContainer(context, spots),
      ],
    );
  }

  // --- WIDGETS HELPER PARA CONSTRUIR LA UI ---

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.trend_up, size: 20),
        const SizedBox(width: 8),
        Text(
          'Evolución de tu Patrimonio',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildChartContainer(BuildContext context, List<FlSpot> spots) {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 20, right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        _buildLineChartData(context, spots),
      ),
    );
  }

  // --- LÓGICA DE CONFIGURACIÓN DEL GRÁFICO (EXTRAÍDA) ---

  LineChartData _buildLineChartData(BuildContext context, List<FlSpot> spots) {
    final (minY, maxY) = _getMinMaxY(spots);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: colorScheme.onSurface.withOpacity(0.1),
          strokeWidth: 1,
        ),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, textTheme),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 50,
            getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, textTheme, minY, maxY),
          ),
        ),
      ),
      lineTouchData: _buildLineTouchData(context),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.tertiary]),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.3),
                colorScheme.primary.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  LineTouchData _buildLineTouchData(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (spot) => Theme.of(context).colorScheme.primary,
        getTooltipItems: (spots) => spots.map((spot) {
          final month = DateFormat.yMMM('es_CO').format(data[spot.spotIndex].monthEnd);
          return LineTooltipItem(
            '${currencyFormatter.format(spot.y)}\n',
            TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
            children: [
              TextSpan(
                text: month,
                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
              ),
            ]
          );
        }).toList(),
      ),
    );
  }

  // --- LÓGICA DE TÍTULOS Y CÁLCULOS (EXTRAÍDA) ---

  Widget _bottomTitleWidgets(double value, TitleMeta meta, TextTheme textTheme) {
    final index = value.toInt();
    if (index >= data.length) return const SizedBox.shrink();
    
    final title = DateFormat.MMM('es_CO').format(data[index].monthEnd);
    return SideTitleWidget(
      space: 8.0,
      meta: meta,
      child: Text(title, style: textTheme.bodySmall),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, TextTheme textTheme, double minY, double maxY) {
    if (value == minY || value == maxY) return const SizedBox.shrink();
    
    return Text('${(value / 1000).toStringAsFixed(0)}k', style: textTheme.bodySmall);
  }

  (double, double) _getMinMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return (0, 100);
    if (spots.length == 1) {
      final y = spots.first.y;
      return (y - 500, y + 500);
    }
    double minY = spots.fold(spots.first.y, (prev, e) => min(prev, e.y));
    double maxY = spots.fold(spots.first.y, (prev, e) => max(prev, e.y));
    if (minY == maxY) return (minY - 500, maxY + 500);
    final padding = (maxY - minY) * 0.20; // 20% de padding
    return (minY - padding, maxY + padding);
  }
}