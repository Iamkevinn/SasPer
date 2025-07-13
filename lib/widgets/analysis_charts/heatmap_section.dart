import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

class HeatmapSection extends StatelessWidget {
  final Map<DateTime, int> data;
  
  const HeatmapSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // Normalizamos las llaves del Map a solo fecha (sin hora):
    final normalizedData = <DateTime, int>{};
    data.forEach((dateTime, value) {
      final key = DateTime(dateTime.year, dateTime.month, dateTime.day);
      normalizedData[key] = value;
    });

    // Colores según tema
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200;
    final positiveColor = Colors.green.shade400;
    final negativeColor = Colors.red.shade400;
    final currencyFmt = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
    final minValue = normalizedData.values.fold<int>(
        0, (prev, v) => v < prev ? v : prev);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Iconsax.calendar_1, size: 20),
            const SizedBox(width: 8),
            Text(
              'Actividad Financiera Diaria',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: HeatMapCalendar(
              datasets: normalizedData,
              defaultColor: defaultColor,
              colorsets: {
                minValue: negativeColor,  // cualquier valor <= -1
                1: positiveColor,  // cualquier valor >=  1
              },
              colorMode: ColorMode.color,
              showColorTip: false,
              monthFontSize: 16,
              weekFontSize: 10,
              fontSize: 10,
              textColor: Theme.of(context).colorScheme.onSurface,
              onClick: (date) {
                final key = DateTime(date.year, date.month, date.day);
                final value = normalizedData[key] ?? 0;
                final formatted = currencyFmt.format(value.abs());
                String message;
                if (value > 0) {
                  message = 'Flujo neto de $formatted';
                } else if (value < 0) {
                  message = 'Flujo neto de -$formatted';
                } else {
                  message = 'Sin actividad registrada';
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${DateFormat.yMMMd('es_MX').format(key)}: $message'
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
