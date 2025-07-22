// lib/screens/recurring_transactions_screen.dart (NUEVO ARCHIVO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/screens/add_recurring_transaction_screen.dart';
import 'package:sasper/data/account_repository.dart'; // Necesario para la pantalla de añadir

class RecurringTransactionsScreen extends StatefulWidget {
  final RecurringRepository repository;
  final AccountRepository accountRepository; // Lo recibimos para pasarlo

  const RecurringTransactionsScreen({
    super.key,
    required this.repository,
    required this.accountRepository,
  });

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  late final Stream<List<RecurringTransaction>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.getRecurringTransactionsStream();
  }

  void _navigateToAdd() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddRecurringTransactionScreen(
        repository: widget.repository,
        accountRepository: widget.accountRepository,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gastos Fijos', style: GoogleFonts.poppins()),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square),
            onPressed: _navigateToAdd,
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringTransaction>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(child: Text('No tienes gastos fijos programados.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.description),
                subtitle: Text('Próximo: ${item.nextDueDate.toLocal().toString().split(' ')[0]}'),
                trailing: Text('\$${item.amount.toStringAsFixed(2)}'),
                leading: Icon(item.type == 'Gasto' ? Iconsax.arrow_down : Iconsax.arrow_up),
              );
            },
          );
        },
      ),
    );
  }
}