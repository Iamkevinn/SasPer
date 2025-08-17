// lib/screens/can_i_afford_it_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/simulation_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/simulation_models.dart';
import 'package:sasper/screens/simulation_result_screen.dart'; // La crearemos en el siguiente paso
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class CanIAffordItScreen extends StatefulWidget {
  const CanIAffordItScreen({super.key});

  @override
  State<CanIAffordItScreen> createState() => _CanIAffordItScreenState();
}

class _CanIAffordItScreenState extends State<CanIAffordItScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  final SimulationRepository _simulationRepo = SimulationRepository.instance;
  final CategoryRepository _categoryRepo = CategoryRepository.instance;

  Category? _selectedCategory;
  bool _isLoading = false;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepo.getExpenseCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      NotificationHelper.show(message: 'Por favor, completa todos los campos.', type: NotificationType.error);
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final categoryName = _selectedCategory!.name;
      
      // Llamamos a nuestro nuevo repositorio para obtener el análisis.
      final SimulationResult result = await _simulationRepo.getExpenseSimulation(
        amount: amount,
        categoryName: categoryName,
      );
      
      // Si la simulación es exitosa, navegamos a la pantalla de resultados.
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SimulationResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(message: e.toString().replaceFirst("Exception: ", ""), type: NotificationType.error);
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
        title: Text('¿Me lo puedo permitir?', style: GoogleFonts.poppins()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Simula un gasto para ver su impacto en tus finanzas',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                textStyle: Theme.of(context).textTheme.titleMedium,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Monto del Gasto',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.money_4),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa un monto';
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) return 'Ingresa un monto válido';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildCategorySelector(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _runSimulation,
              icon: _isLoading ? Container() : const Icon(Iconsax.calculator),
              label: _isLoading 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Text('Analizar Impacto'),
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

  // Este widget lo reutilizamos de `add_budget_screen.dart`.
  Widget _buildCategorySelector() {
    return FutureBuilder<List<Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text('No se pudieron cargar las categorías.');
        }

        final categories = snapshot.data!;
        return DropdownButtonFormField<Category>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Categoría',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Iconsax.category),
          ),
          hint: const Text('Selecciona una categoría de gasto'),
          items: categories.map((Category category) {
            return DropdownMenuItem<Category>(
              value: category,
              child: Row(
                children: [
                  Icon(category.icon, color: category.colorAsObject, size: 20),
                  const SizedBox(width: 12),
                  Text(category.name),
                ],
              ),
            );
          }).toList(),
          onChanged: (newValue) {
            setState(() => _selectedCategory = newValue);
          },
          validator: (value) => value == null ? 'Selecciona una categoría' : null,
        );
      },
    );
  }
}