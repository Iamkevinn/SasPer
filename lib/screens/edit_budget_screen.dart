// lib/screens/edit_budget_screen.dart (VERSIÓN COMPATIBLE CON PRESUPUESTOS FLEXIBLES)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart'; // ¡Importa el nuevo modelo!
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

// Para el selector de periodicidad
enum Periodicity { weekly, monthly, custom }

class EditBudgetScreen extends StatefulWidget {
  // --- ¡CORRECCIÓN! Acepta el nuevo modelo `Budget` ---
  final Budget budget;

  const EditBudgetScreen({
    super.key,
    required this.budget,
  });

  @override
  State<EditBudgetScreen> createState() => _EditBudgetScreenState();
}

class _EditBudgetScreenState extends State<EditBudgetScreen> {
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final _formKey = GlobalKey<FormState>();
  
  // Controladores y estado de la UI
  late final TextEditingController _amountController;
  late Periodicity _selectedPeriodicity;
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-poblamos el formulario con los datos del presupuesto a editar.
    _amountController = TextEditingController(text: widget.budget.amount.toStringAsFixed(0));
    _startDate = widget.budget.startDate;
    _endDate = widget.budget.endDate;
    
    // Convertimos el string de periodicidad a nuestro Enum.
    _selectedPeriodicity = Periodicity.values.firstWhere(
      (e) => e.name == widget.budget.periodicity,
      orElse: () => Periodicity.custom, // Si no coincide, es personalizado.
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
  
  // --- LÓGICA DE UI (idéntica a AddBudgetScreen) ---

  void _updatePeriodicity(Periodicity period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriodicity = period;
      switch (period) {
        case Periodicity.weekly:
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate = now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
          break;
        case Periodicity.monthly:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate = DateTime(now.year, now.month + 1, 0);
          break;
        case Periodicity.custom:
          // Mantenemos las fechas que ya tenía el presupuesto
          _startDate = widget.budget.startDate;
          _endDate = widget.budget.endDate;
          break;
      }
    });
  }

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
          if (_endDate.isBefore(_startDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // --- ¡CORRECCIÓN! Lógica de actualización ---
  Future<void> _updateBudget() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Usamos el método `updateBudget` del repositorio con todos los parámetros.
      await _budgetRepository.updateBudget(
        budgetId: widget.budget.id,
        categoryName: widget.budget.category, 
        amount: double.parse(_amountController.text.replaceAll(',', '.')),
        startDate: _startDate,
        endDate: _endDate,
        periodicity: _selectedPeriodicity.name,
      );

      if (mounted) {
        EventService.instance.fire(AppEvent.budgetsChanged);
        Navigator.of(context).pop(true);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(message: 'Presupuesto actualizado.', type: NotificationType.success);
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR PRESUPUESTO: $e', name: 'EditBudgetScreen');
      if (mounted) {
        NotificationHelper.show(message: 'Error al actualizar.', type: NotificationType.error);
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
            // Mostramos la categoría como texto no editable.
            TextFormField(
              initialValue: widget.budget.category,
              enabled: false,
              decoration: InputDecoration(
                labelText: 'Categoría',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.category),
              ),
            ),
            const SizedBox(height: 24),
            _buildPeriodicitySelector(),
            const SizedBox(height: 24),
            if (_selectedPeriodicity == Periodicity.custom) ...[
              _buildCustomDateSelectors(),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Monto del Presupuesto',
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateBudget,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              child: _isLoading 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text('Actualizar Presupuesto'),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES (reutilizados de AddBudgetScreen) ---

  Widget _buildPeriodicitySelector() {
    // ... (código idéntico a AddBudgetScreen)
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
            _updatePeriodicity(newSelection.first);
          },
        ),
      ],
    );
  }

  Widget _buildCustomDateSelectors() {
    // ... (código idéntico a AddBudgetScreen)
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
}