import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class ExpensePieChart extends StatelessWidget {
  final List<ExpenseByCategory> data;

  const ExpensePieChart({super.key, required this.data});
  
  // Lista de colores para los gráficos
  static const List<Color> _chartColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyStateCard(
        title: 'Gastos por Categoría',
        message: 'Aún no has registrado gastos este mes.',
        icon: Iconsax.chart_21,
      );
    }

    final double totalExpenses = data.fold(0, (sum, item) => sum + item.totalSpent);
    if (totalExpenses == 0) {
       return const EmptyStateCard(
        title: 'Gastos por Categoría',
        message: 'Aún no has registrado gastos este mes.',
        icon: Iconsax.chart_21,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.chart_21, size: 20), const SizedBox(width: 8), Text('Gastos del Mes por Categoría', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                width: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 50,
                    sections: List.generate(data.length, (index) {
                      final item = data[index];
                      final percentage = (item.totalSpent / totalExpenses) * 100;
                      return PieChartSectionData(
                        color: _chartColors[index % _chartColors.length],
                        value: item.totalSpent,
                        title: percentage > 7 ? '${percentage.toStringAsFixed(0)}%' : '',
                        radius: 50,
                        titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black26, blurRadius: 2)]),
                      );
                    }),
                  ),
                ),
              ),
              const Divider(height: 32),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: List.generate(data.length, (index) {
                  final item = data[index];
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 12, height: 12, color: _chartColors[index % _chartColors.length]),
                      const SizedBox(width: 8),
                      Text(item.category)
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}