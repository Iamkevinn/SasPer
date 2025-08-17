// lib/screens/simulation_result_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/simulation_models.dart';
import 'package:percent_indicator/percent_indicator.dart'; // Necesitarás añadir este paquete

class SimulationResultScreen extends StatelessWidget {
  final SimulationResult result;

  const SimulationResultScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Análisis de Gasto', style: GoogleFonts.poppins()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildVerdictCard(context),
          const SizedBox(height: 24),
          if (result.budgetImpact != null) ...[
            _buildBudgetImpactCard(context, result.budgetImpact!),
            const SizedBox(height: 24),
          ],
          _buildSavingsImpactCard(context),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'Esta es una simulación y no afecta tus registros.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES PARA CADA SECCIÓN ---

  Widget _buildVerdictCard(BuildContext context) {
    IconData icon;
    Color color;
    String title;

    switch (result.verdict) {
      case SimulationVerdict.recommended:
        icon = Iconsax.like_1;
        color = Colors.green.shade600;
        title = 'Recomendado';
        break;
      case SimulationVerdict.withCaution:
        icon = Iconsax.warning_2;
        color = Colors.orange.shade600;
        title = 'Con Precaución';
        break;
      case SimulationVerdict.notRecommended:
        icon = Iconsax.dislike;
        color = Colors.red.shade600;
        title = 'No Recomendado';
        break;
    }

    return Card(
      elevation: 0,
      color: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(
              result.verdictMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetImpactCard(BuildContext context, BudgetImpact impact) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impacto en Presupuesto', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildProgressCircle('Actual', impact.currentProgress, impact.currentSpent, currencyFmt, context),
                const Icon(Iconsax.arrow_right_3, color: Colors.grey),
                _buildProgressCircle('Proyectado', impact.projectedProgress, impact.projectedSpent, currencyFmt, context, isProjected: true),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Presupuesto para "${impact.categoryName}": ${currencyFmt.format(impact.budgetAmount)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCircle(String title, double progress, double amount, NumberFormat formatter, BuildContext context, {bool isProjected = false}) {
    Color progressColor;
    if (progress >= 1.0) progressColor = Colors.red.shade400;
    else if (progress >= 0.8) progressColor = Colors.orange.shade400;
    else progressColor = Colors.green.shade400;
    
    if (isProjected) {
      // Usa un estilo diferente para la proyección
    }
    
    return Column(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        CircularPercentIndicator(
          radius: 50.0,
          lineWidth: 10.0,
          percent: progress.clamp(0.0, 1.0),
          center: Text(
            '${(progress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20.0),
          ),
          circularStrokeCap: CircularStrokeCap.round,
          progressColor: progressColor,
          backgroundColor: progressColor.withOpacity(0.2),
        ),
        const SizedBox(height: 8),
        Text(formatter.format(amount), style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }

  Widget _buildSavingsImpactCard(BuildContext context) {
    final currencyFmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final impact = result.savingsImpact;
    final difference = impact.currentEOMBalance - impact.projectedEOMBalance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Impacto en Flujo de Caja', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildImpactRow(
              'Balance Proyectado (Fin de Mes)', 
              currencyFmt.format(impact.currentEOMBalance), 
              context
            ),
            const SizedBox(height: 8),
            _buildImpactRow(
              'Gasto Simulado', 
              '- ${currencyFmt.format(difference)}', 
              context, 
              isNegative: true
            ),
            const Divider(height: 24),
            _buildImpactRow(
              'Nuevo Balance Proyectado', 
              currencyFmt.format(impact.projectedEOMBalance), 
              context, 
              isBold: true
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImpactRow(String label, String value, BuildContext context, {bool isNegative = false, bool isBold = false}) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textTheme.bodyLarge),
        Text(
          value, 
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isNegative ? Colors.red.shade400 : (isBold ? Theme.of(context).colorScheme.primary : null),
          )
        ),
      ],
    );
  }
}