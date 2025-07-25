// lib/screens/add_recurring_transaction_screen.dart (NUEVO ARCHIVO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class AddRecurringTransactionScreen extends StatefulWidget {
  final RecurringRepository repository;
  final AccountRepository accountRepository;

  const AddRecurringTransactionScreen({
    super.key,
    required this.repository,
    required this.accountRepository,
  });

  @override
  State<AddRecurringTransactionScreen> createState() => _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState extends State<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  // --- AÑADIMOS EL ESTADO DE CARGA ---
  bool _isLoading = false;
  
  String _type = 'Gasto';
  String _frequency = 'mensual';
  String? _selectedAccountId;
  final DateTime _startDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nuevo Gasto Fijo', style: GoogleFonts.poppins())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Descripción')),
            TextFormField(controller: _amountController, decoration: const InputDecoration(labelText: 'Monto'), keyboardType: TextInputType.number),
            DropdownButtonFormField<String>(
              value: _type,
              items: ['Gasto', 'Ingreso'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _type = val!),
              decoration: const InputDecoration(labelText: 'Tipo'),
            ),
            FutureBuilder<List<Account>>(
              future: widget.accountRepository.getAccounts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                return DropdownButtonFormField<String>(
                  value: _selectedAccountId,
                  items: snapshot.data!.map((acc) => DropdownMenuItem(value: acc.id, child: Text(acc.name))).toList(),
                  onChanged: (val) => setState(() => _selectedAccountId = val),
                  decoration: const InputDecoration(labelText: 'Cuenta'),
                );
              },
            ),
            DropdownButtonFormField<String>(
              value: _frequency,
              items: ['diario', 'semanal', 'quincenal', 'mensual'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) => setState(() => _frequency = val!),
              decoration: const InputDecoration(labelText: 'Frecuencia'),
            ),
            // TODO: Añadir selector de fecha para _startDate
            ElevatedButton(
              onPressed: _save,
              child: const Text('Guardar Gasto Fijo'),
            ),
          ],
        ),
      ),
    );
  }

  // --- MÉTODO _save() CORREGIDO Y ROBUSTO ---
  Future<void> _save() async {
    // 1. Validar el formulario
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      return;
    }
    
    // 2. Iniciar el estado de carga y deshabilitar el botón
    setState(() => _isLoading = true);

    try {
      // 3. Llamar al repositorio
      await widget.repository.addRecurringTransaction(
        description: _descriptionController.text.trim(),
        amount: double.parse(_amountController.text),
        type: _type,
        category: 'Gastos Fijos', // Puedes cambiar esto
        accountId: _selectedAccountId!,
        frequency: _frequency,
        interval: 1,
        startDate: _startDate,
      );

      // 4. Si todo sale bien...
      if (mounted) {
        // Disparamos el evento para que la pantalla anterior se actualice
        EventService.instance.fire(AppEvent.recurringTransactionChanged);
        
        // Cerramos la pantalla
        Navigator.of(context).pop();

        // Mostramos la notificación de éxito en la pantalla anterior
        // Usamos un Future.delayed para asegurar que se muestre después de la transición
        Future.delayed(const Duration(milliseconds: 300), () {
            NotificationHelper.show(
              context: context,
              message: 'Gasto fijo creado correctamente.',
              type: NotificationType.success,
            );
        });
      }
    } catch (e) {
      // 5. Si algo falla...
      if (mounted) {
        NotificationHelper.show(
          context: context,
          message: 'Error al crear: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    } finally {
      // 6. En cualquier caso, detenemos el estado de carga
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}