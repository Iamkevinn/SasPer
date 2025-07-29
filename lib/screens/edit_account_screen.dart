// lib/screens/edit_account_screen.dart (VERSIÓN FINAL COMPLETA USANDO SINGLETON)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

class EditAccountScreen extends StatefulWidget {
  final Account account;

  // El AccountRepository ya no se pasa como parámetro en el constructor.
  const EditAccountScreen({
    super.key,
    required this.account,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final AccountRepository _accountRepository = AccountRepository.instance;
  
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedType;
  bool _isLoading = false;

  final Map<String, IconData> _accountTypes = {
    'Efectivo': Iconsax.money_3,
    'Cuenta Bancaria': Iconsax.building_4,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros': Iconsax.safe_home,
    'Inversión': Iconsax.chart_1,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.account.name);
    _selectedType = widget.account.type;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      // Usamos el método `copyWith` del modelo para crear una copia actualizada.
      final updatedAccount = widget.account.copyWith(
        name: _nameController.text.trim(),
        type: _selectedType, // Permitimos cambiar el tipo también
      );
      
      // Usamos la instancia _accountRepository para llamar al método.
      await _accountRepository.updateAccount(updatedAccount);

      if (mounted) {
        // Disparamos el evento global para que el Dashboard, etc., se actualicen.
        EventService.instance.fire(AppEvent.accountUpdated);

        // Devolvemos 'true' para el refresco inmediato de la pantalla de lista de cuentas.
        Navigator.of(context).pop(true);
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Cuenta actualizada correctamente.',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL ACTUALIZAR CUENTA: $e', name: 'EditAccountScreen');
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
        title: Text('Editar Cuenta', style: GoogleFonts.poppins()),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre de la cuenta',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.text),
              ),
              validator: (value) => (value == null || value.trim().isEmpty) ? 'El nombre no puede estar vacío' : null,
            ),
            const SizedBox(height: 20),
            // Ahora permitimos editar el tipo de cuenta, ya que el repositorio lo soporta.
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
              // Usamos el saldo de la cuenta que nos pasaron para mostrarlo.
              initialValue: 'Saldo actual: \$${widget.account.balance.toStringAsFixed(0)}',
              enabled: false,
              style: Theme.of(context).textTheme.bodyMedium,
              decoration: InputDecoration(
                labelText: 'El saldo solo se puede ajustar creando transacciones.',
                labelStyle: Theme.of(context).textTheme.bodySmall,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.dollar_circle),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateAccount,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Iconsax.edit),
              label: const Text('Guardar Cambios'),
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
}