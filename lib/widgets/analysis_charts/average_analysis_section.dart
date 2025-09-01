// lib/widgets/analysis_charts/average_analysis_section.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/analysis_models.dart';

class AverageAnalysisSection extends StatelessWidget {
  final MonthlyAverageResult monthlyData;
  final List<CategoryAverageResult> categoryData;

  const AverageAnalysisSection({
    super.key,
    required this.monthlyData,
    required this.categoryData,
  });

  Color _hexToColor(String? code) {
    if (code == null) return Colors.grey;
    return Color(int.parse(code.substring(1, 7), radix: 16) + 0xFF000000);
  }

  @override
  Widget build(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // Usamos un Card como contenedor principal para darle un estilo consistente
    // con tus otros widgets de análisis.
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card para el promedio mensual total
            Center(
              child: Column(
                children: [
                  Text(
                    'Tu Gasto Mensual Promedio',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFmt.format(monthlyData.averageSpending),
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (monthlyData.monthCount > 0)
                    Text(
                      'Basado en ${monthlyData.monthCount} meses de datos',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Sección para los promedios por categoría
            Text(
              'Promedio por Categoría',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            // Usamos un Column en lugar de un ListView para que no haya problemas de scroll anidado
            Column(
              children: List.generate(categoryData.length, (index) {
                final item = categoryData[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _hexToColor(item.color).withOpacity(0.2),
                        radius: 18,
                        child: CircleAvatar(
                          backgroundColor: _hexToColor(item.color),
                          radius: 8,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(item.categoryName, style: const TextStyle(fontWeight: FontWeight.w500)),
                      ),
                      Text(
                        currencyFmt.format(item.averageAmount),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}