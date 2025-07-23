// lib/screens/add_debt_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Para consistencia
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

// --- ¡CAMBIO CLAVE! ---
// Solo importamos los repositorios y modelos, no los servicios.
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class AddDebtScreen extends StatefulWidget {
  // --- ¡CAMBIO CLAVE! ---
  // Ahora requiere los repositorios en su constructor.
  final DebtRepository debtRepository;
  final AccountRepository accountRepository;

  const AddDebtScreen({
    super.key,
    required this.debtRepository,
    required this.accountRepository,
  });

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _entityController = TextEditingController();
  final _amountController = TextEditingController();

  // Se eliminan las instancias locales de servicios/repositorios.

  DebtType _selectedDebtType = DebtType.debt;
  Account? _selectedAccount;
  DateTime? _dueDate;
  bool _isLoading = false;
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    // Usamos el repositorio que viene del widget.
    _accountsFuture = widget.accountRepository.getAccounts(); 
  }

  @override
  void dispose() {
    _nameController.dispose();
    _entityController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAccount == null) {
      NotificationHelper.show(
            context: context,
            message: 'Porfavor seleccionar una cuenta.',
            type: NotificationType.error,
          );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- ¡CAMBIO CLAVE! ---
      // Usamos el repositorio inyectado.
      await widget.debtRepository.addDebtAndInitialTransaction(
        name: _nameController.text.trim(),
        type: _selectedDebtType,
        entityName: _entityController.text.trim().isNotEmpty ? _entityController.text.trim() : null,
        amount: double.parse(_amountController.text),
        accountId: _selectedAccount!.id,
        dueDate: _dueDate,
      );

      if (!mounted) return;

      // El stream del DebtRepository se encargará de notificar a la pantalla de deudas.
      // Solo necesitamos notificar al Dashboard que las transacciones cambiaron.
      EventService.instance.fire(AppEvent.transactionsChanged);

      NotificationHelper.show(
            context: context,
            message: 'Operación guardada!',
            type: NotificationType.success,
          );
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
            context: context,
            message: 'Error al guardar la transacción.',
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Añadir Deuda o Préstamo', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El resto del build está perfecto, solo se ajusta la fuente.
              SegmentedButton<DebtType>(
                segments: const <ButtonSegment<DebtType>>[
                  ButtonSegment<DebtType>(value: DebtType.debt, label: Text('Yo Debo'), icon: Icon(Iconsax.arrow_down)),
                  ButtonSegment<DebtType>(value: DebtType.loan, label: Text('Me Deben'), icon: Icon(Iconsax.arrow_up)),
                ],
                selected: {_selectedDebtType},
                onSelectionChanged: (newSelection) => setState(() => _selectedDebtType = newSelection.first),
                style: SegmentedButton.styleFrom(fixedSize: const Size.fromHeight(50)),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Concepto', hintText: 'Ej. Préstamo para el coche', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.note_1)),
                validator: (value) => (value == null || value.isEmpty) ? 'El concepto es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _entityController,
                decoration: const InputDecoration(labelText: 'Persona o Entidad (Opcional)', hintText: 'Ej. Banco XYZ, Juan Pérez', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.user)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Monto Total', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.dollar_circle)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'El monto es obligatorio';
                  if (double.tryParse(value) == null) return 'Introduce un número válido';
                  if (double.parse(value) <= 0) return 'El monto debe ser mayor a cero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: LinearProgressIndicator());
                  if (snapshot.hasError) return Text('Error al cargar cuentas: ${snapshot.error}');
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('No se encontraron cuentas.');
                  
                  return DropdownButtonFormField<Account>(
                    value: _selectedAccount,
                    decoration: const InputDecoration(labelText: 'Cuenta afectada', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.wallet_3)),
                    items: snapshot.data!.map((account) => DropdownMenuItem(value: account, child: Text(account.name))).toList(),
                    onChanged: (value) => setState(() => _selectedAccount = value),
                    validator: (value) => value == null ? 'Selecciona una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).colorScheme.outline)),
                leading: const Icon(Iconsax.calendar_1),
                title: Text(_dueDate == null ? 'Fecha de Vencimiento (Opcional)' : 'Vence: ${DateFormat.yMMMd('es_MX').format(_dueDate!)}'),
                trailing: const Icon(Iconsax.arrow_right_3),
                onTap: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (pickedDate != null) setState(() => _dueDate = pickedDate);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.save_2),
                  label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}