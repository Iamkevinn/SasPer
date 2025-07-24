// lib/screens/edit_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart'; // Importamos el modelo
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class EditBudgetScreen extends StatefulWidget {
  final BudgetRepository budgetRepository;
  final BudgetProgress budget; // Recibimos el presupuesto a editar

  const EditBudgetScreen({
    super.key,
    required this.budgetRepository,
    required this.budget,
  });

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late String _selectedCategory; // La categoría no podrá cambiarse
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-cargamos los datos del presupuesto existente
    _selectedCategory = widget.budget.category;
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
      // Usamos el método `updateBudget` que añadiremos al repositorio
      await widget.budgetRepository.updateBudget(
        budgetId: widget.budget.budgetId,
        newAmount: double.parse(_amountController.text),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Cerramos la pantalla de edición
        NotificationHelper.show(
          context: context,
          message: 'Presupuesto actualizado correctamente.',
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
        title: Text('Editar Presupuesto', style: GoogleFonts.poppins()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Mostramos la categoría como texto no editable
            Text(
              'Categoría',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedCategory,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Nuevo Monto'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                  return 'Por favor ingresa un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateBudget,
              child: _isLoading ? const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.white)) : const Text('Actualizar Presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}