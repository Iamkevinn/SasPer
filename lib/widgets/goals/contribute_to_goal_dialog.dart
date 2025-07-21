// lib/widgets/goals/contribute_to_goal_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/account_repository.dart'; // Asumimos que tienes un AccountRepository
import '../../models/account_model.dart';
import '../../models/goal_model.dart';
// import '../../services/goal_service.dart'; // Idealmente, la lógica de RPC iría aquí

class ContributeToGoalDialog extends StatefulWidget {
  final Goal goal;
  final VoidCallback onSuccess;

  const ContributeToGoalDialog({
    super.key,
    required this.goal,
    required this.onSuccess,
  });

  @override
  State<ContributeToGoalDialog> createState() => _ContributeToGoalDialogState();
}

class _ContributeToGoalDialogState extends State<ContributeToGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Account? _selectedAccount;
  bool _isSubmitting = false;

  // 1. DEPENDENCIAS (idealmente inyectadas)
  final _accountRepo = AccountRepository();
  // final _goalService = GoalService();
  final _supabase = Supabase.instance.client; // Lo mantenemos por ahora

  // Futuro para cargar las cuentas
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    // Llamamos al repositorio para obtener las cuentas
    _accountsFuture = _accountRepo.getAccounts(); // Asumimos que este método existe
  }

  Future<void> _submitContribution() async {
    // La validación ahora es un poco más simple
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text);

      // await _goalService.addContribution(...)
      await _supabase.rpc('add_contribution_to_goal', params: {
        'goal_id_input': widget.goal.id,
        'account_id_input': _selectedAccount!.id,
        'amount_input': amount,
      });

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Aportación realizada!'), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
  
  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aportar a "${widget.goal.name}"',
            // 2. USAMOS EL TEMA
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // 3. Usamos un FutureBuilder para manejar la carga de cuentas
          FutureBuilder<List<Account>>(
            future: _accountsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No se encontraron cuentas disponibles para realizar la aportación.');
              }
              
              final accounts = snapshot.data!;
              // Seteamos la primera cuenta por defecto si no hay ninguna seleccionada
              _selectedAccount ??= accounts.first;

              // Devolvemos el formulario solo cuando las cuentas están cargadas
              return _buildForm(accounts);
            },
          ),
        ],
      ),
    );
  }

  // 4. El formulario se extrae a su propio método para mayor claridad
  Widget _buildForm(List<Account> accounts) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Cantidad a Aportar',
              prefixIcon: Icon(Iconsax.money_send),
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Introduce una cantidad';
              final amount = double.tryParse(value);
              if (amount == null || amount <= 0) return 'Cantidad no válida';
              if (_selectedAccount != null && amount > _selectedAccount!.balance) {
                return 'Saldo insuficiente en la cuenta';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Account>(
            value: _selectedAccount,
            onChanged: (Account? newValue) {
              setState(() => _selectedAccount = newValue);
            },
            items: accounts.map((account) {
              return DropdownMenuItem<Account>(
                value: account,
                child: Text('${account.name} (Saldo: \$${account.balance.toStringAsFixed(0)})'),
              );
            }).toList(),
            decoration: const InputDecoration(
              labelText: 'Desde la cuenta',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null ? 'Selecciona una cuenta' : null,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitContribution,
            icon: _isSubmitting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Iconsax.send_1),
            label: Text(_isSubmitting ? 'Procesando...' : 'Confirmar Aportación'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}