// lib/screens/budgets_screen.dart (CORREGIDO)

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/edit_budget_screen.dart'; 
import 'package:sasper/screens/add_budget_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/budget_card.dart';

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

  // ---- NUEVA FUNCIÓN PARA NAVEGAR A EDITAR ----
  void _navigateToEditBudget(BudgetProgress budget) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditBudgetScreen(
          budgetRepository: widget.repository,
          budget: budget,
        ),
      ),
    );
  }

  // ---- NUEVA FUNCIÓN PARA MANEJAR EL BORRADO ----
  Future<void> _handleDeleteBudget(BudgetProgress budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar el presupuesto para "${budget.category}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.repository.deleteBudgetSafely(budget.budgetId);
        NotificationHelper.show(
          context: context,
          message: 'Presupuesto eliminado.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          context: context,
          message: e.toString(), // El repositorio ya formatea el mensaje de error
          type: NotificationType.error,
        );
      }
    }
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
          // USAMOS LISTVIEW.SEPARATED PARA MEJOR ESPACIADO
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final budget = budgets[index];
              // AHORA USAMOS EL BUDGETCARD CON LAS NUEVAS ACCIONES
              return BudgetCard(
                budget: budget,
                onTap: () => _navigateToEditBudget(budget),
                onEdit: () => _navigateToEditBudget(budget),
                onDelete: () => _handleDeleteBudget(budget),
              );
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