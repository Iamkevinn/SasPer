// lib/screens/add_budget_screen.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

// Importamos la configuración y el nuevo repositorio
import '../config/app_constants.dart';
import '../data/budget_repository.dart';

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  // Dependencia: Instanciamos el repositorio
  final _budgetRepository = BudgetRepository();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      
      // ¡AQUÍ ESTÁ EL CAMBIO!
      // Delegamos toda la lógica de guardado al repositorio.
      await _budgetRepository.saveBudget(
        category: _selectedCategory!,
        amount: amount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Presupuesto guardado!'), backgroundColor: Colors.green),
        );
        // Devolvemos true para que la pantalla anterior sepa que la operación fue exitosa.
        // Esto es útil si la pantalla anterior no usa streams en tiempo real.
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El método build ya estaba muy bien, no necesita cambios de lógica,
    // solo asegurarse de que el import de `app_constants` sea correcto.
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo o Editar Presupuesto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Categoría de Gasto',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.category),
                ),
                items: AppConstants.expenseCategories.entries.map((entry) {
                  return DropdownMenuItem(
                    value: entry.key,
                    child: Row(
                      children: [
                        Icon(entry.value, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 12),
                        Text(entry.key),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) => value == null ? 'Debes seleccionar una categoría' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Monto Límite',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.dollar_circle),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce un monto';
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) return 'El monto debe ser un número positivo';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveBudget,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Iconsax.save_2),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar Presupuesto'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}