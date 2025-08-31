// lib/widgets/dashboard/category_spending_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/models/dashboard_data_model.dart';

class CategorySpendingChart extends StatefulWidget {
  final List<CategorySpending> spendingData;

  const CategorySpendingChart({super.key, required this.spendingData});

  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

class _CategorySpendingChartState extends State<CategorySpendingChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.spendingData.isEmpty) {
      return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: const SizedBox(
          height: 200,
          child: Center(
            child: Text(
              "Registra algunos gastos este mes\npara ver tu resumen aquí.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TÍTULO ---
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: Text(
                'Tus Gastos este Mes',
                style: GoogleFonts.poppins(
                    textStyle: Theme.of(context).textTheme.titleLarge,
                    fontWeight: FontWeight.bold),
              ),
            ),

            // --- GRÁFICO CENTRADO ---
            const SizedBox(height: 50),
            SizedBox(
              height: 200, // Aumentamos un poco la altura para que respire
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex = pieTouchResponse
                            .touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 3, // Un poco más de espacio entre secciones
                  centerSpaceRadius: 50, // Un centro un poco más grande
                  sections: _buildChartSections(),
                ),
              ),
            ),

            // --- LEYENDA MEJORADA (DEBAJO) ---
            const SizedBox(height: 50),
            const Divider(),
            const SizedBox(height: 10),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 12.0,
                runSpacing: 8.0,
                children: widget.spendingData.asMap().entries.map((entry) {
                  final isTouched = entry.key == touchedIndex;
                  final data = entry.value;

                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _hexToColor(data.color),
                      // Hacemos el avatar más grande si está tocado
                      radius: isTouched ? 8 : 6,
                    ),
                    label: Text(data.categoryName),
                    // Cambiamos el estilo del chip si está seleccionado
                    backgroundColor: isTouched
                        ? _hexToColor(data.color).withOpacity(0.3)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: const StadiumBorder(),
                    side: BorderSide(
                        color: isTouched
                            ? _hexToColor(data.color)
                            : Theme.of(context)
                                .colorScheme
                                .outlineVariant
                                .withOpacity(0.5)),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MÉTODOS AUXILIARES (iguales que antes, pero con valores ajustados) ---

  List<PieChartSectionData> _buildChartSections() {
    final totalValue =
        widget.spendingData.fold<double>(0, (sum, d) => sum + d.totalAmount);
    if (totalValue == 0) return [];

    return widget.spendingData.asMap().entries.map((entry) {
      final isTouched = entry.key == touchedIndex;
      final fontSize = isTouched ? 18.0 : 14.0;
      final radius = isTouched ? 100.0 : 90.0;
      final data = entry.value;

      return PieChartSectionData(
        color: _hexToColor(data.color),
        value: data.totalAmount,
        title: '${(data.totalAmount / totalValue * 100).toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
        ),
      );
    }).toList();
  }

  Color _hexToColor(String code) {
    try {
      return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.grey;
    }
  }
}
