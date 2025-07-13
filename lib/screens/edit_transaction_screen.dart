import 'dart:ui'; // Para el BackdropFilter
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditTransactionScreen extends StatefulWidget {
  final Map<String, dynamic> transaction;

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

  late Future<List<Map<String, dynamic>>> _accountsFuture;
  final supabase = Supabase.instance.client;

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
      _transactionType == 'Gasto'
          ? _expenseCategories
          : _incomeCategories;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.transaction['amount'].toString());
    _descriptionController = TextEditingController(
        text: widget.transaction['description'] ?? '');
    _transactionType = widget.transaction['type'] as String;
    _selectedCategory = widget.transaction['category'] as String?;
    _selectedAccountId =
        widget.transaction['account_id']?.toString();

    // CORRECCIÓN: pedimos el campo "account_name", y lo mostramos igual
    _accountsFuture = supabase
        .from('accounts')
        .select('id, name')
        .eq('user_id', supabase.auth.currentUser!.id)
        .then((value) {
      // valor debería ser List<dynamic>
      return List<Map<String, dynamic>>.from(value);
    });
  }

  Future<void> _updateTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Por favor, selecciona una categoría y una cuenta.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final accountIdAsInt = int.parse(_selectedAccountId!);
      await supabase
          .from('transactions')
          .update({
            'amount': double.parse(_amountController.text),
            'description': _descriptionController.text.trim(),
            'type': _transactionType,
            'category': _selectedCategory,
            'account_id': accountIdAsInt,
            'transaction_date':
                widget.transaction['transaction_date']
          })
          .eq('id', widget.transaction['id']);
      if (!mounted) return;
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
          content: const Text(
              '¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context).colorScheme.errorContainer,
                foregroundColor:
                    Theme.of(context).colorScheme.onErrorContainer,
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
            .eq('id', widget.transaction['id']);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transacción eliminada'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.of(context).pop(true);
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
              // MONTO
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
              // TIPO
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
                onSelectionChanged: (sel) => setState(() {
                  _transactionType = sel.first;
                  if (!_currentCategories
                      .containsKey(_selectedCategory)) {
                    _selectedCategory = null;
                  }
                }),
              ),
              const SizedBox(height: 24),
              // CUENTA
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _accountsFuture,
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child:
                            CircularProgressIndicator());
                  }
                  if (snap.hasError ||
                      !snap.hasData ||
                      snap.data!.isEmpty) {
                    return const Text(
                      'No se pudieron cargar las cuentas.',
                      style: TextStyle(color: Colors.red),
                    );
                  }
                  final accounts = snap.data!;
                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    items: accounts.map((acct) {
                      return DropdownMenuItem<String>(
                        value: acct['id'].toString(),
                        child: Text(acct['name']
                            .toString()),
                      );
                    }).toList(),
                    onChanged: (v) =>
                        setState(() => _selectedAccountId = v),
                    decoration: InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(12)),
                    ),
                    validator: (v) =>
                        v == null ? 'Selecciona una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 24),
              // CATEGORÍA
              const Text('Categoría',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentCategories.entries.map(
                  (e) {
                    return ChoiceChip(
                      label: Text(e.key),
                      avatar: Icon(e.value),
                      selected: _selectedCategory == e.key,
                      onSelected: (_) => setState(
                          () => _selectedCategory = e.key),
                    );
                  },
                ).toList(),
              ),
              const SizedBox(height: 24),
              // DESCRIPCIÓN
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              // GUARDAR
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Iconsax.edit),
                label: _isLoading
                    ? const CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)
                    : const Text('Guardar Cambios'),
                onPressed:
                    _isLoading ? null : _updateTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
