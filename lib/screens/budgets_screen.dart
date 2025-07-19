// lib/screens/budgets_screen.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// Importamos la arquitectura limpia
import '../data/budget_repository.dart';
import '../models/budget_models.dart';
import 'add_budget_screen.dart';
import '../widgets/shared/empty_state_card.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  // 1. LA PANTALLA SOLO NECESITA EL REPOSITORIO Y EL STREAM
  final _budgetRepository = BudgetRepository();
  late final Stream<List<BudgetProgress>> _budgetsStream;

  @override
  void initState() {
    super.initState();
    // Obtenemos el stream reactivo desde el repositorio
    _budgetsStream = _budgetRepository.getBudgetsProgressStream();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Presupuestos de ${DateFormat.MMMM('es_CO').format(DateTime.now())}'),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square),
            tooltip: 'Añadir Presupuesto',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
              );
              // No necesitamos recargar, el stream lo hará automáticamente
            },
          ),
        ],
      ),
      // 2. USAMOS UN ÚNICO STREAMBUILDER
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
            return const Center(
              child: EmptyStateCard(
                title: 'Sin Presupuestos',
                message: 'Aún no has creado ningún presupuesto para este mes. ¡Empieza ahora!',
                icon: Iconsax.additem,
              ),
            );
          }

          final budgets = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              // 3. Pasamos el objeto BudgetProgress directamente al tile
              return _buildBudgetTile(budget);
            },
          );
        },
      ),
    );
  }

  // 4. EL TILE AHORA RECIBE UN OBJETO BudgetProgress
  Widget _buildBudgetTile(BudgetProgress budget) {
    final theme = Theme.of(context);
    final statusColor = budget.status.getColor(context);
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface.withAlpha(100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(budget.category, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                Icon(budget.status.icon, color: statusColor),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  currencyFormat.format(budget.spentAmount),
                  style: TextStyle(fontWeight: FontWeight.w500, color: statusColor),
                ),
                Text(
                  currencyFormat.format(budget.budgetAmount),
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
            if (budget.remainingAmount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Restante: ${currencyFormat.format(budget.remainingAmount)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              )
            ]
          ],
        ),
      ),
    );
  }
}