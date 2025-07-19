// lib/screens/add_transfer_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../data/account_repository.dart';
import '../models/account_model.dart';
import '../services/event_service.dart';

class AddTransferScreen extends StatefulWidget {
  // Ahora recibe el repositorio, siguiendo nuestra arquitectura.
  final AccountRepository accountRepository;

  const AddTransferScreen({super.key, required this.accountRepository});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
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
    _accountsFuture = widget.accountRepository.getAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_fromAccount == null || _toAccount == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar ambas cuentas.'), backgroundColor: Colors.orange));
       return;
    }
    if (_fromAccount!.id == _toAccount!.id) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No puedes transferir a la misma cuenta.'), backgroundColor: Colors.orange));
       return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.accountRepository.createTransfer(
        fromAccountId: _fromAccount!.id,
        toAccountId: _toAccount!.id,
        amount: double.parse(_amountController.text),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        // --- ¡LA CLAVE DE LA REACTIVIDAD! ---
        // Forzamos la actualización de los datos para ver los cambios inmediatamente.
        await widget.accountRepository.forceRefresh();
        
        EventService.instance.fire(AppEvent.transactionsChanged);

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transferencia realizada con éxito'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error));
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
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.length < 2) {
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
                      final amount = double.tryParse(value);
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

  // Widget helper para el Dropdown, ahora usando el modelo Account
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