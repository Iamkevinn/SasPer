// lib/widgets/analysis_charts/heatmap_section.dart

// Para encontrar el mínimo de forma eficiente
import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class HeatmapSection extends StatelessWidget {
  // 1. LA NORMALIZACIÓN OCURRE EN EL CONSTRUCTOR
  final Map<DateTime, int> datasets;

  HeatmapSection({super.key, required Map<DateTime, int> data})
      // El constructor procesa los datos una sola vez
      : datasets = {
          for (var entry in data.entries)
            DateTime(entry.key.year, entry.key.month, entry.key.day): entry.value
        };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
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
              datasets: datasets,
              defaultColor: theme.brightness == Brightness.dark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              // 2. Configuración de colores más robusta
              colorsets: {
                1: Colors.green.shade400, // Nivel 1 para valores positivos
                -1: Colors.red.shade400,  // Nivel -1 para valores negativos
              },
              colorMode: ColorMode.color,
              showColorTip: false,
              monthFontSize: 16,
              weekFontSize: 10,
              fontSize: 10,
              textColor: colorScheme.onSurface,
              onClick: (date) {
                // 3. La lógica del onClick ahora está encapsulada
                _showActivitySnackBar(context, date);
              },
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS Y MÉTODOS HELPER ---

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Iconsax.calendar_1, size: 20),
        const SizedBox(width: 8),
        Text(
          'Actividad Financiera Diaria',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showActivitySnackBar(BuildContext context, DateTime date) {
    // La fecha del `onClick` ya viene normalizada (sin hora)
    final value = datasets[date] ?? 0;
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    String message;

    if (value > 0) {
      message = 'Flujo neto positivo de ${currencyFmt.format(value)}';
    } else if (value < 0) {
      // Usamos .abs() para mostrar siempre un número positivo
      message = 'Flujo neto negativo de ${currencyFmt.format(value.abs())}';
    } else {
      message = 'Sin actividad financiera registrada';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${DateFormat.yMMMd('es_CO').format(date)}: $message',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}