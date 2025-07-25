// lib/screens/edit_recurring_transaction_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class EditRecurringTransactionScreen extends StatefulWidget {
  final RecurringRepository repository;
  final AccountRepository accountRepository;
  final RecurringTransaction transaction;

  const EditRecurringTransactionScreen({
    super.key,
    required this.repository,
    required this.accountRepository,
    required this.transaction,
  });

  @override
  State<EditRecurringTransactionScreen> createState() => _EditRecurringTransactionScreenState();
}

class _EditRecurringTransactionScreenState extends State<EditRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;
  
  late String _type;
  late String _frequency;
  String? _selectedAccountId;
  
  bool _isLoading = false;
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = widget.accountRepository.getAccounts();
    
    final t = widget.transaction;
    _descriptionController = TextEditingController(text: t.description);
    _amountController = TextEditingController(text: t.amount.toStringAsFixed(0));
    _type = t.type;
    _frequency = t.frequency;
    _selectedAccountId = t.accountId;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) return;
    setState(() => _isLoading = true);

    try {
      final updatedTransaction = widget.transaction.copyWith(
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        type: _type,
        accountId: _selectedAccountId,
        frequency: _frequency,
      );

      await widget.repository.updateRecurringTransaction(updatedTransaction);

      if (mounted) {
        // --- LA LÓGICA CLAVE ---
        EventService.instance.fire(AppEvent.recurringTransactionChanged); // Disparamos el evento
        
        Navigator.of(context).pop(); // Ya no necesitamos devolver `true`
        NotificationHelper.show(
          context: context,
          message: 'Gasto fijo actualizado.',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
         EventService.instance.fire(AppEvent.recurringTransactionChanged);
        NotificationHelper.show(
          context: context,
          message: 'Error al actualizar: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Editar Gasto Fijo', style: GoogleFonts.poppins())),
      body: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _selectedAccountId == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error al cargar cuentas: ${snapshot.error}'));
          final accounts = snapshot.data ?? [];
          // Asegurarse de que el _selectedAccountId inicial todavía sea válido
          if (accounts.isNotEmpty && !accounts.any((acc) => acc.id == _selectedAccountId)) {
            _selectedAccountId = accounts.first.id;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 16),
                TextFormField(controller: _amountController, decoration: const InputDecoration(labelText: 'Monto'), keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _type,
                  items: ['Gasto', 'Ingreso'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => _type = val!),
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  items: accounts.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name))).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  decoration: const InputDecoration(labelText: 'Cuenta'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _frequency,
                  items: ['diario', 'semanal', 'quincenal', 'mensual'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                  onChanged: (val) => setState(() => _frequency = val!),
                  decoration: const InputDecoration(labelText: 'Frecuencia'),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _update,
                  child: const Text('Actualizar Gasto Fijo'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}