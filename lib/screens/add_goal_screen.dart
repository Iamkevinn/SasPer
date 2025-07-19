// lib/screens/add_goal_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Para consistencia de UI
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import '../data/goal_repository.dart';

class AddGoalScreen extends StatefulWidget {
  // --- ¡CAMBIO CLAVE! ---
  // Ahora requiere el repositorio en su constructor.
  final GoalRepository goalRepository;

  const AddGoalScreen({super.key, required this.goalRepository});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  DateTime? _targetDate;
  bool _isLoading = false;

  // Se elimina la instancia local: `final _goalRepository = GoalRepository();`

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _targetDate) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _saveGoal() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // --- ¡CAMBIO CLAVE! ---
      // Usamos el repositorio que viene del widget.
      await widget.goalRepository.addGoal(
        name: _nameController.text.trim(),
        targetAmount: double.parse(_targetAmountController.text.trim()),
        targetDate: _targetDate,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Meta creada con éxito!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
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
              // El resto del build es visualmente idéntico, está muy bien hecho.
              // Solo se ajustan las fuentes para consistencia.
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la Meta',
                  hintText: 'Ej. Vacaciones, Portátil Nuevo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.flag),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Por favor, introduce un nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAmountController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad Objetivo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.dollar_circle),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce una cantidad';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return 'Introduce un número válido mayor que cero';
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
                title: Text(_targetDate == null ? 'Fecha Límite (Opcional)' : 'Vence: ${DateFormat.yMMMd('es_MX').format(_targetDate!)}'),
                trailing: _targetDate != null ? IconButton(icon: const Icon(Iconsax.close_circle, size: 20), onPressed: () => setState(() => _targetDate = null)) : null,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}