// lib/screens/edit_goal_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class EditGoalScreen extends StatefulWidget {
  final GoalRepository goalRepository;
  final Goal goal;

  const EditGoalScreen({
    super.key,
    required this.goalRepository,
    required this.goal,
  });

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
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
      initialDate: _targetDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _targetDate) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _updateGoal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final updatedGoal = widget.goal.copyWith(
        name: _nameController.text.trim(),
        targetAmount: double.parse(_targetAmountController.text),
        targetDate: _targetDate,
      );
      
      await widget.goalRepository.updateGoal(updatedGoal);

      if (mounted) {
        Navigator.of(context).pop(true);
        NotificationHelper.show(
          context: context,
          message: 'Meta actualizada correctamente.',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          context: context,
          message: 'Error al actualizar: ${e.toString()}',
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
              decoration: const InputDecoration(labelText: 'Nombre de la Meta', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.flag)),
              validator: (value) => value!.trim().isEmpty ? 'El nombre es obligatorio' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _targetAmountController,
              decoration: const InputDecoration(labelText: 'Monto Objetivo', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.dollar_circle)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Introduce una cantidad';
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) return 'Introduce un número válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
             ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                leading: const Icon(Iconsax.calendar_1),
                title: Text(_targetDate == null ? 'Fecha Límite (Opcional)' : 'Vence: ${DateFormat.yMMMd('es_CO').format(_targetDate!)}'),
                trailing: _targetDate != null ? IconButton(icon: const Icon(Iconsax.close_circle, size: 20), onPressed: () => setState(() => _targetDate = null)) : null,
                onTap: () => _selectDate(),
              ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateGoal,
              icon: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Iconsax.edit),
              label: const Text('Actualizar Meta'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                ),
            ),
          ],
        ),
      ),
    );
  }
}