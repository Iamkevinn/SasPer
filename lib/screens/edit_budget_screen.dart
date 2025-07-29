// lib/screens/edit_budget_screen.dart (VERSIÓN FINAL COMPLETA USANDO SINGLETON)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class EditBudgetScreen extends StatefulWidget {
  // Solo necesita recibir el objeto del presupuesto a editar.
  final BudgetProgress budget;

  const EditBudgetScreen({
    super.key,
    required this.budget,
  });

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final BudgetRepository _budgetRepository = BudgetRepository.instance;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late String _category;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _category = widget.budget.category;
    _amountController = TextEditingController(text: widget.budget.budgetAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _updateBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      await _budgetRepository.updateBudget(
        budgetId: widget.budget.budgetId, // Corregido: 'id' en lugar de 'budgetId'
        newAmount: double.parse(_amountController.text.replaceAll(',', '.')),
      );

      if (mounted) {
        // Disparamos el evento global para que el Dashboard, etc., se actualicen.
        EventService.instance.fire(AppEvent.budgetsChanged);

        // Devolvemos 'true' para el refresco inmediato de la pantalla de lista.
        Navigator.of(context).pop(true);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Presupuesto actualizado correctamente.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR PRESUPUESTO: $e', name: 'EditBudgetScreen');
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
        title: Text('Editar Presupuesto', style: GoogleFonts.poppins()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Mostramos la categoría como texto no editable
            TextFormField(
              initialValue: _category,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.category),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Nuevo Monto del Presupuesto',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.money_4),
                prefixText: '\$ ',
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
              onPressed: _isLoading ? null : _updateBudget,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Actualizar Presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}