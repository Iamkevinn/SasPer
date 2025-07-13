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
    
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.chart, size: 20), const SizedBox(width: 8), Text('Ingresos vs. Gastos', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 10),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Theme.of(context).colorScheme.secondaryContainer,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final rodName = rodIndex == 0 ? 'Ingreso' : 'Gasto';
                    return BarTooltipItem(
                      '$rodName\n',
                      TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 14),
                      children: <TextSpan>[
                        TextSpan(
                          text: currencyFormatter.format(rod.toY),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= data.length) return const SizedBox.shrink();
                      final title = DateFormat.MMM('es_CO').format(data[value.toInt()].monthStart);
                      return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(title, style: Theme.of(context).textTheme.bodySmall));
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('0');
                      return Text('${(value / 1000).toStringAsFixed(0)}k');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: List.generate(data.length, (index) {
                final item = data[index];
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(toY: item.totalIncome, color: Colors.green.shade400, width: 14, borderRadius: const BorderRadius.all(Radius.circular(4))),
                    BarChartRodData(toY: item.totalExpense, color: Colors.red.shade400, width: 14, borderRadius: const BorderRadius.all(Radius.circular(4))),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}