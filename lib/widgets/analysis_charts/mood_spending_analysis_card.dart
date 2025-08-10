// lib/widgets/analysis_charts/mood_spending_analysis_card.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/models/mood_analysis_model.dart';

class MoodSpendingAnalysisCard extends StatefulWidget {
  final List<MoodAnalysis> analysisData;

  const MoodSpendingAnalysisCard({super.key, required this.analysisData});

  @override
  State<MoodSpendingAnalysisCard> createState() => _MoodSpendingAnalysisCardState();
}

class _MoodSpendingAnalysisCardState extends State<MoodSpendingAnalysisCard> {
  late TransactionMood _selectedMood;
  late List<TransactionMood> _availableMoods;

  @override
  void initState() {
    super.initState();
    _availableMoods = widget.analysisData.map((e) => e.mood).toSet().toList();
    _availableMoods.sort((a, b) => a.index.compareTo(b.index));
    _selectedMood = _availableMoods.isNotEmpty ? _availableMoods.first : TransactionMood.necesario;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredData = widget.analysisData.where((d) => d.mood == _selectedMood).toList();
    filteredData.sort((a, b) => a.totalSpent.compareTo(b.totalSpent));

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
            // ... (Título y selector de mood - SIN CAMBIOS)
            Text('Gastos por Estado de Ánimo', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Descubre en qué categorías gastas más según cómo te sientes.', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            if (_availableMoods.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 8.0,
                  children: _availableMoods.map((mood) {
                    return ChoiceChip(
                      label: Text(mood.displayName),
                      avatar: Icon(mood.icon, size: 16),
                      selected: _selectedMood == mood,
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedMood = mood);
                      },
                    );
                  }).toList(),
                ),
              ),
            const SizedBox(height: 24),

            // --- Gráfico de Barras (CÓDIGO CON LA CORRECCIÓN FINAL) ---
            if (filteredData.isNotEmpty)
              SizedBox(
                height: 250,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        // CORRECCIÓN FINAL: Se usa la función de callback `getTooltipColor`.
                        getTooltipColor: (BarChartGroupData group) {
                          // Simplemente devolvemos el color que queremos.
                          // Puedes añadir lógica aquí si quisieras colores diferentes por barra.
                          return Colors.black87;
                        },
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final item = filteredData[groupIndex];
                          final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
                          return BarTooltipItem(
                            '${item.category}\n',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: currencyFormat.format(item.totalSpent.abs()),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // ... (El resto del código del gráfico es correcto y no necesita cambios)
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            if (value == 0 || value == meta.max) return const SizedBox.shrink();
                            return Text('${(value / 1000).abs().toInt()}k', style: const TextStyle(fontSize: 10));
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= filteredData.length) return const SizedBox.shrink();
                            return SideTitleWidget(
                              meta: meta,
                              space: 4,
                              child: Text(
                                filteredData[index].category,
                                style: const TextStyle(fontSize: 10),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
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
                    barGroups: List.generate(filteredData.length, (index) {
                      final item = filteredData[index];
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: item.totalSpent.abs(),
                            color: colorScheme.primary,
                            width: 16,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              )
            else
              SizedBox(
                height: 150,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.chart_1, size: 40, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        'Sin gastos de tipo "${_selectedMood.displayName}"',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}