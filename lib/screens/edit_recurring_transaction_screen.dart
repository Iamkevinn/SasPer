// lib/screens/edit_recurring_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class EditRecurringTransactionScreen extends StatefulWidget {
  final RecurringTransaction transaction;

  // El constructor ahora solo requiere la transacción a editar.
  const EditRecurringTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditRecurringTransactionScreen> createState() => _EditRecurringTransactionScreenState();
}

class _EditRecurringTransactionScreenState extends State<EditRecurringTransactionScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final RecurringRepository _repository = RecurringRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;

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
    // Usamos el Singleton para obtener las cuentas.
    _accountsFuture = _accountRepository.getAccounts();
    
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

      // Usamos el Singleton para actualizar la transacción.
      await _repository.updateRecurringTransaction(updatedTransaction);

      if (mounted) {
        // Devolvemos 'true' para que la pantalla anterior sepa que hubo un cambio.
        Navigator.of(context).pop(true);
        
        // Mostramos la notificación después de que la navegación haya terminado.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Gasto fijo actualizado.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR GASTO FIJO: $e', name: 'EditRecurringScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al actualizar: ${e.toString().replaceFirst("Exception: ", "")}',
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
          
          // Lógica para manejar si la cuenta original fue borrada.
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
                    if (double.parse(v.replaceAll(',', '.')) <= 0) return 'El monto debe ser mayor a cero';
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