// lib/screens/account_details_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/main.dart'; // Para navigatorKey
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';

// Pantallas y Widgets
import 'edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class AccountDetailsScreen extends StatefulWidget {
  // El constructor ahora solo necesita el ID de la cuenta.
  final String accountId;

  const AccountDetailsScreen({
    super.key,
    required this.accountId,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final AccountRepository _accountRepository = AccountRepository.instance;
  final TransactionRepository _transactionRepository = TransactionRepository.instance;

  late Stream<Account?> _accountStream;
  late Stream<List<Transaction>> _transactionsStream;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    // Filtramos el stream principal para escuchar solo los cambios de ESTA cuenta.
    _accountStream = _accountRepository.getAccountsStream().map(
      (accounts) {
        // --- CORRECCIÓN 1: Búsqueda segura que devuelve Account? ---
        final matchingAccounts = accounts.where((acc) => acc.id == widget.accountId);
        return matchingAccounts.isNotEmpty ? matchingAccounts.first : null;
      },
    );

    // Creamos el stream para las transacciones.
    _transactionsStream = _accountRepository.getTransactionsForAccount(widget.accountId).asStream();

    // Escuchamos eventos globales para saber cuándo refrescar las transacciones.
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted,
      };
      if (refreshEvents.contains(event)) {
        _refreshTransactions();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  /// Recarga los datos de las transacciones para esta cuenta específica.
  void _refreshTransactions() {
    if (mounted) {
      setState(() {
        _transactionsStream = _accountRepository.getTransactionsForAccount(widget.accountId).asStream();
      });
    }
  }

  void _navigateToEditTransaction(Transaction transaction) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(transaction: transaction),
      ),
    );
    // Ya no es necesario un refresh manual aquí, la arquitectura reactiva se encarga.
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
    final currencyFormat = NumberFormat.currency(locale: 'ES_CO', symbol: '\$');

    return StreamBuilder<Account?>(
      stream: _accountStream,
      builder: (context, accountSnapshot) {
        if (accountSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final currentAccount = accountSnapshot.data;
        if (currentAccount == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
          return const Scaffold(body: Center(child: Text("Esta cuenta ya no existe.")));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(currentAccount.name, style: GoogleFonts.poppins()),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Center(
                      child: Column(
                        children: [
                          Text('Saldo Actual', style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 8),
                          Text(
                            currencyFormat.format(currentAccount.balance),
                            style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: currentAccount.balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Historial de Movimientos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(indent: 16, endIndent: 16, height: 24),
              Expanded(
                child: StreamBuilder<List<Transaction>>(
                  stream: _transactionsStream,
                  builder: (context, transactionSnapshot) {
                    if (transactionSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (transactionSnapshot.hasError) {
                      return Center(child: Text('Error: ${transactionSnapshot.error}'));
                    }
                    final transactions = transactionSnapshot.data ?? [];
                    if (transactions.isEmpty) {
                      return const Center(
                        child: EmptyStateCard(
                          icon: Iconsax.document_text_1,
                          title: 'Sin Movimientos',
                          message: 'Aún no has registrado transacciones en esta cuenta.',
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
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
                ),
              ),
            ],
          )
        );
      },
    );
  }
}