// lib/models/contact_debt_summary_model.dart

import 'package:sasper/models/debt_model.dart';

class ContactDebtSummary {
  final String contactName;
  final double netBalance; // Positivo = te deben; Negativo = les debes
  final List<Debt> debts;  // Lista de deudas individuales (tú debes)
  final List<Debt> loans;  // Lista de préstamos individuales (te deben)

  ContactDebtSummary({
    required this.contactName,
    required this.netBalance,
    required this.debts,
    required this.loans,
  });
}