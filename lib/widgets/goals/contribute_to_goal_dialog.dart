// lib/widgets/goals/contribute_to_goal_dialog.dart (VERSIÓN FINAL CON SINGLETON)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/goal_model.dart';
//import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
//import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class ContributeToGoalDialog extends StatefulWidget {
  final Goal goal;
  // El onSuccess sigue siendo útil para que la pantalla de Metas
  // sepa cuándo debe forzar su propio refresco si es necesario.
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
  // Accedemos a la única instancia (Singleton) del repositorio.
  final AccountRepository _accountRepo = AccountRepository.instance;
  final GoalRepository _goalRepo = GoalRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  Account? _selectedAccount;
  bool _isSubmitting = false;

  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    // Usamos la instancia singleton para cargar las cuentas.
    _accountsFuture = _accountRepo.getAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  Future<void> _submitContribution() async {
    if (!_formKey.currentState!.validate() || _selectedAccount == null) return;

    setState(() => _isSubmitting = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      
      // Usamos el método del repositorio en lugar de una llamada RPC directa.
      await _goalRepo.addContribution(
        goalId: widget.goal.id,
        accountId: _selectedAccount!.id,
        amount: amount,
      );

      if (mounted) {
        // Los eventos ya no se disparan aquí, el repositorio puede hacerlo si es necesario,
        // pero la arquitectura reactiva se encargará.
        // EventService.instance.fire(...);

        Navigator.of(context).pop(); // Cerramos el diálogo
        widget.onSuccess(); // Llamamos al callback para refresco local

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Aportación realizada!',
            type: NotificationType.success,
          );
        });
      }
    } catch (error) {
      developer.log('🔥 FALLO AL APORTAR A META: $error', name: 'ContributeToGoalDialog');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al realizar la aportación.',
            type: NotificationType.error,
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Añadimos un poco más de padding vertical para que no se sienta tan apretado.
      padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aportar a "${widget.goal.name}"',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
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
              if (_selectedAccount == null && accounts.isNotEmpty) {
                _selectedAccount = accounts.first;
              }

              return _buildForm(accounts);
            },
          ),
        ],
      ),
    );
  }

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
              final amount = double.tryParse(value.replaceAll(',', '.'));
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
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Iconsax.send_1),
            label: Text(_isSubmitting ? 'Procesando...' : 'Confirmar Aportación'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)
            ),
          ),
        ],
      ),
    );
  }
}