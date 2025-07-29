// lib/screens/add_goal_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class AddGoalScreen extends StatefulWidget {
  // El constructor es constante y no recibe parámetros.
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final GoalRepository _goalRepository = GoalRepository.instance;
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime? _targetDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  /// Muestra el selector de fecha.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2101),
      locale: const Locale('es'),
    );
    if (picked != null && picked != _targetDate) {
      setState(() => _targetDate = picked);
    }
  }

  /// Valida el formulario y llama al repositorio para guardar la nueva meta.
  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _goalRepository.addGoal(
        name: _nameController.text.trim(),
        targetAmount: double.parse(_targetAmountController.text.trim().replaceAll(',', '.')),
        targetDate: _targetDate,
      );

      if (mounted) {
        // Disparamos el evento global para que otras pantallas se actualicen.
        EventService.instance.fire(AppEvent.goalCreated);

        // Devolvemos 'true' para que la pantalla anterior sepa que la operación fue exitosa.
        Navigator.of(context).pop(true);

        // Mostramos la notificación después de que la pantalla se cierre.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Meta creada con éxito!',
            type: NotificationType.success,
          );
        });
      }
    } catch (error) {
      developer.log('🔥 FALLO AL CREAR META: $error', name: 'AddGoalScreen');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al crear la meta.',
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
        title: Text('Crear Nueva Meta', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la Meta',
                  hintText: 'Ej. Vacaciones, Portátil Nuevo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.flag),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Por favor, introduce un nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: InputDecoration(
                  labelText: 'Cantidad Objetivo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.dollar_circle),
                  prefixText: '\$ '
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce una cantidad';
                  final amount = double.tryParse(value.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return 'Introduce un número válido mayor que cero';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Iconsax.calendar_1),
                title: Text(_targetDate == null ? 'Fecha Límite (Opcional)' : 'Vence: ${DateFormat.yMMMd('es_CO').format(_targetDate!)}'),
                trailing: _targetDate != null ? IconButton(icon: const Icon(Iconsax.close_circle, size: 20), onPressed: () => setState(() => _targetDate = null)) : const Icon(Iconsax.arrow_right_3),
                onTap: () => _selectDate(context),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveGoal,
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.save_2),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar Meta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}