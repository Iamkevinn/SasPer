// lib/widgets/analysis_charts/expense_pie_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class ExpensePieChart extends StatefulWidget { // 1. Convertido a StatefulWidget para manejar el estado del toque
  final List<ExpenseByCategory> data;

  const ExpensePieChart({super.key, required this.data});
  
  // La lista de colores puede ser parte de la clase
  static const List<Color> _chartColors = [
    Colors.blue, Colors.red, Colors.green, Colors.orange, 
    Colors.purple, Colors.teal, Colors.pink, Colors.indigo,
  ];

  @override
  State<ExpensePieChart> createState() => _ExpensePieChartState();
}

class _ExpensePieChartState extends State<ExpensePieChart> {
  int? _touchedIndex; // Para saber qué sección está siendo tocada

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return _buildEmptyState();
    }
    // El cálculo del total se mueve aquí para que sea accesible en todo el build
    final double totalExpenses = widget.data.fold(0, (sum, item) => sum + item.totalSpent);
    if (totalExpenses == 0) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withAlpha(50),
            borderRadius: BorderRadius.circular(20)
          ),
          child: Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  _buildPieChartData(totalExpenses),
                ),
              ),
              const Divider(height: 32, thickness: 0.5),
              _buildLegend(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const EmptyStateCard(
      title: 'Gastos por Categoría',
      message: 'Aún no has registrado gastos este mes.',
      icon: Iconsax.chart_21,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(children: [
      const Icon(Iconsax.chart_21, size: 20),
      const SizedBox(width: 8),
      Text(
        'Gastos del Mes por Categoría',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    ]);
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 16.0,
      runSpacing: 10.0,
      alignment: WrapAlignment.center,
      children: widget.data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return _LegendItem(
          color: ExpensePieChart._chartColors[index % ExpensePieChart._chartColors.length],
          text: item.category,
        );
      }).toList(),
    );
  }

  // --- LÓGICA DE CONFIGURACIÓN DEL GRÁFICO (EXTRAÍDA) ---

  PieChartData _buildPieChartData(double totalExpenses) {
    return PieChartData(
      // 2. Lógica de interactividad
      pieTouchData: PieTouchData(
        touchCallback: (FlTouchEvent event, pieTouchResponse) {
          setState(() {
            if (!event.isInterestedForInteractions ||
                pieTouchResponse == null ||
                pieTouchResponse.touchedSection == null) {
              _touchedIndex = -1;
              return;
            }
            _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
          });
        },
      ),
      sectionsSpace: 3,
      centerSpaceRadius: 60,
      sections: List.generate(widget.data.length, (index) {
        final item = widget.data[index];
        final isTouched = index == _touchedIndex;
        final percentage = (item.totalSpent / totalExpenses) * 100;
        
        final double radius = isTouched ? 60.0 : 50.0;
        final double fontSize = isTouched ? 16.0 : 14.0;
        final Color color = ExpensePieChart._chartColors[index % ExpensePieChart._chartColors.length];

        return PieChartSectionData(
          color: color,
          value: item.totalSpent,
          title: percentage > 7 ? '${percentage.toStringAsFixed(0)}%' : '',
          radius: radius,
          titleStyle: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
          ),
          // 3. Tooltip personalizado
          badgeWidget: isTouched ? _buildTooltipBadge(item.category, item.totalSpent, color) : null,
          badgePositionPercentageOffset: .98,
        );
      }),
    );
  }

  // Widget para el tooltip que aparece al tocar
  Widget _buildTooltipBadge(String category, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Text(
        '${category}\n${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(amount)}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Widget reutilizable para los items de la leyenda
class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}