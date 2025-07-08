import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // Usamos solo las categorías de gastos, ya que los presupuestos son para controlar gastos.
  final List<String> _expenseCategories = [
    'Comida', 'Transporte', 'Ocio', 'Salud', 'Hogar', 'Compras', 'Servicios'
  ];

  Future<void> _saveBudget() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      setState(() => _isLoading = true);
      
      final currentMonth = DateTime.now().month;
      final currentYear = DateTime.now().year;
      final amount = double.parse(_amountController.text.trim());
      final category = _selectedCategory!;
      final userId = Supabase.instance.client.auth.currentUser!.id;

      try {
        // Usamos 'upsert' para crear o actualizar un presupuesto existente para la misma categoría/mes.
        await Supabase.instance.client.from('budgets').upsert({
          'user_id': userId,
          'category': category,
          'month': currentMonth,
          'year': currentYear,
          'amount': amount,
        }, onConflict: 'user_id, category, month, year'); // Clave única que definimos en la tabla

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Presupuesto guardado!'), backgroundColor: Colors.green));
          Navigator.of(context).pop(); // Volver a la pantalla anterior
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el presupuesto: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo Presupuesto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selector de Categoría
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: 'Categoría de Gasto', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.category)),
                items: _expenseCategories.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (value) => (value == null) ? 'Debes seleccionar una categoría' : null,
              ),
              const SizedBox(height: 16),
              
              // Campo para el Monto Límite
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Monto Límite', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.dollar_circle)),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => (value == null || double.tryParse(value) == null || double.parse(value) <= 0) ? 'Introduce un monto válido' : null,
              ),
              const SizedBox(height: 32),

              // Botón de Guardar
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveBudget,
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Iconsax.save_2),
                label: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Guardar Presupuesto'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}