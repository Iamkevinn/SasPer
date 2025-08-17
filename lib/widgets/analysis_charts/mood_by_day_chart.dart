// lib/widgets/analysis_charts/mood_by_day_chart.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/models/mood_by_day_analysis_model.dart';

class MoodByDayChart extends StatefulWidget {
  final List<MoodByDayAnalysis> analysisData;

  const MoodByDayChart({super.key, required this.analysisData});

  @override
  State<MoodByDayChart> createState() => _MoodByDayChartState();
}

class _MoodByDayChartState extends State<MoodByDayChart> {
  // Mapa de colores para dar consistencia a cada estado de ánimo
  late Map<TransactionMood, Color> _moodColors;

  @override
  void initState() {
    super.initState();
    // Definimos una paleta de colores para los moods.
    // Es importante que sea consistente.
    _moodColors = {
      TransactionMood.necesario: Colors.grey.shade400,
      TransactionMood.planificado: Colors.blue.shade300,
      TransactionMood.impulsivo: Colors.red.shade300,
      TransactionMood.social: Colors.purple.shade200,
      TransactionMood.emocional: Colors.orange.shade300,
    };
  }
  
  // Función auxiliar para obtener la inicial del día de la semana.
  String _getDayInitial(int day) {
    switch (day) {
      case 1: return 'L';
      case 2: return 'M';
      case 3: return 'X';
      case 4: return 'J';
      case 5: return 'V';
      case 6: return 'S';
      case 7: return 'D';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculamos el gasto máximo en un solo día para escalar el eje Y del gráfico.
    double maxY = 0;
    final Map<int, double> dailyTotals = {};
    for (var item in widget.analysisData) {
      dailyTotals[item.dayOfWeek] = (dailyTotals[item.dayOfWeek] ?? 0) + item.totalSpent.abs();
    }
    if (dailyTotals.isNotEmpty) {
      maxY = dailyTotals.values.reduce((a, b) => a > b ? a : b) * 1.2; // 20% de espacio extra
    }
    if (maxY == 0) maxY = 100; // Un valor mínimo si no hay datos

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patrones Semanales de Gasto', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Analiza qué días de la semana concentran tus gastos por emoción.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            
            _buildLegend(), // Construimos la leyenda de colores
            
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.black87,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final mood = _moodColors.keys.elementAt(rodIndex);
                        final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
                        return BarTooltipItem(
                          '${mood.displayName}\n',
                          TextStyle(color: _moodColors[mood], fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: currencyFormat.format(rod.toY.abs()),
                              style: const TextStyle(color: Colors.white),
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          if (value == 0 || value >= maxY) return const SizedBox.shrink();
                          return Text('${(value / 1000).abs().toInt()}k', style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            meta: meta,
                            space: 4,
                            child: Text(_getDayInitial(value.toInt()), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: colorScheme.outlineVariant.withOpacity(0.2),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(7, (dayIndex) { // Generamos un grupo para cada día (1 a 7)
                    final day = dayIndex + 1;
                    
                    // Buscamos todos los gastos para este día específico
                    final dayData = widget.analysisData.where((d) => d.dayOfWeek == day).toList();

                    return BarChartGroupData(
                      x: day,
                      barRods: _moodColors.keys.map((mood) {
                        // Para cada mood, buscamos si hay un gasto correspondiente en los datos del día
                        final item = dayData.where((d) => d.mood == mood).firstOrNull;
                        return BarChartRodData(
                          toY: item?.totalSpent.abs() ?? 0, // Si no hay, la barra es 0
                          color: _moodColors[mood],
                          width: 5, // Barras más delgadas para que quepan
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        );
                      }).toList(),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget auxiliar para construir la leyenda de colores del gráfico
  Widget _buildLegend() {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: _moodColors.entries.map((entry) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, color: entry.value),
            const SizedBox(width: 6),
            Text(entry.key.displayName, style: const TextStyle(fontSize: 12)),
          ],
        );
      }).toList(),
    );
  }
}