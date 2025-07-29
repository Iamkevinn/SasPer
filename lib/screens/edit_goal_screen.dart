// lib/screens/edit_goal_screen.dart (VERSIÓN FINAL CON SINGLETON)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class EditGoalScreen extends StatefulWidget {
  // Solo necesita recibir el objeto de la meta a editar.
  final Goal goal;

  const EditGoalScreen({
    super.key,
    required this.goal,
  });

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final GoalRepository _goalRepository = GoalRepository.instance;
  
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;
  DateTime? _targetDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.goal.name);
    _targetAmountController = TextEditingController(text: widget.goal.targetAmount.toStringAsFixed(0));
    _targetDate = widget.goal.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
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

  Future<void> _updateGoal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Usamos el método `copyWith` del modelo para crear una copia actualizada.
      final updatedGoal = widget.goal.copyWith(
        name: _nameController.text.trim(),
        targetAmount: double.parse(_targetAmountController.text.replaceAll(',', '.')),
        targetDate: _targetDate,
      );
      
      await _goalRepository.updateGoal(updatedGoal);

      if (mounted) {
        // Disparamos el evento global para el Dashboard, etc.
        EventService.instance.fire(AppEvent.goalUpdated);
        
        // Devolvemos 'true' para el refresco inmediato de la pantalla de lista.
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Meta actualizada correctamente.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR META: $e', name: 'EditGoalScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al actualizar: ${e.toString().replaceFirst("Exception: ", "")}',
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
        title: Text('Editar Meta', style: GoogleFonts.poppins()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre de la Meta',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.flag),
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'El nombre es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetAmountController,
              decoration: InputDecoration(
                labelText: 'Monto Objetivo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.dollar_circle),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Introduce una cantidad';
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) return 'Introduce un número válido';
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
                onTap: () => _selectDate(),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateGoal,
              icon: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.edit),
              label: const Text('Actualizar Meta'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
            ),
          ],
        ),
      ),
    );
  }
}