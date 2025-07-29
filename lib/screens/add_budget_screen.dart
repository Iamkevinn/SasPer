// lib/screens/add_budget_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class AddBudgetScreen extends StatefulWidget {
  // El constructor es constante y no recibe parámetros.
  const AddBudgetScreen({super.key});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final BudgetRepository _budgetRepository = BudgetRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  // Lista de categorías disponibles para presupuestar.
  final _categories = ['Comida', 'Transporte', 'Ocio', 'Hogar', 'Compras', 'Servicios', 'Salud', 'Otro'];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Valida el formulario y llama al repositorio para guardar el nuevo presupuesto.
  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
       NotificationHelper.show(
            message: 'Por favor, completa todos los campos.',
            type: NotificationType.error,
          );
      return;
    }
    setState(() => _isLoading = true);

    try {
      await _budgetRepository.addBudget(
        category: _selectedCategory!,
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
      if (mounted) {
        // Disparamos el evento global para que otras pantallas se actualicen.
        EventService.instance.fire(AppEvent.budgetsChanged);

        // Devolvemos 'true' para que la pantalla anterior sepa que la operación fue exitosa.
        Navigator.of(context).pop(true);
        
        // Mostramos la notificación después de que la pantalla se cierre.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Presupuesto creado correctamente.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR PRESUPUESTO: $e', name: 'AddBudgetScreen');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al crear presupuesto: ${e.toString().replaceFirst("Exception: ", "")}',
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
        title: Text('Nuevo Presupuesto', style: GoogleFonts.poppins()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.category),
              ),
              hint: const Text('Selecciona una categoría'),
              items: _categories.map((String category) {
                return DropdownMenuItem<String>(value: category, child: Text(category));
              }).toList(),
              onChanged: (newValue) {
                setState(() => _selectedCategory = newValue);
              },
              validator: (value) => value == null ? 'Por favor selecciona una categoría' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Monto del presupuesto',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.money_4),
                prefixText: '\$ '
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Por favor ingresa un monto';
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Por favor ingresa un monto válido y mayor a cero';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveBudget,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Guardar Presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}