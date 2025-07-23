// lib/screens/register_payment_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Fuente consistente
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:sasper/data/account_repository.dart'; // <-- Usamos el repo
import 'package:sasper/data/debt_repository.dart';   // <-- Usamos el repo
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart'; // Para refrescar la UI global

class RegisterPaymentScreen extends StatefulWidget {
  final Debt debt;
  
  // --- ¡CAMBIO ARQUITECTÓNICO! ---
  // Inyectamos las dependencias necesarias.
  final DebtRepository debtRepository;
  final AccountRepository accountRepository;

  const RegisterPaymentScreen({
    super.key,
    required this.debt,
    // Hacemos que los repositorios sean requeridos.
    required this.debtRepository,
    required this.accountRepository,
  });

  @override
  State<RegisterPaymentScreen> createState() => _RegisterPaymentScreenState();
}

class _RegisterPaymentScreenState extends State<RegisterPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // El `_debtService` local se elimina.
  
  Account? _selectedAccount;
  bool _isLoading = false;
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    // --- ¡CAMBIO CLAVE! ---
    // Usamos el repositorio inyectado para obtener las cuentas.
    _accountsFuture = widget.accountRepository.getAccounts();
    _amountController.text = widget.debt.currentBalance.toStringAsFixed(2);
  }

  // El método `_getAccounts()` local se elimina.

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final paymentAmount = double.parse(_amountController.text);
      
      // --- ¡CAMBIO CLAVE! ---
      // Usamos el método del DebtRepository inyectado.
      await widget.debtRepository.registerPayment(
        debtId: widget.debt.id,
        debtType: widget.debt.type,
        paymentAmount: paymentAmount,
        fromAccountId: _selectedAccount!.id,
        description: _descriptionController.text.trim().isNotEmpty 
          ? _descriptionController.text.trim()
          : 'Pago para: ${widget.debt.name}',
      );

      if (!mounted) return;

      // --- ¡NUEVO! ---
      // Notificamos a toda la app que los datos han cambiado.
      EventService.instance.fire(AppEvent.debtsChanged);
      EventService.instance.fire(AppEvent.transactionsChanged);

      NotificationHelper.show(
            context: context,
            message: 'Operación registrada con exito!',
            type: NotificationType.success,
          );
      Navigator.of(context).pop(); // Simplemente cerramos la pantalla

    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
            context: context,
            message: 'Error "${e.toString()}"',
            type: NotificationType.error,
          );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPayingDebt = widget.debt.type == DebtType.debt;
    final title = isPayingDebt ? 'Registrar Pago' : 'Registrar Cobro';
    final amountLabel = isPayingDebt ? 'Monto a Pagar' : 'Monto a Cobrar';
    final accountLabel = isPayingDebt ? 'Pagar desde la cuenta' : 'Recibir en la cuenta';
    final buttonLabel = isPayingDebt ? 'Confirmar Pago' : 'Confirmar Cobro';

    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.poppins()), // <-- Fuente Consistente
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDebtInfoCard(),
              const SizedBox(height: 24),
              
              // El resto del formulario es funcionalmente idéntico,
              // ya que la lógica de UI y validación era muy buena.
              // Solo cambiamos las fuentes para consistencia.
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: amountLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Iconsax.dollar_circle),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'El monto es obligatorio';
                  final amount = double.tryParse(value);
                  if (amount == null) return 'Introduce un número válido';
                  if (amount <= 0) return 'El monto debe ser mayor a cero';
                  if (amount > widget.debt.currentBalance) return 'El monto no puede superar el saldo pendiente';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Text('Error al cargar cuentas: ${snapshot.error}');
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No tienes cuentas para seleccionar.');
                  }

                  return DropdownButtonFormField<Account>(
                    value: _selectedAccount,
                    decoration: InputDecoration(
                      labelText: accountLabel,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Iconsax.wallet_3),
                    ),
                    items: snapshot.data!.map((account) => DropdownMenuItem(value: account, child: Text(account.name))).toList(),
                    onChanged: (value) => setState(() => _selectedAccount = value),
                    validator: (value) => value == null ? 'Debes seleccionar una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  hintText: 'Ej. Cuota mensual, pago final...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.document_text),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.send_1),
                  label: Text(_isLoading ? 'Procesando...' : buttonLabel),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtInfoCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.debt.name,
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (widget.debt.entityName != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  widget.debt.entityName!,
                  style: GoogleFonts.poppins(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Saldo Pendiente:'),
                Text(
                  NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(widget.debt.currentBalance),
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}