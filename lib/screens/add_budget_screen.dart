// lib/screens/add_budget_screen.dart (CORREGIDO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/budget_repository.dart';

class AddBudgetScreen extends StatefulWidget {
  final BudgetRepository budgetRepository;
  const AddBudgetScreen({super.key, required this.budgetRepository});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  bool _isLoading = false;

  final _categories = ['Comida', 'Transporte', 'Ocio', 'Hogar', 'Compras', 'Servicios', 'Salud', 'Otro'];

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      await widget.budgetRepository.addBudget(
        category: _selectedCategory!,
        amount: double.parse(_amountController.text),
        month: DateTime.now().month,
        year: DateTime.now().year,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Presupuesto creado con éxito')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
            // ... Aquí irían tus TextFormField y DropdownButtonFormField ...
            // Por ejemplo:
            DropdownButtonFormField<String>(
              value: _selectedCategory,
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
              decoration: const InputDecoration(labelText: 'Monto del presupuesto'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
                  return 'Por favor ingresa un monto válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveBudget,
              child: _isLoading ? const CircularProgressIndicator() : const Text('Guardar Presupuesto'),
            ),
          ],
        ),
      ),
    );
  }
}