// lib/widgets/analysis_charts/category_comparison_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import '../../models/analysis_models.dart';
import '../shared/empty_state_card.dart';

class CategoryComparisonChart extends StatelessWidget {
  final List<CategorySpendingComparisonData> data;

  const CategoryComparisonChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Filtramos los datos que no aportan información visual.
    final filteredData = data.where((d) => d.currentMonthSpent > 0 || d.previousMonthSpent > 0).toList();

    if (filteredData.isEmpty) {
      return const EmptyStateCard(
        title: 'Comparativa de Gastos',
        message: 'No hay gastos suficientes este mes o el anterior para poder comparar.',
        icon: Iconsax.chart_fail,
      );
    }

    // El widget principal ahora es más legible.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 24),
        _buildChartContainer(context, filteredData),
        const SizedBox(height: 16),
        _buildLegend(context),
      ],
    );
  }

  // --- WIDGETS HELPER PARA CONSTRUIR LA UI ---

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.chart_fail, size: 20),
            const SizedBox(width: 8),
            Text(
              'Gastos: Mes Actual vs. Anterior',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Compara tus gastos por categoría con el mes pasado para identificar tendencias.',
          style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
  
  Widget _buildChartContainer(BuildContext context, List<CategorySpendingComparisonData> filteredData) {
    return Container(
      height: 300,
      padding: const EdgeInsets.only(top: 16), // Padding ajustado
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(50),
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        // 1. TODA la configuración del gráfico ahora está en este método.
        _buildBarChartData(context, filteredData),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _LegendItem(color: colorScheme.primary, text: 'Este Mes'),
        const SizedBox(width: 24),
        _LegendItem(color: colorScheme.secondary, text: 'Mes Pasado'),
      ],
    );
  }
  
  // --- LÓGICA DE CONFIGURACIÓN DEL GRÁFICO (EXTRAÍDA) ---

  BarChartData _buildBarChartData(BuildContext context, List<CategorySpendingComparisonData> filteredData) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BarChartData(
      // Propiedades del gráfico
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final item = filteredData[group.x.toInt()];
            final amount = rod.toY;
            final month = rodIndex == 0 ? "Este Mes" : "Mes Pasado";
            return BarTooltipItem(
              '${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(amount)}\n',
              TextStyle(color: colorScheme.onInverseSurface, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: month, style: TextStyle(color: colorScheme.onInverseSurface, fontSize: 12)),
              ],
            );
          },
        ),
      ),
      // Generación de las barras
      barGroups: List.generate(filteredData.length, (index) {
        final item = filteredData[index];
        return BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(toY: item.currentMonthSpent, color: colorScheme.primary, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: item.previousMonthSpent, color: colorScheme.secondary, width: 14, borderRadius: BorderRadius.circular(4)),
          ],
        );
      }),
      // Configuración de los ejes
      titlesData: FlTitlesData(
        show: true,
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 45,
            getTitlesWidget: (value, meta) => _leftTitleWidgets(value, meta, textTheme),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) => _bottomTitleWidgets(value, meta, filteredData, textTheme),
          ),
        ),
      ),
      // Estilo de bordes y rejilla
      borderData: FlBorderData(show: false),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(color: colorScheme.onSurface.withOpacity(0.1), strokeWidth: 1),
      ),
    );
  }
  
  // 2. LÓGICA DE TÍTULOS EXTRAÍDA para mayor claridad
  Widget _leftTitleWidgets(double value, TitleMeta meta, TextTheme textTheme) {
    if (value == meta.max || value == 0) return const SizedBox.shrink(); // No mostrar el título más alto ni el cero
    return Text(
      '${(value / 1000).toStringAsFixed(0)}k',
      style: textTheme.bodySmall,
    );
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta, List<CategorySpendingComparisonData> data, TextTheme textTheme) {
    final index = value.toInt();
    if (index >= data.length) return const SizedBox.shrink();
    
    final category = data[index].category;
    // Lógica de abreviación mejorada
    final title = category.length > 4 ? '${category.substring(0, 3)}.' : category;
    
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8.0,
      child: Text(title, style: textTheme.bodySmall),
    );
  }
}

// 3. WIDGET REUTILIZABLE para los items de la leyenda
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