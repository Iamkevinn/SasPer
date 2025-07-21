// lib/widgets/analysis_charts/income_expense_bar_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class IncomeExpenseBarChart extends StatelessWidget {
  final List<MonthlyIncomeExpenseSummaryData> data;

  const IncomeExpenseBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyStateCard(
        title: 'Ingresos vs. Gastos',
        message: 'Aún no hay suficientes datos para comparar tus ingresos y gastos mensuales.',
        icon: Iconsax.chart,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildChartContainer(context),
        const SizedBox(height: 12),
        _buildLegend(context),
      ],
    );
  }
  
  // --- WIDGETS HELPER PARA CONSTRUIR LA UI ---

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.chart, size: 20),
        const SizedBox(width: 8),
        Text(
          'Ingresos vs. Gastos',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildChartContainer(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.only(top: 20, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        // 1. La configuración del gráfico se delega a este método.
        _buildBarChartData(context),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    // Usamos los mismos colores que en el gráfico para la leyenda
    final incomeColor = Colors.green.shade400;
    final expenseColor = Colors.red.shade400;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: incomeColor, text: 'Ingresos'),
        const SizedBox(width: 24),
        _LegendItem(color: expenseColor, text: 'Gastos'),
      ],
    );
  }

  // --- LÓGICA DE CONFIGURACIÓN DEL GRÁFICO (EXTRAÍDA) ---

  BarChartData _buildBarChartData(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final incomeColor = Colors.green.shade400;
    final expenseColor = Colors.red.shade400;

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      barTouchData: _buildBarTouchData(context),
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, textTheme),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, textTheme),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), strokeWidth: 1),
      ),
      barGroups: List.generate(data.length, (index) {
        final item = data[index];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(toY: item.totalIncome, color: incomeColor, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: item.totalExpense, color: expenseColor, width: 14, borderRadius: BorderRadius.circular(4)),
          ],
        );
      }),
    );
  }

  BarTouchData _buildBarTouchData(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => colorScheme.secondaryContainer,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final rodName = rodIndex == 0 ? 'Ingreso' : 'Gasto';
          return BarTooltipItem(
            '$rodName\n',
            TextStyle(color: colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 14),
            children: <TextSpan>[
              TextSpan(
                text: currencyFormatter.format(rod.toY),
                style: TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          );
        },
      ),
    );
  }

  // 2. LÓGICA DE TÍTULOS EXTRAÍDA
  Widget _bottomTitleWidgets(double value, TitleMeta meta, TextTheme textTheme) {
    final index = value.toInt();
    if (index >= data.length) return const SizedBox.shrink();
    
    final title = DateFormat.MMM('es_CO').format(data[index].monthStart);
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(title, style: textTheme.bodySmall),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, TextTheme textTheme) {
    if (value == 0) return const Text('0', style: TextStyle(fontSize: 10));
    if (value == meta.max) return const SizedBox.shrink();
    
    return Text('${(value / 1000).toStringAsFixed(0)}k', style: textTheme.bodySmall);
  }
}

// Widget reutilizable para la leyenda
class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}