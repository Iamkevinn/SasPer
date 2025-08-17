// lib/screens/add_transaction_screen.dart (VERSIÓN CORREGIDA Y ADAPTADA)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/models/budget_models.dart'; // Importa el nuevo modelo `Budget`
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _transactionType = 'Gasto';
  Category? _selectedCategory;
  bool _isLoading = false;
  String? _selectedAccountId;
  int? _selectedBudgetId; // Mantenemos el ID del presupuesto a vincular
  TransactionMood? _selectedMood;
  
  late Future<List<Account>> _accountsFuture;
  // --- ¡CORRECCIÓN! El Future ahora espera una lista del nuevo modelo `Budget` ---
  late Future<List<Budget>> _budgetsFuture;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    // ¡CORRECCIÓN! Usamos el método `getBudgets` que devuelve los nuevos modelos.
    _budgetsFuture = _budgetRepository.getBudgets();
    _categoriesFuture = _categoryRepository.getCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // --- ¡CORRECCIÓN! La función ahora recibe una lista de `Budget` ---
  void _onCategorySelected(Category category, List<Budget> budgets) {
    setState(() {
      _selectedCategory = category;
      try {
        // La lógica de búsqueda sigue siendo válida.
        // Buscamos un presupuesto ACTIVO que coincida con la categoría seleccionada.
        final foundBudget = budgets.firstWhere(
          (b) => b.category == category.name && b.isActive
        );
        _selectedBudgetId = foundBudget.id;
      } catch (e) {
        // Si no se encuentra un presupuesto activo para esa categoría, no se vincula ninguno.
        _selectedBudgetId = null;
      }
    });
  }

  Future<void> _saveTransaction() async {
    // --- ¡CORRECCIÓN! Añadimos un ! para solucionar el error de tipo nullable ---
    if (!_formKey.currentState!.validate() || _selectedCategory == null || _selectedAccountId == null) {
      NotificationHelper.show(message: 'Por favor rellena todos los campos!', type: NotificationType.error);
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
      // La llamada al repositorio ya era correcta.
      await _transactionRepository.addTransaction(
        accountId: _selectedAccountId!,
        amount: amount,
        type: _transactionType,
        category: _selectedCategory!.name, 
        description: _descriptionController.text.trim(),
        transactionDate: DateTime.now(),
        budgetId: _selectedBudgetId,
        mood: _selectedMood,
      );
      
      if (mounted) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        // --- ¡CORRECCIÓN! Añadimos un ! aquí también ---
        if (_transactionType == 'Gasto' && userId != null && _selectedCategory != null) {
            _checkBudgetOnBackend(userId: userId, categoryName: _selectedCategory!.name);
        }

        EventService.instance.fire(AppEvent.transactionCreated);
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(message: 'Transacción guardada!', type: NotificationType.success);
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL GUARDAR TRANSACCIÓN: $e', name: 'AddTransactionScreen');
      if (mounted) {
        NotificationHelper.show(message: 'Error al guardar la transacción.', type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ... (El resto de la clase, incluyendo `_checkBudgetOnBackend` y `build`, se mantiene igual)
  // ... Pegar el resto del código desde el original
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
              
              FutureBuilder<List<Category>>(
                future: _categoriesFuture,
                builder: (context, categorySnapshot) {
                  if (categorySnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                  }
                  if (categorySnapshot.hasError) {
                    developer.log(
                      'Error en FutureBuilder<List<Category>>',
                      name: 'AddTransactionScreen',
                      error: categorySnapshot.error,
                      stackTrace: categorySnapshot.stackTrace,
                    );
                    return Center( child: Text('Error al cargar categorías: ${categorySnapshot.error}'));
                  }
                  if (!categorySnapshot.hasData || categorySnapshot.data!.isEmpty) {
                    return const Text('No tienes categorías. Créalas en Ajustes.');
                  }
                  final allUserCategories = categorySnapshot.data!;
                  final expectedTypeName = _transactionType == 'Gasto' ? 'expense' : 'income';
                  final currentCategories = allUserCategories
                      .where((c) => c.type.name == expectedTypeName)
                      .toList();

                  // --- ¡CORRECCIÓN! El FutureBuilder anidado ahora espera una lista de `Budget` ---
                  return FutureBuilder<List<Budget>>(
                    future: _budgetsFuture,
                    builder: (context, budgetSnapshot) {
                      final budgets = budgetSnapshot.data ?? [];
                      return Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: currentCategories.map((category) {
                          return FilterChip(
                            label: Text(category.name, style: GoogleFonts.poppins()),
                            avatar: Icon(
                              category.icon ?? Iconsax.category,
                              color: _selectedCategory == category ? Theme.of(context).colorScheme.onSecondaryContainer : category.colorAsObject,
                            ),
                            selected: _selectedCategory == category,
                            onSelected: (selected) {
                              if (selected) {
                                _onCategorySelected(category, budgets);
                              } else {
                                setState(() {
                                  _selectedCategory = null;
                                  _selectedBudgetId = null;
                                });
                              }
                            },
                            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
                            checkmarkColor: Theme.of(context).colorScheme.onSecondaryContainer,
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              
              if (_transactionType == 'Gasto') ...[
                Text('¿Cómo te sentiste con este gasto? (Opcional)', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: TransactionMood.values.map((mood) {
                    return FilterChip(
                      label: Text(mood.displayName, style: GoogleFonts.poppins()),
                      avatar: Icon(
                        mood.icon,
                        color: _selectedMood == mood ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant,
                      ),
                      selected: _selectedMood == mood,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedMood = mood;
                          } else {
                            _selectedMood = null;
                          }
                        });
                      },
                      selectedColor: colorScheme.secondaryContainer,
                      checkmarkColor: colorScheme.onSecondaryContainer,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],
              
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