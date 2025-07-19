import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../data/account_repository.dart';
import '../data/transaction_repository.dart';
import '../models/account_model.dart';
import '../models/transaction_models.dart';
import '../widgets/shared/transaction_tile.dart';
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
  late Future<List<Transaction>> _transactionsFuture;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  void _loadTransactions() {
    // Usamos el nuevo método del repositorio.
    _transactionsFuture = widget.accountRepository.getTransactionsForAccount(widget.account.id);
  }

  void _navigateToEditTransaction(Transaction transaction) {
    Navigator.of(context).push<bool>( // Esperamos un booleano para saber si hubo cambios
      MaterialPageRoute(
        builder: (context) => EditTransactionScreen(
          transactionToEdit: transaction,
          transactionRepository: widget.transactionRepository,
          accountRepository: widget.accountRepository,
        ),
      )
    ).then((changed) {
      // Si la pantalla de edición nos dice que hubo cambios, refrescamos.
      if (changed == true) {
        setState(() {
          _loadTransactions();
          // También le decimos al account repo que refresque los balances en la pantalla anterior
          widget.accountRepository.forceRefresh();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.name, style: GoogleFonts.poppins()),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0, color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Text('Saldo Actual', style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(widget.account.balance),
                      style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: widget.account.balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary),
                    ),
                  ],
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
            child: FutureBuilder<List<Transaction>>(
              future: _transactionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error al cargar movimientos: ${snapshot.error}'));
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text('No hay movimientos en esta cuenta.'));
                
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final transaction = snapshot.data![index];
                    return TransactionTile(
                      transaction: transaction,
                      onTap: () => _navigateToEditTransaction(transaction),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}