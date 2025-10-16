// lib/widgets/debts/shareable_debt_summary.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sasper/models/debt_model.dart'; // Asegúrate que la ruta sea correcta

class ShareableDebtSummary extends StatelessWidget {
  final Debt debt;
  final String appName = "Sasper Finanzas"; // Puedes cambiar esto

  const ShareableDebtSummary({super.key, required this.debt});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final dateFormat = DateFormat.yMMMd('es_CO');
    final isMyDebt = debt.type == DebtType.debt;
    final title = isMyDebt ? 'Resumen de Deuda' : 'Resumen de Préstamo';
    final mainParty = isMyDebt ? 'Acreedor:' : 'Deudor:';

    return Material(
      child: Container(
        padding: const EdgeInsets.all(20),
        width: 400, // Ancho fijo para la imagen
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey.shade100, Colors.grey.shade300],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.grey.shade400, width: 2),
          borderRadius: BorderRadius.circular(16)
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Para que el tamaño se ajuste al contenido
          children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(debt.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600)),
            const Divider(height: 24),

            _buildDetailRow(mainParty, debt.entityName ?? 'No especificado'),
            if (debt.dueDate != null)
              _buildDetailRow('Fecha Límite:', dateFormat.format(debt.dueDate!)),
            
            const SizedBox(height: 16),
            
            _buildAmountCard(
              'Monto Inicial', 
              currencyFormat.format(debt.initialAmount),
              Colors.blueGrey
            ),
            const SizedBox(height: 8),
            _buildAmountCard(
              'Monto Pagado', 
              currencyFormat.format(debt.paidAmount),
              Colors.green.shade700
            ),
            const SizedBox(height: 8),
             _buildAmountCard(
              'Saldo Pendiente', 
              currencyFormat.format(debt.currentBalance),
              Colors.red.shade700,
              isBold: true
            ),
            
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                'Generado con $appName',
                style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text('$label ', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black54)),
          Expanded(child: Text(value, style: GoogleFonts.poppins(color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildAmountCard(String label, String amount, Color color, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(amount, style: GoogleFonts.lato(color: color, fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}