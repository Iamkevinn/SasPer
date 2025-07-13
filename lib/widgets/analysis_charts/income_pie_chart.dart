import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class IncomePieChart extends StatelessWidget {
  final List<IncomeByCategory> data;

  const IncomePieChart({super.key, required this.data});
  
  // Reutilizamos la misma paleta de colores
  static const List<Color> _chartColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const EmptyStateCard(
        title: 'Fuentes de Ingreso',
        message: 'Aún no has registrado ingresos este mes.',
        icon: Iconsax.money_add,
      );
    }
    
    final double totalIncome = data.fold(0, (sum, item) => sum + item.totalIncome);
    if (totalIncome == 0) {
      return const EmptyStateCard(
        title: 'Fuentes de Ingreso',
        message: 'Aún no has registrado ingresos este mes.',
        icon: Iconsax.money_add,
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [const Icon(Iconsax.money_add, size: 20), const SizedBox(width: 8), Text('Ingresos del Mes por Categoría', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))]),
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
                      final percentage = (item.totalIncome / totalIncome) * 100;
                      return PieChartSectionData(
                        color: _chartColors[index % _chartColors.length].withOpacity(0.8),
                        value: item.totalIncome,
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
                      Container(width: 12, height: 12, color: _chartColors[index % _chartColors.length].withOpacity(0.8)),
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