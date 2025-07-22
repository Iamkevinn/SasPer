// lib/screens/budgets_screen.dart (CORREGIDO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/add_budget_screen.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
class BudgetsScreen extends StatefulWidget {
  final BudgetRepository repository;

  const BudgetsScreen({super.key, required this.repository});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  late final Stream<List<BudgetProgress>> _budgetsStream;

  @override
  void initState() {
    super.initState();
    _budgetsStream = widget.repository.getBudgetsProgressStream();
  }
  
  void _navigateToAddBudget() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AddBudgetScreen(budgetRepository: widget.repository)),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Presupuestos de ${DateFormat.MMMM('es_CO').format(DateTime.now())}', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square),
            tooltip: 'Añadir Presupuesto',
            onPressed: _navigateToAddBudget,
          ),
        ],
      ),
      body: StreamBuilder<List<BudgetProgress>>(
        stream: _budgetsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar presupuestos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: EmptyStateCard(
                title: 'Sin Presupuestos',
                message: 'Aún no has creado ningún presupuesto para este mes. ¡Empieza ahora!',
                icon: Iconsax.additem,
                actionButton: ElevatedButton.icon(
                  onPressed: _navigateToAddBudget,
                  icon: const Icon(Iconsax.add),
                  label: const Text('Crear mi primer presupuesto'),
                ),
              ),
            );
          }

          final budgets = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              return _buildBudgetTile(budget);
            },
          );
        },
      ),
    );
  }

  Widget _buildBudgetTile(BudgetProgress budget) {
    final theme = Theme.of(context);
    final statusColor = budget.status.getColor(context);
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(budget.category, style: GoogleFonts.poppins(textStyle: theme.textTheme.titleMedium, fontWeight: FontWeight.bold)),
                Icon(budget.status.icon, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(budget.spentAmount),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: statusColor),
                ),
                Text(
                  currencyFormat.format(budget.budgetAmount),
                  style: GoogleFonts.poppins(textStyle: theme.textTheme.bodyMedium, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: budget.progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
              backgroundColor: statusColor.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            if (budget.remainingAmount >= 0) ...[
              const SizedBox(height: 8),
              Text(
                'Restante: ${currencyFormat.format(budget.remainingAmount)}',
                style: GoogleFonts.poppins(textStyle: theme.textTheme.bodySmall, color: theme.colorScheme.onSurfaceVariant),
              )
            ]
          ],
        ),
      ),
    );
  }
}