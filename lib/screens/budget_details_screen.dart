// lib/screens/budget_details_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'package:intl/intl.dart'; // Para formatear números

class BudgetDetailsScreen extends StatefulWidget {
  final BudgetProgress budgetProgress;
  final TransactionRepository transactionRepository;
  // Podríamos necesitar el repo de cuentas si queremos navegar a la edición de transacciones
  // final AccountRepository accountRepository; 

  const BudgetDetailsScreen({
    super.key,
    required this.budgetProgress,
    required this.transactionRepository,
    // required this.accountRepository,
  });

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    // --- CORREGIDO: Convertimos el ID a String ---
    _transactionsFuture = widget.transactionRepository
        .getTransactionsForBudget(widget.budgetProgress.budgetId.toString()); // <-- CAMBIO AQUÍ
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final budget = widget.budgetProgress;

    return Scaffold(
      appBar: AppBar(
        title: Text(budget.category, style: GoogleFonts.poppins()),
      ),
      body: Column(
        children: [
          _buildBudgetSummaryCard(budget, formatCurrency),
          const Divider(height: 1),
          Expanded(
            child: _buildTransactionsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSummaryCard(BudgetProgress budget, NumberFormat formatCurrency) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progreso del Presupuesto',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gastado:', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                formatCurrency.format(budget.spentAmount),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Límite:', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                formatCurrency.format(budget.budgetAmount),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: budget.progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(
              budget.progress > 0.8 ? Colors.red.shade400 : Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return FutureBuilder<List<Transaction>>(
      future: _transactionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar movimientos: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: EmptyStateCard(
              title: 'Sin Movimientos',
              message: 'No hay transacciones asociadas a este presupuesto.',
              icon: Icons.receipt_long,
            ),
          );
        }
        final transactions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return TransactionTile(
              transaction: transaction,
              onTap: () {
                // TODO: Navegar a la pantalla de edición de transacción si se desea
              },
              // La función onDeleted puede pasarse como null si no queremos
              // permitir el borrado desde esta pantalla, o implementarla.
              onDeleted: null, 
            );
          },
        );
      },
    );
  }
}