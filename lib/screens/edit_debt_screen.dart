// lib/screens/edit_debt_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class EditDebtScreen extends StatefulWidget {
  final Debt debt;

  const EditDebtScreen({super.key, required this.debt});

  @override
  State<EditDebtScreen> createState() => _EditDebtScreenState();
}

class _EditDebtScreenState extends State<EditDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _entityController;

  final DebtRepository _debtRepository = DebtRepository.instance;

  DateTime? _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-poblamos los campos con los datos de la deuda existente.
    _nameController = TextEditingController(text: widget.debt.name);
    _entityController = TextEditingController(text: widget.debt.entityName);
    _dueDate = widget.debt.dueDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _entityController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Usamos el método `updateDebt` del repositorio.
      await _debtRepository.updateDebt(
        debtId: widget.debt.id,
        name: _nameController.text.trim(),
        entityName: _entityController.text.trim().isNotEmpty ? _entityController.text.trim() : null,
        dueDate: _dueDate,
      );

      if (!mounted) return;

      NotificationHelper.show(
        message: 'Deuda actualizada con éxito!',
        type: NotificationType.success,
      );
      Navigator.of(context).pop();

    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
        message: 'Error al actualizar: ${e.toString().replaceFirst("Exception: ", "")}',
        type: NotificationType.error,
      );
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
        title: Text('Editar Información', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // No permitimos cambiar el tipo ni el monto, ya que están ligados
              // a una transacción inicial que no debe ser alterada.
              _buildInfoCard(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Concepto', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.note_1)),
                validator: (value) => (value == null || value.isEmpty) ? 'El concepto es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _entityController,
                decoration: const InputDecoration(labelText: 'Persona o Entidad (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.user)),
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Theme.of(context).colorScheme.outline)),
                leading: const Icon(Iconsax.calendar_1),
                title: Text(_dueDate == null ? 'Fecha de Vencimiento (Opcional)' : 'Vence: ${DateFormat.yMMMd('es_CO').format(_dueDate!)}'),
                trailing: const Icon(Iconsax.arrow_right_3),
                onTap: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: _dueDate ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (pickedDate != null) setState(() => _dueDate = pickedDate);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Iconsax.save_2),
                  label: Text(_isLoading ? 'Guardando...' : 'Guardar Cambios'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Monto Original', style: GoogleFonts.poppins()),
                Text(
                  NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(widget.debt.initialAmount),
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tipo de Operación', style: GoogleFonts.poppins()),
                Text(
                  widget.debt.type == DebtType.debt ? 'Deuda' : 'Préstamo',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ],
        )
      ),
    );
  }
}