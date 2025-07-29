// lib/screens/add_transaction_screen.dart (VERSIÓN FINAL COMPLETA USANDO SINGLETONS)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/budget_repository.dart'; // Importamos para la lógica de presupuestos
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class AddTransactionScreen extends StatefulWidget {
  // Los repositorios ya no se pasan en el constructor.
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;
  final BudgetRepository _budgetRepository = BudgetRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _transactionType = 'Gasto';
  String? _selectedCategory;
  bool _isLoading = false;
  String? _selectedAccountId;
  int? _selectedBudgetId;
  
  late Future<List<Account>> _accountsFuture;
  late Future<List<BudgetProgress>> _budgetsFuture;

  final Map<String, IconData> _expenseCategories = { 'Comida': Iconsax.cup, 'Transporte': Iconsax.bus, 'Ocio': Iconsax.gameboy, 'Salud': Iconsax.health, 'Hogar': Iconsax.home, 'Compras': Iconsax.shopping_bag, 'Servicios': Iconsax.flash_1, 'Otro': Iconsax.category };
  final Map<String, IconData> _incomeCategories = { 'Sueldo': Iconsax.money_recive, 'Inversión': Iconsax.chart, 'Freelance': Iconsax.briefcase, 'Regalo': Iconsax.gift, 'Otro': Iconsax.category_2 };
  Map<String, IconData> get _currentCategories => _transactionType == 'Gasto' ? _expenseCategories : _incomeCategories;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    // Cargamos los presupuestos del mes actual para poder vincularlos.
    _budgetsFuture = _budgetRepository.getBudgetsForCurrentMonth();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String categoryName, List<BudgetProgress> budgets) {
    setState(() {
      _selectedCategory = categoryName;
      try {
        final foundBudget = budgets.firstWhere((b) => b.category == categoryName);
        _selectedBudgetId = foundBudget.budgetId;
        developer.log('✅ Presupuesto encontrado para "$categoryName". ID: $_selectedBudgetId', name: 'AddTransactionScreen');
      } catch (e) {
        _selectedBudgetId = null;
        developer.log('ℹ️ No hay presupuesto activo para "$categoryName".', name: 'AddTransactionScreen');
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null || _selectedAccountId == null) {
      NotificationHelper.show(
            message: 'Porfavor rellena todos los campos!',
            type: NotificationType.error,
          );
      return;
    }
    
    setState(() => _isLoading = true);

    double amount = (double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0.0);
    if (_transactionType == 'Gasto') {
      amount = -amount.abs();
    } else {
      amount = amount.abs();
    }

    try {
      await _transactionRepository.addTransaction(
        accountId: _selectedAccountId!,
        amount: amount,
        type: _transactionType,
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
        transactionDate: DateTime.now(),
        budgetId: _selectedBudgetId,
      );
      
      if (mounted) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (_transactionType == 'Gasto' && userId != null && _selectedCategory != null) {
            _checkBudgetOnBackend(userId: userId, categoryName: _selectedCategory!);
        }

        EventService.instance.fire(AppEvent.transactionCreated);
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transacción guardada!',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL GUARDAR TRANSACCIÓN: $e', name: 'AddTransactionScreen');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al guardar la transacción.',
            type: NotificationType.error,
          );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBudgetOnBackend({
    required String userId, 
    required String categoryName
  }) async {
    final url = Uri.parse('https://sasper.onrender.com/check-budget-on-transaction');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'category': categoryName}),
      );
      developer.log('Backend response (budget check): ${response.statusCode} - ${response.body}', name: 'AddTransactionScreen');
    } catch (e) {
      developer.log('Error calling budget check backend: $e', name: 'AddTransactionScreen');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Añadir Transacción', style: GoogleFonts.poppins())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _amountController,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 56, fontWeight: FontWeight.bold, color: _transactionType == 'Gasto' ? colorScheme.error : Colors.green.shade600),
                decoration: InputDecoration(
                  prefixText: '\$',
                  hintText: '0.00',
                  hintStyle: TextStyle(color: Colors.grey.withOpacity(0.5)),
                  border: InputBorder.none,
                  prefixStyle: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.w300, color: _transactionType == 'Gasto' ? colorScheme.error.withOpacity(0.7) : Colors.green.shade600.withOpacity(0.7)),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Introduce un monto';
                  if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Introduce un monto válido';
                  return null;
                },
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
                  _selectedBudgetId = null;
                }),
              ),
              const SizedBox(height: 24),
              
              FutureBuilder<List<Account>>(
                future: _accountsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const LinearProgressIndicator();
                  if (snapshot.hasError) return Text('Error al cargar cuentas: ${snapshot.error}');
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('No tienes cuentas. Crea una primero.'));
                  }
                  final accounts = snapshot.data!;
                  return DropdownButtonFormField<String>(
                    value: _selectedAccountId,
                    decoration: InputDecoration(labelText: 'Cuenta', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Iconsax.wallet_3)),
                    items: accounts.map((account) {
                      return DropdownMenuItem<String>(
                        value: account.id, 
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedAccountId = value),
                    validator: (value) => value == null ? 'Debes seleccionar una cuenta' : null,
                  );
                },
              ),
              const SizedBox(height: 24),

              Text('Categorías', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              
              FutureBuilder<List<BudgetProgress>>(
                future: _budgetsFuture,
                builder: (context, snapshot) {
                  final budgets = snapshot.data ?? [];
                  return Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: _currentCategories.entries.map((entry) {
                      return FilterChip(
                        label: Text(entry.key, style: GoogleFonts.poppins()),
                        avatar: Icon(entry.value, color: _selectedCategory == entry.key ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant),
                        selected: _selectedCategory == entry.key,
                        onSelected: (selected) {
                           if (selected) {
                             _onCategorySelected(entry.key, budgets);
                           } else {
                             setState(() {
                               _selectedCategory = null;
                               _selectedBudgetId = null;
                             });
                           }
                        },
                        selectedColor: colorScheme.secondaryContainer,
                        checkmarkColor: colorScheme.onSecondaryContainer,
                      );
                    }).toList(),
                  );
                }
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Descripción (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), prefixIcon: const Icon(Iconsax.document_text)),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              
              ElevatedButton.icon(
                icon: _isLoading ? const SizedBox.shrink() : const Icon(Iconsax.send_1),
                label: _isLoading ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white) : const Text('Guardar Transacción'),
                onPressed: _isLoading ? null : _saveTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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