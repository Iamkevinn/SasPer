// lib/screens/add_recurring_transaction_screen.dart (NUEVO ARCHIVO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';

class AddRecurringTransactionScreen extends StatefulWidget {
  final RecurringRepository repository;
  final AccountRepository accountRepository;

  const AddRecurringTransactionScreen({
    super.key,
    required this.repository,
    required this.accountRepository,
  });

  @override
  State<AddRecurringTransactionScreen> createState() => _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState extends State<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  String _type = 'Gasto';
  String _frequency = 'mensual';
  String? _selectedAccountId;
  final DateTime _startDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nuevo Gasto Fijo', style: GoogleFonts.poppins())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Descripción')),
            TextFormField(controller: _amountController, decoration: const InputDecoration(labelText: 'Monto'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: _type,
              items: ['Gasto', 'Ingreso'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _type = val!),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            FutureBuilder<List<Account>>(
              future: widget.accountRepository.getAccounts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  items: snapshot.data!.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name))).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  decoration: const InputDecoration(labelText: 'Cuenta'),
                );
              },
            ),
            DropdownButtonFormField<String>(
              value: _frequency,
              items: ['diario', 'semanal', 'quincenal', 'mensual'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) => setState(() => _frequency = val!),
              decoration: const InputDecoration(labelText: 'Frecuencia'),
            ),
            // TODO: Añadir selector de fecha para _startDate
            ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar Gasto Fijo'),
            ),
          ],
        ),
      ),
    );
  }

  void _save() async {
    if (_formKey.currentState!.validate() && _selectedAccountId != null) {
      await widget.repository.addRecurringTransaction(
        description: _descriptionController.text,
        amount: double.parse(_amountController.text),
        type: _type,
        category: 'Gastos Fijos', // O pide una categoría al usuario
        accountId: _selectedAccountId!,
        frequency: _frequency,
        interval: 1, // Por simplicidad, puedes añadir un campo para esto
        startDate: _startDate,
      );
      if (mounted) Navigator.of(context).pop(true);
    }
  }
}