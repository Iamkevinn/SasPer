// lib/screens/edit_transaction_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Importamos los modelos que hemos creado
import '../models/account_model.dart';
import '../models/transaction_models.dart';
import '../services/event_service.dart'; // Para notificar cambios

class EditTransactionScreen extends StatefulWidget {
  // 1. AHORA RECIBE UN OBJETO 'Transaction'
  final Transaction transaction;

  const EditTransactionScreen({super.key, required this.transaction});

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late String _transactionType;
  String? _selectedCategory;
  String? _selectedAccountId;
  bool _isLoading = false;

  late Future<List<Account>> _accountsFuture;
  final supabase = Supabase.instance.client;

  // Los mapas de categorías se mantienen, están perfectos
  final Map<String, IconData> _expenseCategories = {
    'Comida': Iconsax.cup,
    'Transporte': Iconsax.bus,
    'Ocio': Iconsax.gameboy,
    'Salud': Iconsax.health,
    'Hogar': Iconsax.home,
    'Compras': Iconsax.shopping_bag,
    'Servicios': Iconsax.flash_1,
    'Otro': Iconsax.category
  };
  final Map<String, IconData> _incomeCategories = {
    'Sueldo': Iconsax.money_recive,
    'Inversión': Iconsax.chart,
    'Freelance': Iconsax.briefcase,
    'Regalo': Iconsax.gift,
    'Otro': Iconsax.category_2
  };
  Map<String, IconData> get _currentCategories =>
      _transactionType == 'Gasto' || _transactionType == 'expense'
          ? _expenseCategories
          : _incomeCategories;

  @override
  void initState() {
    super.initState();
    // 2. INICIALIZAMOS EL ESTADO DESDE EL OBJETO 'widget.transaction'
    _amountController =
        TextEditingController(text: widget.transaction.amount.toString());
    _descriptionController =
        TextEditingController(text: widget.transaction.description ?? '');
    _transactionType = widget.transaction.type;
    _selectedCategory = widget.transaction.category;
    _selectedAccountId = widget.transaction.accountId;

    // 3. EL FUTURE AHORA DEVUELVE UNA LISTA DE OBJETOS 'Account'
    _accountsFuture = supabase
        .from('accounts')
        .select() // select * para tener todos los datos para el fromMap
        .eq('user_id', supabase.auth.currentUser!.id)
        .then((data) {
      // Parseamos la respuesta JSON en una lista de objetos Account
      return data.map<Account>((item) => Account.fromMap(item)).toList();
    });
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecciona una categoría y una cuenta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase
          .from('transactions')
          .update({
            'amount': double.parse(_amountController.text),
            'description': _descriptionController.text.trim(),
            'type': _transactionType,
            'category': _selectedCategory,
            'account_id': _selectedAccountId,
            // No actualizamos la fecha, la mantenemos como la original
          })
          // 4. USAMOS EL ID DEL OBJETO PARA LA CLÁUSULA 'eq'
          .eq('id', int.parse(widget.transaction.id));

      if (!mounted) return;

      EventService.instance.fire(AppEvent.transactionUpdated); // Notificamos el cambio
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Transacción actualizada!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteTransaction() async {
    // 5. USAMOS EL OBJETO PARA COMPROBAR SI LA TRANSACCIÓN ESTÁ VINCULADA
    if (widget.transaction.debtId != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          title: const Text('Acción no permitida'),
          content: Text(
            "Esta transacción está vinculada a una deuda o préstamo ('${widget.transaction.description}').\n\nPara gestionarla, ve a la sección de Deudas.",
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor:
              Theme.of(context).colorScheme.surface.withOpacity(0.85),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.0)),
          title: const Text('Confirmar eliminación'),
          content:
              const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (shouldDelete == true) {
      setState(() => _isLoading = true);
      try {
        await supabase
            .from('transactions')
            .delete()
            .eq('id', int.parse(widget.transaction.id));

        if (!mounted) return;

        EventService.instance.fire(AppEvent.transactionDeleted);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transacción eliminada'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.of(context).pop(true); // Cierra la pantalla de edición
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Transacción'),
        actions: [
          IconButton(
            icon: Icon(Iconsax.trash,
                color: Theme.of(context).colorScheme.error),
            onPressed: _isLoading ? null : _deleteTransaction,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Monto',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v == null ||
                        v.isEmpty ||
                        double.tryParse(v) == null
                    ? 'Ingresa un monto válido'
                    : null,
              ),
              const SizedBox(height: 24),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'Gasto',
                      label: Text('Gasto'),
                      icon: Icon(Iconsax.arrow_down_2)),
                  ButtonSegment(
                      value: 'Ingreso',
                      label: Text('Ingreso'),
                      icon: Icon(Iconsax.arrow_up_1)),
                ],
                selected: {_transactionType},
                onSelectionChanged: (selection) {
                  if (selection.isNotEmpty) {
                    setState(() {
                      _transactionType = selection.first;
                      if (!_currentCategories.containsKey(_selectedCategory)) {
                        _selectedCategory = null;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              // 6. EL FUTUREBUILDER AHORA TRABAJA CON OBJETOS 'Account'
              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return Text(
                      'Error: No se pudieron cargar las cuentas.',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    );
                  }
                  final accounts = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    items: accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedAccountId = value),
                    decoration: InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (value) =>
                        value == null ? 'Debes seleccionar una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              const Text('Categoría',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentCategories.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.key),
                    avatar: Icon(entry.value),
                    selected: _selectedCategory == entry.key,
                    onSelected: (isSelected) {
                      if (isSelected) {
                        setState(() => _selectedCategory = entry.key);
                      }
                      },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Iconsax.edit),
                label: _isLoading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)
                    : const Text('Guardar Cambios'),
                onPressed: _isLoading ? null : _updateTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}