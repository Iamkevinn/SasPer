import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditTransactionScreen extends StatefulWidget {
  // Recibimos la transacción que vamos a editar
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
  late String? _selectedCategory;
  late int? _selectedAccountId;
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  // Las mismas listas de categorías que en la pantalla de añadir
  final Map<String, IconData> _expenseCategories = { 'Comida': Iconsax.cup, 'Transporte': Iconsax.bus, 'Ocio': Iconsax.gameboy, 'Salud': Iconsax.health, 'Hogar': Iconsax.home, 'Compras': Iconsax.shopping_bag, 'Servicios': Iconsax.flash_1, };
  final Map<String, IconData> _incomeCategories = { 'Sueldo': Iconsax.money_recive, 'Inversión': Iconsax.chart, 'Freelance': Iconsax.briefcase, 'Regalo': Iconsax.gift, 'Otro': Iconsax.category, };
  Map<String, IconData> get _currentCategories => _transactionType == 'Gasto' ? _expenseCategories : _incomeCategories;

  @override
  void initState() {
    super.initState();
    // Pre-rellenamos los campos con los datos de la transacción recibida
    _amountController = TextEditingController(text: widget.transaction['amount'].toString());
    _descriptionController = TextEditingController(text: widget.transaction['description'] ?? '');
    _transactionType = widget.transaction['type'];
    _selectedCategory = widget.transaction['category'];
    _selectedAccountId = widget.transaction['account_id'];
  }

  Future<void> _updateTransaction() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null && _selectedAccountId != null) {
      setState(() => _isLoading = true);
      try {
        await supabase.from('transactions').update({
          'amount': double.parse(_amountController.text),
          'description': _descriptionController.text.trim(),
          'type': _transactionType,
          'category': _selectedCategory,
          'account_id': _selectedAccountId,
        }).eq('id', widget.transaction['id']); // La condición WHERE para actualizar la fila correcta

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Transacción actualizada!'), backgroundColor: Colors.green));
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteTransaction() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de que quieres eliminar esta transacción? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await supabase.from('transactions').delete().eq('id', widget.transaction['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transacción eliminada'), backgroundColor: Colors.blue));
          Navigator.of(context).pop();
        }
      } catch(e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
    // La UI es casi idéntica a la de añadir, pero con un botón extra de eliminar
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Transacción'),
        actions: [
          // Botón para eliminar
          IconButton(
            icon: Icon(Iconsax.trash, color: Theme.of(context).colorScheme.error),
            onPressed: _isLoading ? null : _deleteTransaction,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Los campos (monto, tipo, categoría, cuenta, descripción) son los mismos que en 'add_transaction_screen'
              // La única diferencia es que sus controladores y variables ya están inicializados.
              // (Aquí iría el código de la UI de los campos, que puedes copiar de add_transaction_screen.dart)
              // ...

              // Botón de guardar cambios
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Iconsax.edit),
                label: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Guardar Cambios'),
                onPressed: _isLoading ? null : _updateTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}