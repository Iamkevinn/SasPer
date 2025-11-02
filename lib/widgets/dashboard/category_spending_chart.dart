// lib/widgets/dashboard/category_spending_chart.dart
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/screens/analysis_screen.dart';

class CategorySpendingChart extends StatefulWidget {
  final List<CategorySpending> spendingData;

  const CategorySpendingChart({super.key, required this.spendingData});

  @override
  State<CategorySpendingChart> createState() => _CategorySpendingChartState();
}

class _CategorySpendingChartState extends State<CategorySpendingChart> {
  int touchedIndex = -1;

  List<CategorySpending> get processedSpendingData {
    if (widget.spendingData.length <= 5) {
      return widget.spendingData;
    }

    final sortedData = List<CategorySpending>.from(widget.spendingData)
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final top4 = sortedData.take(4).toList();
    final others = sortedData.skip(4).toList();

    if (others.isNotEmpty) {
      final othersTotal =
          others.fold<double>(0, (sum, item) => sum + item.totalAmount);
      top4.add(CategorySpending(
        categoryName: 'Otros',
        totalAmount: othersTotal,
        color: '#808080',
      ));
    }
    return top4;
  }

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

    final displayData = processedSpendingData;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Tus Gastos este Mes',
                  style: GoogleFonts.poppins(
                      textStyle: Theme.of(context).textTheme.titleLarge,
                      fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AnalysisScreen()),
                    );
                  },
                  icon: Text(
                    'Detalles',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  label: Icon(
                    Iconsax.arrow_right_3,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback:
                              (FlTouchEvent event, pieTouchResponse) {
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
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: _buildChartSections(displayData),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: displayData.asMap().entries.map((entry) {
                      return _Indicator(
                        color: _hexToColor(entry.value.color),
                        text: entry.value.categoryName,
                        isTouched: entry.key == touchedIndex,
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(List<CategorySpending> data) {
    final totalValue = data.fold<double>(0, (sum, d) => sum + d.totalAmount);
    if (totalValue == 0) return [];

    return data.asMap().entries.map((entry) {
      final isTouched = entry.key == touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 70.0 : 60.0;
      final sectionData = entry.value;
      final sectionColor = _hexToColor(sectionData.color);

      final percentage = (sectionData.totalAmount / totalValue * 100);
      final title = percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '';

      return PieChartSectionData(
        color: sectionColor,
        value: sectionData.totalAmount,
        title: title,
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: _getTextColorForBackground(sectionColor),
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

  Color _getTextColorForBackground(Color backgroundColor) {
    if (ThemeData.estimateBrightnessForColor(backgroundColor) ==
        Brightness.light) {
      return Colors.black87;
    }
    return Colors.white;
  }
}

class _Indicator extends StatelessWidget {
  final Color color;
  final String text;
  final bool isTouched;

  const _Indicator({
    required this.color,
    required this.text,
    required this.isTouched,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: <Widget>[
          Container(
            width: isTouched ? 12 : 8,
            height: isTouched ? 12 : 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          )
        ],
      ),
    );
  }
}