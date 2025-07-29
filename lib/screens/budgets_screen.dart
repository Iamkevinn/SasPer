// lib/screens/budgets_screen.dart (VERSIÓN FINAL COMPLETA USANDO SINGLETON)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/screens/edit_budget_screen.dart'; 
import 'package:sasper/screens/add_budget_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/main.dart';

class BudgetsScreen extends StatefulWidget {
  // El repositorio ya no se pasa como parámetro en el constructor.
  const BudgetsScreen({super.key});
  
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final BudgetRepository _repository = BudgetRepository.instance;
  late final Stream<List<BudgetProgress>> _budgetsStream;

  @override
  void initState() {
    super.initState();
    // Obtenemos el stream del repositorio singleton.
    _budgetsStream = _repository.getBudgetsStream();
  }
  
  void _navigateToAddBudget() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
    );
    // Si se creó un presupuesto, le damos el "empujón" para refrescar.
    if (result == true && mounted) {
      _repository.refreshData();
    }
  }

  void _navigateToEditBudget(BudgetProgress budget) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditBudgetScreen(budget: budget),
      ),
    );
    // Si se editó el presupuesto, refrescamos.
    if (result == true && mounted) {
      _repository.refreshData();
    }
  }

  Future<void> _handleDeleteBudget(BudgetProgress budget) async {
    final confirmed = await showDialog<bool>(
      // 1. Usamos el context del Navigator global.
      context: navigatorKey.currentContext!,
      
      // 2. Usamos 'dialogContext' para el builder.
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar el presupuesto para "${budget.category}"?'),
          actions: [
            // 3. Usamos 'dialogContext' para cerrar el diálogo.
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              // 4. Usamos 'dialogContext' para obtener el tema.
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer),
              // 5. Y para cerrar el diálogo.
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteBudgetSafely(budget.budgetId);  // Corregido: 'id' en lugar de 'budgetId'
        // El listener reactivo debería actuar, pero un "nudge" asegura inmediatez.
        _repository.refreshData();

        // Disparamos el evento global para el Dashboard.
        EventService.instance.fire(AppEvent.budgetsChanged);

        NotificationHelper.show(
          message: 'Presupuesto eliminado.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message: e.toString().replaceFirst("Exception: ", ""),
          type: NotificationType.error,
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Usamos toBeginningOfSentenceCase para que el mes empiece con mayúscula.
    final monthName = toBeginningOfSentenceCase(DateFormat.MMMM('es_CO').format(DateTime.now()));

    return Scaffold(
      appBar: AppBar(
        title: Text('Presupuestos de $monthName', style: GoogleFonts.poppins()),
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
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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
          return ListView.separated(
            padding: const EdgeInsets.all(16.0),
            itemCount: budgets.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final budget = budgets[index];
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
}