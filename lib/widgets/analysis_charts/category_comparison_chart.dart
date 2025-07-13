import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class CategoryComparisonChart extends StatelessWidget {
  final List<CategorySpendingComparisonData> data;

  const CategoryComparisonChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final filteredData = data.where((d) => d.currentMonthSpent > 0 || d.previousMonthSpent > 0).toList();

    if (filteredData.isEmpty) {
      return const EmptyStateCard(
        title: 'Comparativa de Gastos',
        message: 'No hay gastos suficientes para comparar entre meses.',
        icon: Iconsax.chart_fail,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.chart_fail, size: 20), const SizedBox(width: 8), Text('Gastos: Mes Actual vs. Anterior', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 8),
        Text('Compara tus gastos por categoría con el mes pasado.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: BarChart(
            BarChartData(
              barGroups: List.generate(filteredData.length, (index) {
                final item = filteredData[index];
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(toY: item.currentMonthSpent, color: Theme.of(context).colorScheme.primary, width: 12),
                    BarChartRodData(toY: item.previousMonthSpent, color: Theme.of(context).colorScheme.secondary, width: 12),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) => Text('${(value / 1000).toStringAsFixed(0)}k'),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= filteredData.length) return const SizedBox.shrink();
                      final category = filteredData[value.toInt()].category;
                      final title = category.length > 3 ? category.substring(0, 3) : category;
                      return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(title, style: Theme.of(context).textTheme.bodySmall));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(children: [Container(width: 12, height: 12, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), const Text('Este Mes')]),
            const SizedBox(width: 24),
            Row(children: [Container(width: 12, height: 12, color: Theme.of(context).colorScheme.secondary), const SizedBox(width: 8), const Text('Mes Pasado')]),
          ],
        )
      ],
    );
  }
}