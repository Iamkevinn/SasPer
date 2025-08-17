// lib/screens/add_budget_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/category_repository.dart'; // ¡NUEVA IMPORTACIÓN!
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/category_model.dart'; // ¡NUEVA IMPORTACIÓN!
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

// Para el selector de periodicidad
enum Periodicity { weekly, monthly, custom }

class AddBudgetScreen extends StatefulWidget {
  // Opcional: recibe un presupuesto para entrar en modo "Edición"
  //final Budget? budgetToEdit; 
  
  const AddBudgetScreen({super.key}); // const AddBudgetScreen({super.key, this.budgetToEdit});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance; // Para cargar categorías

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  
  // --- NUEVOS ESTADOS PARA LA UI ---
  Category? _selectedCategory;
  Periodicity _selectedPeriodicity = Periodicity.monthly;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  bool _isLoading = false;
  
  // La lista de categorías ahora se carga de forma asíncrona
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    // Cargamos las categorías de gastos una sola vez.
    _categoriesFuture = _categoryRepository.getExpenseCategories();
    // Configuramos las fechas iniciales para el modo mensual por defecto.
    _calculateDatesForPeriodicity(Periodicity.monthly);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  /// Calcula y actualiza las fechas de inicio y fin según la periodicidad seleccionada.
  void _calculateDatesForPeriodicity(Periodicity period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriodicity = period;
      switch (period) {
        case Periodicity.weekly:
          // Lunes de la semana actual
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          // Domingo de la semana actual
          _endDate = now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
          break;
        case Periodicity.monthly:
          // Primer día del mes actual
          _startDate = DateTime(now.year, now.month, 1);
          // Último día del mes actual
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case Periodicity.custom:
          // No hacemos nada, el usuario las elegirá manualmente
          break;
      }
    });
  }

  /// Muestra un selector de fecha y actualiza el estado.
  Future<void> _selectDate(BuildContext context, {required bool isStartDate}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          // Si la fecha de fin es anterior a la nueva de inicio, la ajustamos.
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  /// Valida y guarda el presupuesto.
  Future<void> _saveBudget() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      NotificationHelper.show(message: 'Por favor, completa todos los campos.', type: NotificationType.error);
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Usamos el método actualizado del repositorio.
      await _budgetRepository.addBudget(
        categoryName: _selectedCategory!.name,
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        startDate: _startDate,
        endDate: _endDate,
        periodicity: _selectedPeriodicity.name, // 'weekly', 'monthly', 'custom'
      );
      
      if (mounted) {
        EventService.instance.fire(AppEvent.budgetsChanged);
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(message: 'Presupuesto creado correctamente.', type: NotificationType.success);
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR PRESUPUESTO: $e', name: 'AddBudgetScreen');
      if (mounted) {
        NotificationHelper.show(message: 'Error al crear presupuesto.', type: NotificationType.error);
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
            // --- NUEVO: Selector de periodicidad ---
            _buildPeriodicitySelector(),
            const SizedBox(height: 24),
            
            // --- NUEVO: Selectores de fecha para modo personalizado ---
            if (_selectedPeriodicity == Periodicity.custom) ...[
              _buildCustomDateSelectors(),
              const SizedBox(height: 16),
            ],

            // Dropdown de categorías ahora es asíncrono
            _buildCategorySelector(),
            const SizedBox(height: 16),

            // Campo de monto (sin cambios mayores)
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Monto del presupuesto',
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
            const SizedBox(height: 32),
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

  // --- WIDGETS AUXILIARES PARA MANTENER EL CÓDIGO LIMPIO ---

  Widget _buildPeriodicitySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Duración del Presupuesto', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<Periodicity>(
          segments: const [
            ButtonSegment(value: Periodicity.weekly, label: Text('Semanal'), icon: Icon(Iconsax.calendar_1, size: 18)),
            ButtonSegment(value: Periodicity.monthly, label: Text('Mensual'), icon: Icon(Iconsax.calendar, size: 18)),
            ButtonSegment(value: Periodicity.custom, label: Text('Otro'), icon: Icon(Iconsax.setting_4, size: 18)),
          ],
          selected: {_selectedPeriodicity},
          onSelectionChanged: (newSelection) {
            _calculateDatesForPeriodicity(newSelection.first);
          },
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomDateSelectors() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context, isStartDate: true),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Desde',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.calendar_add),
              ),
              child: Text(DateFormat.yMd('es_CO').format(_startDate)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context, isStartDate: false),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Hasta',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.calendar_remove),
              ),
              child: Text(DateFormat.yMd('es_CO').format(_endDate)),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCategorySelector() {
    return FutureBuilder<List<Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
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
          hint: const Text('Selecciona una categoría'),
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