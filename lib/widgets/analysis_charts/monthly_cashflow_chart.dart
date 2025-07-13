import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class MonthlyCashflowChart extends StatelessWidget {
  final List<MonthlyCashflowData> data;

  const MonthlyCashflowChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyStateCard(
        title: 'Flujo de Caja Mensual',
        message: 'Aún no tienes suficientes transacciones para mostrar tu flujo de caja mensual.',
        icon: Iconsax.money_recive,
      );
    }
    
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.money_recive, size: 20),
            const SizedBox(width: 8),
            Text(
              'Flujo de Caja Mensual',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
            )
          ]
        ),
        const SizedBox(height: 8),
        Text(
          'La diferencia entre tus ingresos y gastos de cada mes.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)
        ),
        const SizedBox(height: 16),
        Container(
          height: 250,
          padding: const EdgeInsets.fromLTRB(8, 24, 16, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20)
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => Theme.of(context).colorScheme.secondaryContainer,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final item = data[groupIndex];
                    final cashFlowColor = item.cashFlow >= 0 ? Colors.green.shade300 : Colors.red.shade300;
                    
                    return BarTooltipItem(
                      '${DateFormat.MMM('es_CO').format(item.monthStart)}\n',
                      TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.bold, fontSize: 14),
                      children: <TextSpan>[
                        TextSpan(text: 'Flujo: ${currencyFormatter.format(item.cashFlow)}\n', style: TextStyle(color: cashFlowColor, fontWeight: FontWeight.bold, fontSize: 12)),
                        TextSpan(text: 'Ingresos: ${currencyFormatter.format(item.income)}\n', style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 11)),
                        TextSpan(text: 'Gastos: ${currencyFormatter.format(item.expense)}', style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontSize: 11)),
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
                    }
                  )
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 45,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const Text('0');
                      if (value.abs() >= 1000000) return Text('${(value / 1000000).toStringAsFixed(1)}M');
                      if (value.abs() >= 1000) return Text('${(value / 1000).toStringAsFixed(0)}k');
                      return const SizedBox.shrink();
                    }
                  )
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
                    BarChartRodData(
                      toY: item.cashFlow,
                      color: item.cashFlow >= 0 ? Colors.green.shade400 : Colors.red.shade400,
                      width: 16,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
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