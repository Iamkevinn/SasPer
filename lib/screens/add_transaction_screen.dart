import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sas_per/services/checkBudgetStatusAfterTransaction.dart';
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _transactionType = 'Gasto';
  String? _selectedCategory;
  int? _selectedAccountId; // Variable para el ID de la cuenta
  bool _isLoading = false;

  final supabase = Supabase.instance.client;

  final Map<String, IconData> _expenseCategories = { 'Comida': Iconsax.cup, 'Transporte': Iconsax.bus, 'Ocio': Iconsax.gameboy, 'Salud': Iconsax.health, 'Hogar': Iconsax.home, 'Compras': Iconsax.shopping_bag, 'Servicios': Iconsax.flash_1, };
  final Map<String, IconData> _incomeCategories = { 'Sueldo': Iconsax.money_recive, 'Inversión': Iconsax.chart, 'Freelance': Iconsax.briefcase, 'Regalo': Iconsax.gift, 'Otro': Iconsax.category, };
  Map<String, IconData> get _currentCategories => _transactionType == 'Gasto' ? _expenseCategories : _incomeCategories;

  Future<void> _saveTransaction() async {
    // Validamos que todos los campos obligatorios estén completos
    if (_formKey.currentState!.validate() && _selectedCategory != null && _selectedAccountId != null) {
      setState(() => _isLoading = true);
      try {
        await supabase.from('transactions').insert({
          'user_id': supabase.auth.currentUser!.id,
          'account_id': _selectedAccountId, // Guardamos el ID de la cuenta
          'amount': double.parse(_amountController.text),
          'type': _transactionType,
          'category': _selectedCategory,
          'description': _descriptionController.text.trim(),
          'transaction_date': DateTime.now().toIso8601String(),
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Transacción guardada!'), backgroundColor: Colors.green));
          // --- NUEVO CÓDIGO DE VERIFICACIÓN ---
          await checkBudgetStatusAfterTransaction(
            categoryName: _selectedCategory!, // ID de la categoría de la nueva transacción
            userId: Supabase.instance.client.auth.currentUser!.id,
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona una cuenta'), backgroundColor: Colors.orange));
    } else if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, selecciona una categoría'), backgroundColor: Colors.orange));
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Añadir Transacción'), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 56, fontWeight: FontWeight.bold, color: _transactionType == 'Gasto' ? colorScheme.error : Colors.green.shade600),
                decoration: InputDecoration(
                  prefixText: '\$',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  border: InputBorder.none,
                  prefixStyle: TextStyle(fontSize: 40, fontWeight: FontWeight.w300, color: _transactionType == 'Gasto' ? colorScheme.error.withOpacity(0.7) : Colors.green.shade600.withOpacity(0.7)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? 'Introduce un monto válido' : null,
              ),

              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Gasto', label: Text('Gasto'), icon: Icon(Iconsax.arrow_down)),
                  ButtonSegment(value: 'Ingreso', label: Text('Ingreso'), icon: Icon(Iconsax.arrow_up)),
                ],
                selected: {_transactionType},
                onSelectionChanged: (newSelection) => setState(() {
                  _transactionType = newSelection.first;
                  _selectedCategory = null; 
                }),
              ),
              const SizedBox(height: 24),

              // --- SELECTOR DE CUENTA ---
              // Ahora es uno de los primeros campos a rellenar, por su importancia
              FutureBuilder<List<Map<String, dynamic>>>(
                future: supabase.from('accounts').select('id, name').eq('user_id', supabase.auth.currentUser!.id).order('name'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                  if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                    return Text('No tienes cuentas. Crea una primero en la pestaña "Cuentas".', textAlign: TextAlign.center, style: TextStyle(color: colorScheme.error));
                  }
                  final accounts = snapshot.data!;
                  return DropdownButtonFormField<int>(
                    value: _selectedAccountId,
                    decoration: const InputDecoration(labelText: 'Mover desde/hacia la cuenta', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.wallet_3)),
                    items: accounts.map((account) => DropdownMenuItem<int>(value: account['id'], child: Text(account['name']))).toList(),
                    onChanged: (value) => setState(() => _selectedAccountId = value),
                    validator: (value) => value == null ? 'Debes seleccionar una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 24),

              const Text('Categorías', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _currentCategories.entries.map((entry) {
                  return FilterChip(
                    label: Text(entry.key),
                    avatar: Icon(entry.value, color: _selectedCategory == entry.key ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant),
                    selected: _selectedCategory == entry.key,
                    onSelected: (selected) => setState(() => _selectedCategory = selected ? entry.key : null),
                    selectedColor: colorScheme.secondaryContainer,
                    checkmarkColor: colorScheme.onSecondaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Iconsax.document_text)),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Iconsax.send_1),
                label: _isLoading ? const CircularProgressIndicator(strokeWidth: 2) : const Text('Guardar Transacción'),
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}