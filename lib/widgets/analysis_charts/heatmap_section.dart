// lib/widgets/analysis_charts/heatmap_section.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// --- Novedad: Widget para renderizar un solo mes ---
class _MonthlyHeatmap extends StatelessWidget {
  final int year;
  final int month;
  final Map<DateTime, int> datasets;
  final double maxPositive;
  final double maxNegative;
  final Function(DateTime) onDateTap;

  const _MonthlyHeatmap({
    required this.year,
    required this.month,
    required this.datasets,
    required this.maxPositive,
    required this.maxNegative,
    required this.onDateTap,
  });

  Color _getColorForValue(int value, BuildContext context) {
    final theme = Theme.of(context);
    if (value == 0) {
      return theme.brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200;
    }
    if (value > 0) {
      final intensity = (value / maxPositive).clamp(0.0, 1.0);
      return Color.lerp(Colors.green.shade100, Colors.green.shade800, intensity)!;
    } else {
      final intensity = (value.abs() / maxNegative).clamp(0.0, 1.0);
      return Color.lerp(Colors.red.shade100, Colors.red.shade800, intensity)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // Lunes = 1, Domingo = 7. Restamos 1 para el índice de la cuadrícula.
    final emptyCells = firstDayOfMonth.weekday - 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat.yMMMM('es_CO').format(firstDayOfMonth),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildWeekHeaders(context),
          const SizedBox(height: 4),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
            itemCount: daysInMonth + emptyCells,
            itemBuilder: (context, index) {
              if (index < emptyCells) {
                return const SizedBox.shrink(); // Celdas vacías al inicio del mes
              }
              final day = index - emptyCells + 1;
              final date = DateTime(year, month, day);
              final value = datasets[date] ?? 0;
              return _HeatmapCell(
                date: date,
                color: _getColorForValue(value, context),
                onTap: () => onDateTap(date),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeaders(BuildContext context) {
    final days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return Row(
      children: days.map((day) => Expanded(
        child: Center(
          child: Text(
            day,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      )).toList(),
    );
  }
}


// --- Novedad: El widget principal ahora es Stateful para gestionar los meses ---
class HeatmapSection extends StatefulWidget {
  final Map<DateTime, int> data;
  final DateTime startDate;
  final DateTime endDate;

  const HeatmapSection({
    super.key,
    required this.data,
    required this.startDate,
    required this.endDate,
  });

  @override
  State<HeatmapSection> createState() => _HeatmapSectionState();
}

class _HeatmapSectionState extends State<HeatmapSection> {
  late final Map<DateTime, int> _completeDatasets;
  late final List<DateTime> _monthsToDisplay;
  late final double _maxPositive;
  late final double _maxNegative;

  @override
  void initState() {
    super.initState();
    _completeDatasets = _createCompleteDataset(widget.data, widget.startDate, widget.endDate);
    _monthsToDisplay = _calculateMonthsInRange(widget.startDate, widget.endDate);
    _calculateMaxValues();
  }

  void _calculateMaxValues() {
    final nonZeroValues = _completeDatasets.values.where((v) => v != 0);
    final positiveValues = nonZeroValues.where((v) => v > 0);
    final negativeValues = nonZeroValues.where((v) => v < 0).map((v) => v.abs());
    _maxPositive = positiveValues.isEmpty ? 1.0 : positiveValues.reduce(max).toDouble();
    _maxNegative = negativeValues.isEmpty ? 1.0 : negativeValues.reduce(max).toDouble();
  }
  
  static Map<DateTime, int> _createCompleteDataset(Map<DateTime, int> originalData, DateTime start, DateTime end) {
    final Map<DateTime, int> normalizedKeys = {
      for (var e in originalData.entries) DateTime(e.key.year, e.key.month, e.key.day): e.value
    };
    final Map<DateTime, int> complete = {};
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final date = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      complete[date] = normalizedKeys[date] ?? 0;
    }
    return complete;
  }
  
  List<DateTime> _calculateMonthsInRange(DateTime start, DateTime end) {
    final List<DateTime> months = [];
    DateTime current = DateTime(start.year, start.month, 1);
    while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
      months.add(current);
      current = DateTime(current.year, current.month + 1, 1);
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
          // --- Novedad: Contenedor con altura fija para la lista scrollable ---
          child: SizedBox(
            height: 380, // Altura ajustable según tus necesidades
            child: ListView.builder(
              itemCount: _monthsToDisplay.length,
              itemBuilder: (context, index) {
                final month = _monthsToDisplay[index];
                return _MonthlyHeatmap(
                  year: month.year,
                  month: month.month,
                  datasets: _completeDatasets,
                  maxPositive: _maxPositive,
                  maxNegative: _maxNegative,
                  onDateTap: (date) => _showActivitySnackBar(context, date),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(context),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
     final textStyle = GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Poco', style: textStyle),
        const SizedBox(width: 8),
        Container(width: 15, height: 15, color: Colors.red[100]),
        Container(width: 15, height: 15, color: Colors.red[400]),
        Container(width: 15, height: 15, color: Colors.red[800]),
        const SizedBox(width: 4),
        Container(
          width: 15, height: 15, 
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200
          ),
        ),
        const SizedBox(width: 4),
        Container(width: 15, height: 15, color: Colors.green[100]),
        Container(width: 15, height: 15, color: Colors.green[400]),
        Container(width: 15, height: 15, color: Colors.green[800]),
        const SizedBox(width: 8),
        Text('Mucho', style: textStyle),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.calendar_1, size: 20, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          'Actividad Financiera Diaria',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  void _showActivitySnackBar(BuildContext context, DateTime date) {
     final value = _completeDatasets[date] ?? 0;
    
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    String message;
    IconData icon;
    Color color;

    if (value == 0) {
      message = 'Sin movimientos registrados';
      icon = Iconsax.info_circle;
      color = Colors.grey;
    } else if (value > 0) {
      message = 'Flujo neto positivo de ${currencyFmt.format(value)}';
      icon = Iconsax.arrow_up_3;
      color = Colors.green;
    } else {
      message = 'Flujo neto negativo de ${currencyFmt.format(value.abs())}';
      icon = Iconsax.arrow_down_2;
      color = Colors.red;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text('${DateFormat.yMMMd('es_CO').format(date)}: $message')),
        ],
      ),
      duration: const Duration(seconds: 3)
    ));
  }
}

// Celda individual del calendario (sin cambios)
class _HeatmapCell extends StatelessWidget {
  final DateTime date;
  final Color color;
  final VoidCallback onTap;

  const _HeatmapCell({required this.date, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Tooltip(
        message: DateFormat.yMMMd('es_CO').format(date),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              date.day.toString(),
              style: GoogleFonts.poppins(
                color: color.computeLuminance() > 0.5 ? Colors.black54 : Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}