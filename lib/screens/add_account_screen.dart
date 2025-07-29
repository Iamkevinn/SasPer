// lib/screens/add_account_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class AddAccountScreen extends StatefulWidget {
  // El constructor es constante y no recibe parámetros.
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final AccountRepository _accountRepository = AccountRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  String _selectedType = 'Efectivo';
  bool _isLoading = false;

  final Map<String, IconData> _accountTypes = {
    'Efectivo': Iconsax.money_3,
    'Cuenta Bancaria': Iconsax.building_4,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros': Iconsax.safe_home,
    'Inversión': Iconsax.chart_1,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  /// Valida el formulario y llama al repositorio para guardar la nueva cuenta.
  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final initialBalance = double.tryParse(_balanceController.text.trim().replaceAll(',', '.')) ?? 0.0;

      // Usamos la instancia Singleton para llamar al método.
      await _accountRepository.addAccount(
        name: _nameController.text.trim(),
        type: _selectedType,
        initialBalance: initialBalance,
      );

      if (mounted) {
        // Disparamos el evento global para que otras pantallas se actualicen.
        EventService.instance.fire(AppEvent.accountCreated);

        // Devolvemos 'true' para que la pantalla anterior sepa que la operación fue exitosa.
        Navigator.of(context).pop(true);

        // Mostramos la notificación después de que la pantalla se cierre.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Cuenta creada exitosamente!',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR CUENTA: $e', name: 'AddAccountScreen');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al crear la cuenta.',
            type: NotificationType.error,
          );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nueva Cuenta', style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nombre de la cuenta',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.text),
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Tipo de cuenta',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.category),
                ),
                items: _accountTypes.entries.map((entry) {
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
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedType = value);
                  }
                },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _balanceController,
                decoration: InputDecoration(
                  labelText: 'Saldo inicial',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Iconsax.dollar_circle),
                  hintText: '0.00'
                ),
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                validator: (value) {
                   if (value == null || value.isEmpty) return 'El saldo es obligatorio';
                   if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Introduce un saldo válido';
                   return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveAccount,
                icon: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Iconsax.save_2),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar Cuenta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}