// lib/screens/add_recurring_transaction_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/notification_service.dart'; 
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

import 'dart:developer' as developer;

class AddRecurringTransactionScreen extends StatefulWidget {
  // El constructor ahora es simple y constante. No recibe ningún parámetro.
  const AddRecurringTransactionScreen({super.key});

  @override
  State<AddRecurringTransactionScreen> createState() => _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState extends State<AddRecurringTransactionScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final RecurringRepository _repository = RecurringRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isLoading = false;
  String _type = 'Gasto';
  String _frequency = 'mensual';
  String? _selectedAccountId;
  late DateTime _startDate;
  final String _category = 'Gastos Fijos';
  late Future<List<Account>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    // Usamos el Singleton para obtener las cuentas.
    _accountsFuture = _accountRepository.getAccounts();
    _startDate = DateTime.now();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      NotificationHelper.show(
        message: 'Por favor, completa todos los campos requeridos.',
        type: NotificationType.error,
      );
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      // 2. AHORA CAPTURAMOS EL RESULTADO DE LA LLAMADA AL REPOSITORIO
      final newTransaction = await _repository.addRecurringTransaction(
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        type: _type,
        category: _category,
        accountId: _selectedAccountId!,
        frequency: _frequency,
        interval: 1,
        startDate: _startDate,
      );

      // 3. PASAMOS LA NUEVA TRANSACCIÓN AL SERVICIO DE NOTIFICACIONES
      await NotificationService.instance.scheduleRecurringReminders(newTransaction);
      developer.log('✅ Notificaciones programadas para: ${newTransaction.description}', name: 'AddRecurringScreen');
      
      // Usamos la instancia del Singleton para llamar al método.
      await _repository.addRecurringTransaction(
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        type: _type,
        category: _category,
        accountId: _selectedAccountId!,
        frequency: _frequency,
        interval: 1,
        startDate: _startDate,
      );

      if (mounted) {
        // Devolvemos 'true' para que la pantalla anterior sepa que hubo un cambio.
        Navigator.of(context).pop(true);
        // Mostramos la notificación después de que la navegación haya terminado.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Gasto fijo creado correctamente.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL GUARDAR GASTO FIJO: $e', name: 'AddRecurringScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al guardar: ${e.toString().replaceFirst("Exception: ", "")}',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nuevo Gasto Fijo', style: GoogleFonts.poppins())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descripción',
                hintText: 'Ej: Suscripción a Netflix, Alquiler',
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
            FutureBuilder<List<Account>>(
              // Usamos el Future que inicializamos en initState.
              future: _accountsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                if (snapshot.hasError) return Text('Error: ${snapshot.error}');
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Text('Crea una cuenta primero.');

                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  items: snapshot.data!.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name))).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  decoration: InputDecoration(
                    labelText: 'Cuenta de Origen',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Iconsax.wallet_3),
                  ),
                  validator: (v) => v == null ? 'Debes seleccionar una cuenta' : null,
                );
              },
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
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Theme.of(context).dividerColor)),
              leading: const Icon(Iconsax.calendar_1),
              title: const Text('Fecha de inicio'),
              subtitle: Text(DateFormat.yMMMd('es_CO').format(_startDate)),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Guardar Gasto Fijo'),
            ),
          ],
        ),
      ),
    );
  }
}