import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/event_service.dart';

class AddTransferScreen extends StatefulWidget {
  const AddTransferScreen({super.key});

  @override
  State<AddTransferScreen> createState() => _AddTransferScreenState();
}

class _AddTransferScreenState extends State<AddTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _fromAccountId;
  int? _toAccountId;
  bool _isLoading = false;

  late final Future<List<Map<String, dynamic>>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = Supabase.instance.client
        .rpc('get_accounts_with_balance')
        .then((data) => List<Map<String, dynamic>>.from(data));
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar ambas cuentas.')));
      return;
    }
    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las cuentas no pueden ser la misma.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.rpc('create_transfer', params: {
        'from_account_id': _fromAccountId,
        'to_account_id': _toAccountId,
        'transfer_amount': double.parse(_amountController.text),
        'transfer_description': _descriptionController.text.trim(),
      });

      EventService.instance.emit(AppEvent.transactionCreated);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Transferencia realizada!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Transferencia')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.length < 2) {
            return const Center(child: Text('Necesitas al menos dos cuentas para transferir.'));
          }
          return _buildForm(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildForm(List<Map<String, dynamic>> accounts) {
    final currencyStyle = Theme.of(context).textTheme.titleLarge;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown para la cuenta de origen
            _buildAccountDropdown(
              label: 'Desde la cuenta',
              value: _fromAccountId,
              onChanged: (val) => setState(() => _fromAccountId = val),
              accounts: accounts,
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: Icon(Iconsax.arrow_down, color: Colors.grey)),
            ),
            // Dropdown para la cuenta de destino
            _buildAccountDropdown(
              label: 'Hacia la cuenta',
              value: _toAccountId,
              onChanged: (val) => setState(() => _toAccountId = val),
              accounts: accounts,
            ),
            const SizedBox(height: 24),
            // Campo de monto
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixIcon: Padding(padding: const EdgeInsets.all(12.0), child: Text('\$', style: currencyStyle)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (val) => val == null || val.isEmpty || double.tryParse(val) == null || double.parse(val) <= 0 ? 'Ingresa un monto válido' : null,
            ),
            const SizedBox(height: 24),
            // Campo de descripción
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Descripción (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 32),
            // Botón de enviar
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _submitTransfer,
              icon: _isLoading ? const SizedBox.shrink() : const Icon(Iconsax.send_1),
              label: _isLoading ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2) : const Text('Realizar Transferencia'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget helper para no repetir el código del Dropdown
  Widget _buildAccountDropdown({
    required String label,
    required int? value,
    required void Function(int?) onChanged,
    required List<Map<String, dynamic>> accounts,
  }) {
    return DropdownButtonFormField<int>(
      value: value,
      items: accounts.map((acc) {
        // --- CORRECCIÓN CLAVE AQUÍ ---
        // Hacemos un cast explícito para asegurar que el valor es un int.
        final int accountId = acc['id'] as int;
        final String accountName = acc['name']?.toString() ?? 'Sin Nombre';
        return DropdownMenuItem<int>(
          value: accountId,
          child: Text(accountName),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (val) => val == null ? 'Selecciona una cuenta' : null,
    );
  }
}