// lib/widgets/goals/contribute_to_goal_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/account_model.dart'; // Asegúrate de tener este modelo
import '../../models/goal_model.dart';

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
  List<Account> _accounts = [];
  bool _isLoading = false;
  bool _isFetchingAccounts = true;

  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final response = await supabase.from('accounts').select();
      _accounts = (response as List).map((data) => Account.fromMap(data)).toList();
      if (_accounts.isNotEmpty) {
        _selectedAccount = _accounts.first;
      }
    } catch (e) {
      // Manejar error
    } finally {
      setState(() {
        _isFetchingAccounts = false;
      });
    }
  }

  Future<void> _submitContribution() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);

      await supabase.rpc('add_contribution_to_goal', params: {
        'goal_id_input': widget.goal.id,
        'account_id_input': int.parse(_selectedAccount!.id),
        'amount_input': amount,
      });

      if (mounted) {
        Navigator.of(context).pop(); // Cierra el modal
        widget.onSuccess(); // Llama al callback para refrescar la lista
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: _isLoading || _isFetchingAccounts
          ? const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()))
          : Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Aportar a "${widget.goal.name}"',
                      style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad a Aportar',
                      prefixIcon: Icon(Icons.monetization_on_outlined),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
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
                  if (_accounts.isNotEmpty)
                    DropdownButtonFormField<Account>(
                      value: _selectedAccount,
                      onChanged: (Account? newValue) {
                        setState(() { _selectedAccount = newValue; });
                      },
                      items: _accounts.map<DropdownMenuItem<Account>>((Account account) {
                        return DropdownMenuItem<Account>(
                          value: account,
                          child: Text('${account.name} (Saldo: \$${account.balance.toStringAsFixed(2)})'),
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
                    onPressed: _submitContribution,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Confirmar Aportación'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}