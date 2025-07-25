// lib/screens/edit_account_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class EditAccountScreen extends StatefulWidget {
  final AccountRepository accountRepository;
  final Account account;

  const EditAccountScreen({
    super.key,
    required this.accountRepository,
    required this.account,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isLoading = false;
  // Mantenemos el tipo para mostrarlo, pero no será editable
  late String _selectedType;

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
      // Usamos el método `copyWith` de tu modelo para crear una copia actualizada
      final updatedAccount = widget.account.copyWith(name: _nameController.text.trim());
      
      await widget.accountRepository.updateAccount(updatedAccount);

      if (mounted) {
        // Pasamos `true` al cerrar para indicar que hubo cambios
        Navigator.of(context).pop(true); 
        NotificationHelper.show(
          context: context,
          message: 'Cuenta actualizada correctamente.',
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre no puede estar vacío';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // Mostramos el tipo de cuenta como no editable, ya que cambiarlo podría afectar la lógica
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: InputDecoration(
                labelText: 'Tipo de cuenta',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.category),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainer,
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
              onChanged: null, // Deshabilitado
            ),
            const SizedBox(height: 20),
            // Mostramos el saldo como información no editable
            TextFormField(
              initialValue: 'No se puede editar el saldo. Realiza una transacción para ajustarlo.',
              enabled: false,
              style: Theme.of(context).textTheme.bodySmall,
              decoration: InputDecoration(
                labelText: 'Saldo Actual: \$${widget.account.balance.toStringAsFixed(0)}',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Iconsax.dollar_circle),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _updateAccount,
              icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                : const Icon(Iconsax.edit),
              label: const Text('Actualizar Nombre'),
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