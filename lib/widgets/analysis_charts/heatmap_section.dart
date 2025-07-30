// lib/widgets/analysis_charts/heatmap_section.dart

import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class HeatmapSection extends StatelessWidget {
  // Guardamos los datos completos (con ceros) para el SnackBar.
  final Map<DateTime, int> originalDatasets;
  // Pasamos al widget un mapa SIN los ceros para el coloreado correcto.
  final Map<DateTime, int> datasetsForCalendar;

  final bool isEdgeCase;

  HeatmapSection({
    super.key,
    required Map<DateTime, int> data,
    required DateTime startDate,
    required DateTime endDate,
  }) : originalDatasets = _createCompleteDataset(data, startDate, endDate),
       // ¡LA SOLUCIÓN! Filtramos los ceros de los datos que verá el calendario.
       datasetsForCalendar = _filterZeroValues(
           _createCompleteDataset(data, startDate, endDate)
       ),
       isEdgeCase = _isEdgeCase(data);

  // Detecta el caso borde que causa la división por cero.
  static bool _isEdgeCase(Map<DateTime, int> data) {
    final nonZeroValues = data.values.where((v) => v != 0);
    if (nonZeroValues.isEmpty) {
      return true;
    }
    return nonZeroValues.toSet().length <= 1;
  }

  // Crea un conjunto de datos con todos los días, rellenando con 0 los vacíos.
  static Map<DateTime, int> _createCompleteDataset(Map<DateTime, int> originalData, DateTime start, DateTime end) {
    final Map<DateTime, int> normalized = { for (var e in originalData.entries) DateTime(e.key.year, e.key.month, e.key.day): e.value };
    final Map<DateTime, int> complete = {};
    for (int i = 0; i <= end.difference(start).inDays; i++) {
      final date = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      complete[date] = normalized[date] ?? 0;
    }
    return complete;
  }
  
  // --- MÉTODO CLAVE AÑADIDO ---
  // Este método elimina las entradas cuyo valor es 0.
  static Map<DateTime, int> _filterZeroValues(Map<DateTime, int> data) {
    final filteredData = <DateTime, int>{};
    data.forEach((date, value) {
      if (value != 0) {
        filteredData[date] = value;
      }
    });
    return filteredData;
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Para la configuración de colores, sí usamos los datos filtrados.
    final Map<DateTime, int> displayData = isEdgeCase 
        ? datasetsForCalendar.map((key, value) => MapEntry(key, value > 0 ? 1 : -1))
        : datasetsForCalendar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface.withAlpha(50),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: HeatMapCalendar(
              // Pasamos los datos SIN ceros.
              datasets: displayData,
              
              defaultColor: theme.brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              
              colorsets: isEdgeCase
                  ? { // Configuración SEGURA
                      1: Colors.green.shade400,
                      -1: Colors.red.shade400,
                    }
                  : { // Configuración BONITA
                      1: Colors.green[100]!, 2: Colors.green[300]!, 3: Colors.green[500]!, 4: Colors.green[700]!, 5: Colors.green[900]!,
                      -1: Colors.red[100]!, -2: Colors.red[300]!, -3: Colors.red[500]!, -4: Colors.red[700]!, -5: Colors.red[900]!,
                    },

              colorMode: isEdgeCase ? ColorMode.color : ColorMode.opacity,
              
              monthFontSize: 16,
              weekFontSize: 10,
              fontSize: 10,
              textColor: colorScheme.onSurface,
              onClick: (date) {
                // El onClick sigue usando los datos originales, que sí tienen los ceros.
                _showActivitySnackBar(context, date);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.calendar_1, size: 20),
        const SizedBox(width: 8),
        Text('Actividad Financiera Diaria', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showActivitySnackBar(BuildContext context, DateTime date) {
    // Buscamos el valor en el mapa de datos ORIGINAL.
    final value = originalDatasets[date] ?? 0;
    
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    String message;

    if (value == 0) {
      message = 'Sin movimientos registrados';
    } else if (value > 0) {
      message = 'Flujo neto positivo de ${currencyFmt.format(value)}';
    } else {
      message = 'Flujo neto negativo de ${currencyFmt.format(value.abs())}';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${DateFormat.yMMMd('es_CO').format(date)}: $message'), duration: const Duration(seconds: 3)));
  }
}