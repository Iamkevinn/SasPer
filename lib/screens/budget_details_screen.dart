// lib/screens/budget_details_screen.dart

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/main.dart'; // Para navigatorKey
import 'package:sasper/models/budget_models.dart'; // ¡Importa el nuevo modelo `Budget`!
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';

// Pantallas y Widgets
import 'edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';


class BudgetDetailsScreen extends StatefulWidget {
  final int budgetId;

  const BudgetDetailsScreen({
    super.key,
    required this.budgetId,
  });

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  
  // Declaramos los streams que la UI usará. Serán inicializados en el build.
  late final Stream<Budget?> _budgetStream;
  late final Stream<List<Transaction>> _transactionsStream;

  @override
  void initState() {
    super.initState();
    
    // 1. Obtenemos el stream de TODOS los presupuestos
    _budgetStream = _budgetRepository.getBudgetsStream().map(
      (budgets) {
        try {
          // Buscamos nuestro presupuesto específico en la lista
          return budgets.firstWhere((b) => b.id == widget.budgetId);
        } catch (e) {
          // Si no se encuentra (p. ej., fue eliminado), devolvemos null
          return null;
        }
      },
    );

    // 2. Usamos el NUEVO método reactivo del repositorio de transacciones
    _transactionsStream = _transactionRepository.getTransactionsStreamForBudget(widget.budgetId);
  }
  

  void _navigateToEditTransaction(Transaction transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
  }

  Future<bool> _handleDeleteTransaction(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          backgroundColor: Theme.of(dialogContext).colorScheme.surface.withOpacity(0.85),
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionRepository.deleteTransaction(transaction.id);
        EventService.instance.fire(AppEvent.transactionDeleted);
        if (mounted) {
          NotificationHelper.show(message: 'Transacción eliminada correctamente.', type: NotificationType.success);
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(message: 'Error al eliminar la transacción.', type: NotificationType.error);
        }
        return false;
      }
    }
    return false;
  }

   @override
  Widget build(BuildContext context) {
    return StreamBuilder<Budget?>(
      stream: _budgetStream,
      builder: (context, budgetSnapshot) {
        if (budgetSnapshot.connectionState == ConnectionState.waiting && !budgetSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final budget = budgetSnapshot.data;
        if (budget == null) {
          // Si el presupuesto es nulo (fue eliminado), cerramos la pantalla.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(body: Center(child: Text("Este presupuesto ya no existe.")));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(budget.category, style: GoogleFonts.poppins()),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20.0),
              child: Text(
                budget.periodText,
                style: GoogleFonts.poppins(color: Theme.of(context).textTheme.bodySmall?.color),
              ),
            ),
          ),
          body: Column(
            children: [
              _buildBudgetSummaryCard(budget),
              const Divider(height: 1, thickness: 0.5),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Movimientos Relacionados',
                    style: GoogleFonts.poppins(textStyle: Theme.of(context).textTheme.titleMedium, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
              // El `Expanded` ahora contiene el StreamBuilder de las transacciones
              Expanded(
                child: _buildTransactionsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- ¡CORRECCIÓN! El método ahora recibe un `Budget` ---
  Widget _buildBudgetSummaryCard(Budget budget) {
    final formatCurrency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- NUEVO: Mostramos los días restantes ---
          if (budget.isActive && budget.daysLeft >= 0)
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                avatar: Icon(Iconsax.clock, size: 16, color: Theme.of(context).colorScheme.secondary),
                label: Text(
                  'Quedan ${budget.daysLeft} ${budget.daysLeft == 1 ? "día" : "días"}',
                  style: GoogleFonts.poppins(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.bold,
                  )
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Gastado:', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                formatCurrency.format(budget.spentAmount),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: budget.status.getColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
           Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Restante:', style: Theme.of(context).textTheme.bodyLarge),
              Text(
                formatCurrency.format(budget.remainingAmount), // Usamos el getter
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
                formatCurrency.format(budget.amount),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: budget.progress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(6),
            backgroundColor: budget.status.getColor(context).withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(budget.status.getColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    // ¡Aquí está la magia! Usamos un StreamBuilder que se actualiza solo.
    return StreamBuilder<List<Transaction>>(
      stream: _transactionsStream, // Usamos el stream que definimos en initState
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
              message: 'Aún no hay transacciones asociadas a este presupuesto.',
              icon: Iconsax.receipt_search,
            ),
          );
        }

        final transactions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
          itemCount: transactions.length,
          itemBuilder: (context, index) {
            final transaction = transactions[index];
            return TransactionTile(
              transaction: transaction,
              onTap: () => _navigateToEditTransaction(transaction),
              onDeleted: () => _handleDeleteTransaction(transaction),
            );
          },
        );
      },
    );
  }
}