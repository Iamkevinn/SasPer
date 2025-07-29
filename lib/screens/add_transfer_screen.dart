// lib/screens/add_transfer_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class AddTransferScreen extends StatefulWidget {
  // El constructor es constante y no recibe parámetros.
  const AddTransferScreen({super.key});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final AccountRepository _accountRepository = AccountRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  Account? _fromAccount;
  Account? _toAccount;
  bool _isLoading = false;

  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    // Usamos la instancia singleton para cargar las cuentas.
    _accountsFuture = _accountRepository.getAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Valida el formulario y llama al repositorio para crear la transferencia.
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fromAccount == null || _toAccount == null) {
       NotificationHelper.show(
            message: 'Debes seleccionar ambas cuentas.',
            type: NotificationType.error,
          );
       return;
    }
    if (_fromAccount!.id == _toAccount!.id) {
       NotificationHelper.show(
            message: 'No puedes transferir a la misma cuenta.',
            type: NotificationType.error,
          );
       return;
    }

    setState(() => _isLoading = true);

    try {
      await _accountRepository.createTransfer(
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        // Disparamos un evento global para que otras partes de la app se enteren.
        EventService.instance.fire(AppEvent.transactionsChanged);
        
        // Devolvemos 'true' para que la pantalla anterior sepa que la operación fue exitosa.
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transferencia realizada con éxito!',
            type: NotificationType.success,
          );
        });
      }

    } catch (e) {
      developer.log('🔥 FALLO AL CREAR TRANSFERENCIA: $e', name: 'AddTransferScreen');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al realizar la transferencia: ${e.toString().replaceFirst("Exception: ", "")}',
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
      appBar: AppBar(
        title: Text('Nueva Transferencia', style: GoogleFonts.poppins()),
      ),
      body: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || (snapshot.data?.length ?? 0) < 2) {
            return const Center(child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Necesitas al menos dos cuentas para poder realizar una transferencia.', textAlign: TextAlign.center),
            ));
          }

          final accounts = snapshot.data!;
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildAccountDropdown(
                    label: 'Desde la cuenta',
                    value: _fromAccount,
                    accounts: accounts,
                    onChanged: (value) => setState(() => _fromAccount = value),
                    icon: Iconsax.export
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Center(child: Icon(Iconsax.arrow_down, color: Colors.grey)),
                  ),
                  _buildAccountDropdown(
                    label: 'Hacia la cuenta',
                    value: _toAccount,
                    accounts: accounts,
                    onChanged: (value) => setState(() => _toAccount = value),
                    icon: Iconsax.import
                  ),
                  const SizedBox(height: 24),
                  
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(labelText: 'Monto a Transferir', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.dollar_circle)),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'El monto es obligatorio';
                      final amount = double.tryParse(value.replaceAll(',', '.'));
                      if (amount == null || amount <= 0) return 'Introduce un monto válido';
                      if (_fromAccount != null && amount > _fromAccount!.balance) return 'Saldo insuficiente en la cuenta de origen';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                   TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Descripción (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.note)),
                  ),
                  const SizedBox(height: 32),

                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.send_1),
                    label: Text(_isLoading ? 'Procesando...' : 'Confirmar Transferencia'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Widget helper para construir los Dropdowns de selección de cuenta.
  Widget _buildAccountDropdown({
    required String label,
    required Account? value,
    required List<Account> accounts,
    required void Function(Account?) onChanged,
    required IconData icon,
  }) {
    return DropdownButtonFormField<Account>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      items: accounts.map((acc) {
        return DropdownMenuItem<Account>(
          value: acc,
          child: Text(acc.name),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (val) => val == null ? 'Selecciona una cuenta' : null,
    );
  }
}