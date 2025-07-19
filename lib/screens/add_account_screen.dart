// lib/screens/add_account_screen.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
// import 'package:sasper/services/event_service.dart'; // Ya no es necesario si la otra pantalla usa streams
import '../data/account_repository.dart'; // Importamos el repositorio

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  
  // Estado
  String _selectedType = 'Efectivo';
  bool _isLoading = false;

  // Dependencia
  final _accountRepository = AccountRepository();

  // 1. MEJORA: Asociamos tipos con iconos para un Dropdown más visual
  final Map<String, IconData> _accountTypes = {
    'Efectivo': Iconsax.money,
    'Cuenta Bancaria': Iconsax.building,
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

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final initialBalance = double.tryParse(_balanceController.text.trim()) ?? 0.0;
      
      // 2. LLAMAMOS AL REPOSITORIO para encapsular la lógica de datos
      await _accountRepository.addAccount(
        name: _nameController.text.trim(),
        type: _selectedType,
        initialBalance: initialBalance,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Cuenta creada con éxito!'), backgroundColor: Colors.green),
        );
        // 3. Devolvemos 'true' para que la pantalla anterior sepa que hubo un cambio
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la cuenta: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
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
        title: const Text('Nueva Cuenta'),
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
                decoration: const InputDecoration(
                  labelText: 'Nombre de la cuenta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.text),
                ),
                validator: (value) => (value == null || value.isEmpty) ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Tipo de cuenta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.category),
                ),
                // 4. El Dropdown ahora muestra iconos junto al texto
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Iconsax.dollar_circle),
                ),
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                validator: (value) {
                   if (value == null || value.isEmpty) return 'El saldo es obligatorio';
                   if (double.tryParse(value) == null) return 'Introduce un saldo válido';
                   return null;
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveAccount,
                icon: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                    : const Icon(Iconsax.save_2),
                label: Text(_isLoading ? 'Guardando...' : 'Guardar Cuenta'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}