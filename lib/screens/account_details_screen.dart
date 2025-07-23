// lib/screens/account_details_screen.dart (VERSIÓN FINAL CORREGIDA)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'edit_transaction_screen.dart';

class AccountDetailsScreen extends StatefulWidget {
  final Account account;
  final AccountRepository accountRepository;
  final TransactionRepository transactionRepository;

  const AccountDetailsScreen({
    super.key,
    required this.account,
    required this.accountRepository,
    required this.transactionRepository,
  });

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  // 2. MEJORA: Añadimos estado para la cuenta y las transacciones
  late Future<void> _dataFuture;
  late Account _currentAccount;
  List<Transaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _currentAccount = widget.account; // Inicializamos con los datos que llegan
    _loadData();
  }

  // 2. MEJORA: Esta función ahora carga todos los datos necesarios para la pantalla.
  Future<void> _loadData() async {
    _dataFuture = _fetchData();
    setState(() {}); // Provoca que el FutureBuilder se reconstruya con el nuevo future
  }
  
  Future<void> _fetchData() async {
      // Obtenemos los datos en paralelo para más eficiencia
      final results = await Future.wait([
        widget.accountRepository.getTransactionsForAccount(widget.account.id),
        widget.accountRepository.getAccountById(widget.account.id),
      ]);
      
      _transactions = results[0] as List<Transaction>;
      // Actualizamos la cuenta actual si se encontró una versión más nueva
      if(results[1] != null) {
        _currentAccount = results[1] as Account;
      }
  }

  void _navigateToEditTransaction(Transaction transaction) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(
          transaction: transaction,
          transactionRepository: widget.transactionRepository,
          accountRepository: widget.accountRepository,
        ),
      ),
    ).then((changed) {
      if (changed == true) {
        _loadData(); // Recargamos TODOS los datos de la pantalla
        widget.accountRepository.forceRefresh();
      }
    });
  }

  Future<bool> _handleDeleteTransaction(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        // 1. CORRECCIÓN: Llenamos el AlertDialog
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.85),
          title: const Text('Confirmar eliminación'),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor: Theme.of(context).colorScheme.onErrorContainer),
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
          _loadData(); // Recargamos TODOS los datos
          widget.accountRepository.forceRefresh();
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            context: context,
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
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name, style: GoogleFonts.poppins()),
      ),
      body: FutureBuilder<void>(
        future: _dataFuture,
        builder: (context, snapshot) {
          // Si estamos cargando, mostramos un indicador de progreso
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Si hay un error, lo mostramos
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }
          
          // Si todo va bien, construimos la UI con los datos ya cargados
          return Column(
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
                          // 2. MEJORA: Usamos el balance de la cuenta en el estado
                          Text(
                            currencyFormat.format(_currentAccount.balance),
                            style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: _currentAccount.balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Historial de Movimientos', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(indent: 16, endIndent: 16, height: 24),
              Expanded(
                child: _transactions.isEmpty
                    ? const Center(child: Text('No hay movimientos en esta cuenta.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final transaction = _transactions[index];
                          return TransactionTile(
                            transaction: transaction,
                            onTap: () => _navigateToEditTransaction(transaction),
                            onDeleted: () => _handleDeleteTransaction(transaction),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
