// lib/widgets/analysis_charts/monthly_cashflow_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        _buildChartContainer(context),
      ],
    );
  }

  // --- WIDGETS HELPER PARA CONSTRUIR LA UI ---

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.money_recive, size: 20),
            const SizedBox(width: 8),
            Text('Flujo de Caja Mensual', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'La diferencia entre tus ingresos y gastos de cada mes.',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildChartContainer(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(top: 24, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        _buildBarChartData(context),
      ),
    );
  }

  // --- LÓGICA DE CONFIGURACIÓN DEL GRÁFICO (EXTRAÍDA) ---

  BarChartData _buildBarChartData(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    // 1. MEJORA VISUAL OPCIONAL: Usamos gradientes en lugar de colores sólidos
    final positiveGradient = LinearGradient(
      colors: [Colors.green.shade500, Colors.green.shade300],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );
    final negativeGradient = LinearGradient(
      colors: [Colors.red.shade500, Colors.red.shade300],
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
    );

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
            reservedSize: 50, // Un poco más de espacio para "1.0M"
            getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, textTheme),
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), strokeWidth: 1),
        // Añadimos una línea en el cero para ver claramente el umbral
        checkToShowHorizontalLine: (value) => value == 0,
      ),
      barGroups: List.generate(data.length, (index) {
        final item = data[index];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: item.cashFlow,
              gradient: item.cashFlow >= 0 ? positiveGradient : negativeGradient,
              width: 18,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ],
        );
      }),
      // Definimos los límites del eje Y para que el cero siempre esté visible
      minY: data.map((d) => d.cashFlow).reduce((a, b) => a < b ? a : b) * 1.2,
      maxY: data.map((d) => d.cashFlow).reduce((a, b) => a > b ? a : b) * 1.2,
    );
  }

  BarTouchData _buildBarTouchData(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return BarTouchData(
      touchTooltipData: BarTouchTooltipData(
        getTooltipColor: (group) => colorScheme.inverseSurface,
        getTooltipItem: (group, groupIndex, rod, rodIndex) {
          final item = data[groupIndex];
          final cashFlowColor = item.cashFlow >= 0 ? Colors.green.shade300 : Colors.red.shade300;
          
          return BarTooltipItem(
            '${DateFormat.yMMM('es_CO').format(item.monthStart)}\n',
            TextStyle(color: colorScheme.onInverseSurface, fontWeight: FontWeight.bold, fontSize: 14),
            children: <TextSpan>[
              TextSpan(text: 'Flujo Neto: ${currencyFormatter.format(item.cashFlow)}\n', style: TextStyle(color: cashFlowColor, fontWeight: FontWeight.bold, fontSize: 12)),
              TextSpan(text: 'Ingresos: ${currencyFormatter.format(item.income)}\n', style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 11)),
              TextSpan(text: 'Gastos: ${currencyFormatter.format(item.expense)}', style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 11)),
            ],
          );
        },
      ),
    );
  }

  // --- LÓGICA DE TÍTULOS (EXTRAÍDA) ---
  
  Widget _bottomTitleWidgets(double value, TitleMeta meta, TextTheme textTheme) {
    final index = value.toInt();
    if (index >= data.length) return const SizedBox.shrink();
    
    final title = DateFormat.MMM('es_CO').format(data[index].monthStart);
    return SideTitleWidget(
      space: 8.0,
      meta: meta,
      child: Text(title, style: textTheme.bodySmall),
    );
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta, TextTheme textTheme) {
    // Tu lógica aquí era perfecta.
    if (value == 0) return const Text('0', style: TextStyle(fontSize: 10));
    if (value == meta.max || value == meta.min) return const SizedBox.shrink(); // No mostrar los extremos

    String text;
    if (value.abs() >= 1000000) {
      text = '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}k';
    } else {
      return const SizedBox.shrink(); // No mostrar títulos para valores pequeños
    }
    
    return Text(text, style: textTheme.bodySmall);
  }
}

// Widget de leyenda, por consistencia, aunque aquí no sea estrictamente necesario
class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}