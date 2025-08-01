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
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';

// Pantallas y Widgets
import 'edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';


class BudgetDetailsScreen extends StatefulWidget {
  // El constructor ahora solo necesita el ID del presupuesto.
  final int budgetId;

  const BudgetDetailsScreen({
    super.key,
    required this.budgetId,
  });

  @override
  State<BudgetDetailsScreen> createState() => _BudgetDetailsScreenState();
}

class _BudgetDetailsScreenState extends State<BudgetDetailsScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  
  late Stream<BudgetProgress?> _budgetStream;
  late Stream<List<Transaction>> _transactionsStream;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    // Filtramos el stream principal para escuchar solo los cambios de ESTE presupuesto.
    _budgetStream = _budgetRepository.getBudgetsStream().map(
      (budgets) {
        final matchingBudgets = budgets.where((b) => b.budgetId == widget.budgetId);
        return matchingBudgets.isNotEmpty ? matchingBudgets.first : null;
      },
    );

    // Creamos el stream para las transacciones.
    _transactionsStream = _transactionRepository.getTransactionsForBudget(widget.budgetId.toString()).asStream();
    
    // Escuchamos eventos globales para saber cuándo refrescar las transacciones.
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted,
      };
      if (refreshEvents.contains(event)) {
        _refreshTransactions();
        // También refrescamos los presupuestos por si el cambio afecta su progreso
        _budgetRepository.refreshData();
      }
    });
  }
  
  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  /// Recarga los datos de las transacciones para este presupuesto.
  void _refreshTransactions() {
    if (mounted) {
      setState(() {
        _transactionsStream = _transactionRepository.getTransactionsForBudget(widget.budgetId.toString()).asStream();
      });
    }
  }

  void _navigateToEditTransaction(Transaction transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
    // La arquitectura reactiva se encarga de las actualizaciones.
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
          NotificationHelper.show(
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
        }
        return false;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BudgetProgress?>(
      stream: _budgetStream,
      builder: (context, budgetSnapshot) {
        if (budgetSnapshot.connectionState == ConnectionState.waiting && !budgetSnapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final budget = budgetSnapshot.data;
        if (budget == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(body: Center(child: Text("Este presupuesto ya no existe.")));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(budget.category, style: GoogleFonts.poppins()),
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
              Expanded(
                child: _buildTransactionsList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBudgetSummaryCard(BudgetProgress budget) {
    final formatCurrency = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
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
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: budget.status.getColor(context)),
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
            backgroundColor: budget.status.getColor(context).withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(budget.status.getColor(context)),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionsList() {
    return StreamBuilder<List<Transaction>>(
      stream: _transactionsStream,
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
              message: 'Aún no hay transacciones asociadas a este presupuesto para el mes actual.',
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