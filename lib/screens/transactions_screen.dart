// lib/screens/transactions_screen.dart (VERSIÓN FINAL REACTIVA)

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/data/account_repository.dart'; // Necesario para editar
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart'; // Necesario para editar
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';

class TransactionsScreen extends StatefulWidget {
  final TransactionRepository transactionRepository;
  // Añadimos AccountRepository para poder pasarlo a la pantalla de edición
  final AccountRepository accountRepository;

  const TransactionsScreen({
    super.key,
    required this.transactionRepository,
    required this.accountRepository, // Añadido
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final Stream<List<Transaction>> _transactionsStream;
  late final StreamSubscription<AppEvent> _eventSubscription;
  @override
  void initState() {
    super.initState();
    _transactionsStream = widget.transactionRepository.getTransactionsStream();

    // --- AÑADIDO: Escuchamos eventos para forzar la recarga ---
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      if ({
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted
      }.contains(event)) {
        // En lugar de recargar el stream, le decimos al repositorio que emita nuevos datos.
        // Asumimos que el repositorio tiene un método forceRefresh().
        widget.transactionRepository.forceRefresh();
      }
    });
  }

  void _navigateToEdit(Transaction transaction) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditTransactionScreen(
        transaction: transaction,
        transactionRepository: widget.transactionRepository,
        accountRepository: widget.accountRepository,
      ),
    ));
  }

  // --- CORREGIDO: Lógica de borrado completa traída desde el Dashboard ---
  Future<bool> _handleDelete(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          backgroundColor:
              Theme.of(context).colorScheme.surface.withOpacity(0.85),
          title: const Text('Confirmar eliminación'),
          content:
              const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await widget.transactionRepository.deleteTransaction(transaction.id);
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
          // Disparamos el evento para que la UI se actualice automáticamente
          // gracias al StreamSubscription que ya teníamos en initState.
          EventService.instance.fire(AppEvent.transactionDeleted);
        }
        return true; // Se borró con éxito
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
        }
        return false; // Hubo un error
      }
    }
    return false; // No se confirmó el borrado
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Todos los Movimientos', style: GoogleFonts.poppins()),
        // Aquí puedes añadir botones para filtrar y buscar en el futuro
      ),
      body: StreamBuilder<List<Transaction>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Aún no tienes movimientos.'));
          }
          final transactions = snapshot.data!;
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionTile(
                transaction: transaction,
                onTap: () => _navigateToEdit(transaction),
                onDeleted: () => _handleDelete(transaction),
              );
            },
          );
        },
      ),
    );
  }
}
