// lib/screens/add_transaction_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:sasper/screens/place_search_screen.dart';
import 'package:geolocator/geolocator.dart';

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final TransactionRepository _transactionRepository =
      TransactionRepository.instance;
  final AccountRepository _accountRepository = AccountRepository.instance;
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance;

  DateTime _selectedDate = DateTime.now();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late AnimationController _shakeController;

  String _transactionType = 'Gasto';
  Category? _selectedCategory;
  bool _isLoading = false;
  String? _selectedAccountId;
  int? _selectedBudgetId;
  TransactionMood? _selectedMood;

  String? _selectedLocationName;
  double? _selectedLat;
  double? _selectedLng;
  bool _isFetchingLocation = false;

  late Future<List<Account>> _accountsFuture;
  late Future<List<Budget>> _budgetsFuture;
  late Future<List<Category>> _categoriesFuture;

  final int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepository.getAccounts();
    _budgetsFuture = _budgetRepository.getBudgets();
    _categoriesFuture = _categoryRepository.getCategories();
    _selectedDate = DateTime.now();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          NotificationHelper.show(
            message: 'Permiso de ubicación denegado.',
            type: NotificationType.warning,
          );
          setState(() => _isFetchingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        NotificationHelper.show(
          message: 'Permiso de ubicación denegado permanentemente.',
          type: NotificationType.error,
        );
        setState(() => _isFetchingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final locationName = await _getPlaceNameFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (mounted) {
        setState(() {
          _selectedLat = position.latitude;
          _selectedLng = position.longitude;
          _selectedLocationName = locationName;
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message: 'No se pudo obtener la ubicación.',
          type: NotificationType.error,
        );
        setState(() => _isFetchingLocation = false);
      }
    }
  }

  Future<String> _getPlaceNameFromCoordinates(double lat, double lng) async {
    final apiKey = AppConfig.googlePlacesApiKey;
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
      return "Ubicación Desconocida";
    } catch (e) {
      return "Ubicación Desconocida";
    }
  }

  void _onCategorySelected(Category category, List<Budget> budgets) {
    setState(() {
      _selectedCategory = category;
      try {
        final foundBudget = budgets.firstWhere(
          (b) => b.category == category.name && b.isActive,
        );
        _selectedBudgetId = foundBudget.id;
      } catch (e) {
        _selectedBudgetId = null;
      }
    });
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCategory == null ||
        _selectedAccountId == null) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      NotificationHelper.show(
        message: 'Por favor completa todos los campos',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isLoading = true);

    double amount = (double.tryParse(
          _amountController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0);

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
        category: _selectedCategory!.name,
        description: _descriptionController.text.trim(),
        transactionDate: _selectedDate,
        budgetId: _selectedBudgetId,
        mood: _selectedMood,
        locationName: _selectedLocationName,
        latitude: _selectedLat,
        longitude: _selectedLng,
      );

      if (mounted) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (_transactionType == 'Gasto' &&
            userId != null &&
            _selectedCategory != null) {
          _checkBudgetOnBackend(
            userId: userId,
            categoryName: _selectedCategory!.name,
          );
        }

        EventService.instance.fire(AppEvent.transactionCreated);
        Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transacción guardada exitosamente',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL GUARDAR: $e', name: 'AddTransactionScreen');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al guardar',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBudgetOnBackend({
    required String userId,
    required String categoryName,
  }) async {
    final url =
        Uri.parse('https://sasper.onrender.com/check-budget-on-transaction');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'category': categoryName}),
      );
      developer.log(
        'Backend response (budget check): ${response.statusCode} - ${response.body}',
        name: 'AddTransactionScreen',
      );
    } catch (e) {
      developer.log(
        'Error calling budget check backend: $e',
        name: 'AddTransactionScreen',
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isExpense = _transactionType == 'Gasto';

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar moderna
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 30, bottom: 14),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Transacción',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      isExpense
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Input de monto destacado
                  _buildAmountInput(colorScheme, isExpense)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .scale(delay: 100.ms),

                  // Selector de tipo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildTypeSelector(colorScheme)
                        .animate()
                        .fadeIn(delay: 200.ms),
                  ),

                  const SizedBox(height: 24),

                  // Contenido principal
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        _buildAccountSelector()
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideX(begin: -0.1),
                        const SizedBox(height: 24),
                        _buildDateSelector(colorScheme)
                            .animate()
                            .fadeIn(delay: 400.ms)
                            .slideX(begin: -0.1),
                        const SizedBox(height: 24),
                        _buildCategorySelector()
                            .animate()
                            .fadeIn(delay: 500.ms)
                            .slideX(begin: -0.1),
                        const SizedBox(height: 24),
                        if (isExpense) ...[
                          _buildMoodSelector(colorScheme)
                              .animate()
                              .fadeIn(delay: 600.ms)
                              .slideX(begin: -0.1),
                          const SizedBox(height: 24),
                        ],
                        _buildDescriptionField()
                            .animate()
                            .fadeIn(delay: 700.ms)
                            .slideX(begin: -0.1),
                        const SizedBox(height: 24),
                        _buildLocationSelector(colorScheme)
                            .animate()
                            .fadeIn(delay: 800.ms)
                            .slideX(begin: -0.1),
                        const SizedBox(height: 32),
                        _buildSaveButton(colorScheme)
                            .animate()
                            .fadeIn(delay: 900.ms)
                            .scale(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(ColorScheme colorScheme, bool isExpense) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      child: Column(
        children: [
          Text(
            'Monto',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            textAlign: TextAlign.center,
            autofocus: true,
            style: GoogleFonts.poppins(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              color: isExpense ? Colors.red : Colors.green,
              height: 1.2,
            ),
            decoration: InputDecoration(
              prefix: Align(
                alignment: Alignment.center,
                widthFactor: 0, // 🔥 El truco para que no desplaze el texto
                child: Text(
                  '\$',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: isExpense
                        ? Colors.red.withOpacity(0.7)
                        : Colors.green.withOpacity(0.7),
                  ),
                ),
              ),
              hintText: '0',
              hintStyle: TextStyle(
                color: Colors.grey.withOpacity(0.3),
              ),
              border: InputBorder.none,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Introduce un monto';
              if (double.tryParse(value.replaceAll(',', '.')) == null) {
                return 'Introduce un monto válido';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSelector(ColorScheme colorScheme) {
    return SegmentedButton<String>(
      style: SegmentedButton.styleFrom(
        textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        side: BorderSide(
          // Borde general alrededor del segmento
          color: colorScheme.outline.withOpacity(0.4),
          width: 1.2,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Bordes redondeados bonitos
        ),
        selectedBackgroundColor: _transactionType == 'Gasto'
            ? Colors.red.withOpacity(0.15)
            : Colors.green.withOpacity(0.15),
        selectedForegroundColor:
            _transactionType == 'Gasto' ? Colors.red : Colors.green,
      ),
      segments: const [
        ButtonSegment(
          value: 'Gasto',
          label: Text('Gasto'),
          icon: Icon(Iconsax.arrow_down_2),
        ),
        ButtonSegment(
          value: 'Ingreso',
          label: Text('Ingreso'),
          icon: Icon(Iconsax.arrow_up_1),
        ),
      ],
      selected: {_transactionType},
      onSelectionChanged: (newSelection) => setState(() {
        _transactionType = newSelection.first;
        _selectedCategory = null;
        _selectedBudgetId = null;
      }),
    );
  }

  Widget _buildAccountSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.wallet,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Cuenta',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Account>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('No tienes cuentas. Crea una primero.'),
              );
            }

            final accounts = snapshot.data!;
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: DropdownButtonFormField<String>(
                value: _selectedAccountId,
                items: accounts.map((account) {
                  final currencyFormat = NumberFormat.currency(
                    locale: 'es_CO',
                    symbol: '\$',
                    decimalDigits: 0,
                  );
                  return DropdownMenuItem<String>(
                    value: account.id,
                    child: Row(
                      children: [
                        Icon(Iconsax.wallet_3, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(account.name),
                              Text(
                                currencyFormat.format(account.balance),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: account.balance < 0
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) =>
                    setState(() => _selectedAccountId = value),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  hintText: 'Selecciona una cuenta',
                ),
                validator: (value) =>
                    value == null ? 'Debes seleccionar una cuenta' : null,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDateSelector(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(Iconsax.calendar_1, color: colorScheme.primary),
        title: const Text('Fecha'),
        subtitle: Text(
          DateFormat.yMMMd('es_CO').format(_selectedDate),
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Iconsax.arrow_right_3),
        onTap: () => _selectDate(context),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.category,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Categoría',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_selectedCategory != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '✓',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<Category>>(
          future: _categoriesFuture,
          builder: (context, categorySnapshot) {
            if (categorySnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (categorySnapshot.hasError) {
              return const Text('Error al cargar categorías');
            }
            if (!categorySnapshot.hasData || categorySnapshot.data!.isEmpty) {
              return const Text('No tienes categorías. Créalas en Ajustes.');
            }

            final allUserCategories = categorySnapshot.data!;
            final expectedTypeName =
                _transactionType == 'Gasto' ? 'expense' : 'income';
            final currentCategories = allUserCategories
                .where((c) => c.type.name == expectedTypeName)
                .toList();

            return FutureBuilder<List<Budget>>(
              future: _budgetsFuture,
              builder: (context, budgetSnapshot) {
                final budgets = budgetSnapshot.data ?? [];
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: currentCategories.map((category) {
                    final isSelected = _selectedCategory == category;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? category.colorAsObject
                              : Theme.of(context).colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        color: isSelected
                            ? category.colorAsObject.withOpacity(0.15)
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      ),
                      child: InkWell(
                        onTap: () {
                          if (isSelected) {
                            setState(() {
                              _selectedCategory = null;
                              _selectedBudgetId = null;
                            });
                          } else {
                            _onCategorySelected(category, budgets);
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                category.icon ?? Iconsax.category,
                                size: 20,
                                color: isSelected
                                    ? category.colorAsObject
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                category.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? category.colorAsObject
                                      : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildMoodSelector(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.emoji_happy, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Estado de ánimo (Opcional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: TransactionMood.values.map((mood) {
            final isSelected = _selectedMood == mood;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
                color: isSelected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
              ),
              child: InkWell(
                onTap: () => setState(() {
                  _selectedMood = isSelected ? null : mood;
                }),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mood.icon,
                        size: 20,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mood.displayName,
                        style: TextStyle(
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Iconsax.note_text,
                size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Descripción (Opcional)',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _descriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Añade una nota sobre esta transacción...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSelector(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: _isFetchingLocation
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Iconsax.location, color: colorScheme.primary),
        title: Text(_selectedLocationName ?? 'Ubicación (Opcional)'),
        subtitle: _selectedLocationName != null
            ? const Text('Toca para cambiar')
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Iconsax.gps),
              tooltip: 'Usar mi ubicación',
              onPressed: _isFetchingLocation ? null : _getCurrentLocation,
            ),
            if (_selectedLocationName != null)
              IconButton(
                icon: const Icon(Iconsax.close_circle, color: Colors.grey),
                tooltip: 'Quitar ubicación',
                onPressed: () {
                  setState(() {
                    _selectedLocationName = null;
                    _selectedLat = null;
                    _selectedLng = null;
                  });
                },
              ),
          ],
        ),
        onTap: () async {
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
              builder: (context) => const PlaceSearchScreen(),
            ),
          );
          if (result != null && mounted) {
            setState(() {
              _selectedLocationName = result['name'];
              _selectedLat = result['lat'];
              _selectedLng = result['lng'];
            });
          }
        },
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return FilledButton(
      onPressed: _isLoading ? null : _saveTransaction,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Iconsax.tick_circle, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Guardar Transacción',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
    );
  }
}
