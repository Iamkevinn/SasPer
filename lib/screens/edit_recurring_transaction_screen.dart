// lib/screens/edit_recurring_transaction_screen.dart (VERSIÓN FINAL USANDO SINGLETON)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart'; // Importamos el repositorio
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class EditRecurringTransactionScreen extends StatefulWidget {
  // RecurringRepository ya no se pasa como parámetro.
  final AccountRepository accountRepository;
  final RecurringTransaction transaction;

  const EditRecurringTransactionScreen({
    super.key,
    required this.accountRepository,
    required this.transaction,
  });

  @override
  State<EditRecurringTransactionScreen> createState() => _EditRecurringTransactionScreenState();
}

class _EditRecurringTransactionScreenState extends State<EditRecurringTransactionScreen> {
  // Accedemos a la única instancia del repositorio directamente.
  final RecurringRepository _repository = RecurringRepository.instance;

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
    _amountController = TextEditingController(text: t.amount.toStringAsFixed(2).replaceAll('.00', ''));
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
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        type: _type,
        accountId: _selectedAccountId,
        frequency: _frequency,
      );

      // Usamos la instancia _repository para llamar al método.
      await _repository.updateRecurringTransaction(updatedTransaction);

      if (mounted) {
        Navigator.of(context).pop(true);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            context: Navigator.of(context).context,
            message: 'Gasto fijo actualizado.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR GASTO FIJO: $e', name: 'EditRecurringScreen');
      if (mounted) {
        NotificationHelper.show(
          context: context,
          message: 'Error al actualizar. Revisa tu conexión o los permisos.',
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error al cargar cuentas: ${snapshot.error}'));
          
          final accounts = snapshot.data ?? [];
          
          if (_selectedAccountId != null && !accounts.any((acc) => acc.id == _selectedAccountId)) {
             _selectedAccountId = accounts.isNotEmpty ? accounts.first.id : null;
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.document_text),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'La descripción es requerida' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: InputDecoration(
                    labelText: 'Monto',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.money_4),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'El monto es requerido';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Ingresa un monto válido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _type,
                  items: ['Gasto', 'Ingreso'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setState(() => _type = val!),
                  decoration: InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.arrow_swap),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  items: accounts.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name))).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  decoration: InputDecoration(
                    labelText: 'Cuenta de Origen',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.wallet_3),
                  ),
                   validator: (v) => v == null ? 'Debes seleccionar una cuenta' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _frequency,
                  items: ['diario', 'semanal', 'quincenal', 'mensual'].map((f) => DropdownMenuItem(value: f, child: Text(toBeginningOfSentenceCase(f)!))).toList(),
                  onChanged: (val) => setState(() => _frequency = val!),
                  decoration: InputDecoration(
                    labelText: 'Frecuencia de Repetición',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.repeat),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _update,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                    : const Text('Actualizar Gasto Fijo'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}