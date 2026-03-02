// lib/screens/add_transaction_screen.dart
// FIXES aplicados:
// 1. _buildAccountSection usa FutureBuilder<_accountsFuture> — no lista local
// 2. DropdownButtonFormField reemplazado por _TappableRow + showModalBottomSheet
//    → elimina el assert parentDataDirty en SliverToBoxAdapter
// 3. _buildFundSourceSection idem — Dropdown reemplazado por _TappableRow + sheet
// 4. _loadInitialData con log de error explícito para debug

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/debt_model.dart';
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

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────

class _C {
  final BuildContext ctx;
  _C(this.ctx);

  bool get isDark => Theme.of(ctx).brightness == Brightness.dark;

  Color get bg      => isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface => isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get raised  => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get sep     => isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  Color get label  => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get label2 => isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get label3 => isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get label4 => isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  static const Color red    = Color(0xFFFF3B30);
  static const Color green  = Color(0xFF30D158);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color blue   = Color(0xFF0A84FF);
  static const Color purple = Color(0xFFBF5AF2);

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double rSM  = 8.0;
  static const double rMD  = 12.0;
  static const double rLG  = 16.0;
  static const double rXL  = 22.0;
  static const double r2XL = 28.0;

  static const Duration fast   = Duration(milliseconds: 140);
  static const Duration mid    = Duration(milliseconds: 260);
  static const Duration slow   = Duration(milliseconds: 420);
  static const Curve   easeOut = Curves.easeOutCubic;
}


abstract class _T {
  static const Color bg             = Color(0xFF0A0A0F);
  static const Color surface        = Color(0xFF111118);
  static const Color surfaceRaised  = Color(0xFF181820);
  static const Color surfaceHighest = Color(0xFF1E1E28);
  static const Color border         = Color(0xFF252530);
  static const Color borderSubtle   = Color(0xFF1A1A22);

  static const Color textPrimary   = Color(0xFFF0ECE4);
  static const Color textSecondary = Color(0xFF7A7688);
  static const Color textTertiary  = Color(0xFF3C3A48);

  static const Color accent    = Color(0xFFC9A96E);
  static const Color accentDim = Color(0xFF6B5535);

  static const Color expenseColor = Color(0xFFE05555);
  static const Color expenseDim   = Color(0xFF3A1515);
  static const Color incomeColor  = Color(0xFF4EA87A);
  static const Color incomeDim    = Color(0xFF122A1E);
  static const Color debtColor    = Color(0xFFFF9F0A);

  static const double xs  = 4;
  static const double sm  = 8;
  static const double md  = 16;
  static const double lg  = 24;
  static const double xl  = 32;
  static const double xxl = 48;

  static const double rSM = 8;
  static const double rMD = 14;
  static const double rLG = 20;
  static const double rXL = 28;

  static const Duration fast = Duration(milliseconds: 160);
  static const Duration mid  = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 480);

  static const Curve curve    = Curves.easeInOutCubic;
  static const Curve curveOut = Curves.easeOutCubic;
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});
  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  final _txRepo       = TransactionRepository.instance;
  final _accountRepo  = AccountRepository.instance;
  final _budgetRepo   = BudgetRepository.instance;
  final _categoryRepo = CategoryRepository.instance;
  final _debtRepo     = DebtRepository.instance;

  final _formKey             = GlobalKey<FormState>();
  final _amountController    = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scrollController    = ScrollController();

  late AnimationController _shakeController;
  late Animation<double>   _shakeAnimation;

  DateTime _selectedDate     = DateTime.now();
  String   _transactionType  = 'Gasto';
  Category? _selectedCategory;
  bool     _isLoading        = false;
  int?     _selectedBudgetId;
  TransactionMood? _selectedMood;
  String?  _selectedLocationName;
  double?  _selectedLat;
  double?  _selectedLng;
  bool     _isFetchingLocation = false;
  bool     _amountHasValue     = false;
  Debt?    _smartSuggestion;
  bool _isInterestFree = false; // Añade este estado al inicio de tu clase

  // --- NUEVOS ESTADOS PARA TARJETAS ---
  int _installments = 1; // Por defecto 1 cuota
  bool get _isCreditCard => _selectedAccount?.type == 'Tarjeta de Crédito';

  // Cálculo de interés (IA)
  double _calculateInterestCost() {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.')) ?? 0.0;
    final rate = _selectedAccount?.interestRate ?? 0.0;
    if (_installments <= 1 || amount <= 0 || rate <= 0) return 0;
    
    // Fórmula de interés compuesto para cuotas fijas (Aproximación francesa)
    double monthlyRate = (rate / 100) / 12;
    double monthlyPayment = amount * (monthlyRate * math.pow(1 + monthlyRate, _installments)) / 
                          (math.pow(1 + monthlyRate, _installments) - 1);
    return (monthlyPayment * _installments) - amount;
  }

  // Consejo de fecha de corte (IA)
  String? _getCreditCardAdvice() {
    if (!_isCreditCard || _selectedAccount?.closingDay == null) return null;
    
    final closingDay = _selectedAccount!.closingDay!;
    final today = DateTime.now();
    final daysUntilClosing = closingDay - today.day;

    if (daysUntilClosing >= 0 && daysUntilClosing <= 3) {
      return "💡 Tip IA: Tu tarjeta corta en $daysUntilClosing días. Si esperas al día ${closingDay + 1}, ganarás casi 45 días para pagar esta compra.";
    }
    return null;
  }

  // Cuenta y fondo seleccionados — objetos completos, no solo IDs
  // Esto evita el DropdownButtonFormField que causa parentDataDirty
  Account? _selectedAccount;
  Debt?    _selectedFundSource;
  List<Debt> _availableFunds = [];

  // FUTUREs — única fuente de verdad para cuentas y presupuestos
  late final Future<List<Account>>  _accountsFuture  = _accountRepo.getAccounts();
  late final Future<List<Budget>>   _budgetsFuture   = _budgetRepo.getBudgets();
  late final Future<List<Category>> _categoriesFuture = _categoryRepo.getCategories();

  @override
  void initState() {
    super.initState();
    _loadAvailableFunds();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _amountController.addListener(() {
      final hasValue = _amountController.text.isNotEmpty;
      if (hasValue != _amountHasValue) {
        setState(() => _amountHasValue = hasValue);
      }
      _runSmartMatching();
    });

    // Pre-seleccionar la primera cuenta si solo hay una
    _accountsFuture.then((accounts) {
      if (mounted && accounts.length == 1) {
        setState(() => _selectedAccount = accounts.first);
      }
    }).catchError((e) {
      developer.log('Error cargando cuentas: $e', name: 'AddTransactionScreen');
    });
  }

  Future<void> _loadAvailableFunds() async {
    try {
      final debts = await _debtRepo.getDebtsWithSpendingFunds();
      if (mounted) setState(() => _availableFunds = debts);
    } catch (e) {
      developer.log('Error cargando fondos: $e', name: 'AddTransactionScreen');
    }
  }

  void _runSmartMatching() {
    if (!_isExpense || _amountController.text.isEmpty || _selectedFundSource != null) {
      if (_smartSuggestion != null) setState(() => _smartSuggestion = null);
      return;
    }
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0) return;

    try {
      final suggestion = _availableFunds.firstWhere((fund) {
        bool catMatch = false;
        if (_selectedCategory != null) {
          final catName  = _selectedCategory!.name.toLowerCase();
          final debtName = fund.name.toLowerCase();
          catMatch = debtName.contains(catName) || catName.contains(debtName);
        }
        final amtMatch = (fund.spendingFund - amount).abs() < 1.0;
        return catMatch || amtMatch;
      });
      if (_smartSuggestion?.id != suggestion.id) {
        setState(() => _smartSuggestion = suggestion);
      }
    } catch (_) {
      if (_smartSuggestion != null) setState(() => _smartSuggestion = null);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _shakeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool  get _isExpense   => _transactionType == 'Gasto';
  Color get _typeColor   => _isExpense ? _T.expenseColor : _T.incomeColor;
  Color get _typeDimColor => _isExpense ? _T.expenseDim : _T.incomeDim;

  // ── ACCIONES ──────────────────────────────────────────────────────────────

  /// Abre un bottom sheet iOS-style para seleccionar cuenta.
  /// Reemplaza DropdownButtonFormField — elimina el assert parentDataDirty.
  void _showAccountPicker(List<Account> accounts) {
    HapticFeedback.selectionClick();
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _T.surfaceRaised,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _T.textTertiary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                Text('Selecciona una cuenta',
                    style: TextStyle(
                        color: _T.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
              ]),
            ),
            ...accounts.map((a) {
              final positive = a.balance >= 0;
              final isSelected = _selectedAccount?.id == a.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedAccount = a);
                  Navigator.pop(context);
                },
                child: Container(
                  color: isSelected
                      ? _T.surfaceHighest
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: positive ? _T.incomeColor : _T.expenseColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(a.name,
                          style: TextStyle(
                              color: isSelected
                                  ? _T.textPrimary
                                  : _T.textSecondary,
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                    Text(fmt.format(a.balance),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: positive
                                ? _T.incomeColor
                                : _T.expenseColor)),
                    if (isSelected) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.check_rounded,
                          size: 17, color: _T.accent),
                    ],
                  ]),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Abre un bottom sheet para seleccionar fuente de fondos.
  void _showFundPicker() {
    HapticFeedback.selectionClick();
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: _T.surfaceRaised,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _T.textTertiary.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('¿Desde dónde?',
                  style: TextStyle(
                      color: _T.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
            // Opción: Mi dinero libre
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFundSource = null);
                Navigator.pop(context);
              },
              child: Container(
                color: _selectedFundSource == null
                    ? _T.surfaceHighest
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                child: Row(children: [
                  const Icon(Iconsax.wallet_3,
                      size: 17, color: _T.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Mi dinero libre',
                        style: TextStyle(
                            color: _selectedFundSource == null
                                ? _T.textPrimary
                                : _T.textSecondary,
                            fontSize: 15,
                            fontWeight: _selectedFundSource == null
                                ? FontWeight.w600
                                : FontWeight.w400)),
                  ),
                  if (_selectedFundSource == null)
                    const Icon(Icons.check_rounded,
                        size: 17, color: _T.accent),
                ]),
              ),
            ),
            // Préstamos disponibles
            ..._availableFunds.map((debt) {
              final isSelected = _selectedFundSource?.id == debt.id;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedFundSource = debt);
                  Navigator.pop(context);
                },
                child: Container(
                  color: isSelected ? _T.surfaceHighest : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 14),
                  child: Row(children: [
                    const Icon(Iconsax.lock_circle,
                        size: 17, color: _T.debtColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Préstamo: ${debt.name}',
                          style: TextStyle(
                              color: isSelected
                                  ? _T.debtColor
                                  : _T.textSecondary,
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                    ),
                    Text(fmt.format(debt.spendingFund),
                        style: const TextStyle(
                            fontSize: 13, color: _T.textSecondary)),
                    if (isSelected) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.check_rounded,
                          size: 17, color: _T.accent),
                    ],
                  ]),
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _onCategorySelected(Category category, List<Budget> budgets) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedCategory = category;
      try {
        final found = budgets.firstWhere((b) =>
            b.category == category.name &&
            !_selectedDate.isBefore(b.startDate) &&
            !_selectedDate.isAfter(b.endDate));
        _selectedBudgetId = found.id;
      } catch (_) {
        _selectedBudgetId = null;
      }
    });
    _runSmartMatching();
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCategory == null ||
        _selectedAccount == null) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      NotificationHelper.show(
          message: 'Completa monto, cuenta y categoría',
          type: NotificationType.error);
      return;
    }

    setState(() => _isLoading = true);
    final amount = double.tryParse(
        _amountController.text.trim().replaceAll(',', '.')) ?? 0.0;

    try {
      if (_selectedFundSource != null && _isExpense) {
        await _debtRepo.addTransactionFromDebtFund(
          accountId: _selectedAccount!.id,
          amount: amount.abs(),
          description: _descriptionController.text.trim().isEmpty
              ? 'Gasto de fondo: ${_selectedFundSource!.name}'
              : _descriptionController.text.trim(),
          category: _selectedCategory!.name,
          debtId: _selectedFundSource!.id,
          transactionDate: _selectedDate,
        );
      } else {
        await _txRepo.addTransaction(
          accountId: _selectedAccount!.id,
          amount: _isExpense ? -amount.abs() : amount.abs(),
          type: _transactionType,
          category: _selectedCategory!.name,
          description: _descriptionController.text.trim(),
          transactionDate: _selectedDate,
          budgetId: _selectedBudgetId,
          mood: _selectedMood,
          locationName: _selectedLocationName,
          latitude: _selectedLat,
          longitude: _selectedLng,
          creditCardId: _isCreditCard ? _selectedAccount!.id : null,
          installmentsTotal: _isCreditCard ? _installments : 1,
          installmentsCurrent: _isCreditCard ? 1 : null,
          isInstallment: _isCreditCard && _installments > 1,
          isInterestFree: _isInterestFree,
        );
      }

      if (mounted) {
        HapticFeedback.heavyImpact();
        EventService.instance.fire(AppEvent.transactionCreated);
        if (_selectedFundSource != null) {
          EventService.instance.fire(AppEvent.debtsChanged);
        }
        Navigator.of(context).pop(true);
        NotificationHelper.show(
            message: 'Transacción guardada',
            type: NotificationType.success);
      }
    } catch (e) {
      developer.log('Error guardando transacción: $e',
          name: 'AddTransactionScreen');
      if (mounted) {
        NotificationHelper.show(
            message: 'Error al guardar', type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isFetchingLocation = true);
    HapticFeedback.lightImpact();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        NotificationHelper.show(
            message: 'Permiso de ubicación denegado',
            type: NotificationType.warning);
        if (mounted) setState(() => _isFetchingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _selectedLat          = pos.latitude;
          _selectedLng          = pos.longitude;
          _selectedLocationName = name;
          _isFetchingLocation   = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isFetchingLocation = false);
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final res = await http.get(Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=${AppConfig.googlePlacesApiKey}'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (_) {}
    return 'Ubicación actual';
  }

  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _T.accent,
            surface: _T.surfaceRaised,
            onSurface: _T.textPrimary,
          ),
          dialogBackgroundColor: _T.surfaceRaised,
        ),
        child: child!,
      ),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _T.bg,
        body: Form(
          key: _formKey,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildAmountHero()),
              SliverToBoxAdapter(child: _buildSmartSuggestion()),
              SliverToBoxAdapter(
                child: _FadeSlide(
                  delay: 60,
                  child: Padding(
                    padding:
                        const EdgeInsets.fromLTRB(_T.md, 0, _T.md, _T.lg),
                    child: _buildTypeToggle(),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _T.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fuente de fondos — solo si es gasto y hay préstamos
                      if (_isExpense && _availableFunds.isNotEmpty) ...[
                        _FadeSlide(
                            delay: 100,
                            child: _buildFundSourceSection()),
                        const SizedBox(height: _T.md),
                      ],
                      _FadeSlide(delay: 120, child: _buildAccountSection()),
                      const SizedBox(height: _T.md),
                      // --- NUEVA SECCIÓN: CUOTAS E INTELIGENCIA DE TARJETA ---
                      if (_isExpense && _isCreditCard) ...[
                        _FadeSlide(
                          delay: 140,
                          child: _buildInstallmentSection(),
                        ),
                        const SizedBox(height: _T.md),
                        
                        if (_getCreditCardAdvice() != null) 
                          _FadeSlide(
                            delay: 150,
                            child: _AITipCard(message: _getCreditCardAdvice()!),
                          ),
                        const SizedBox(height: _T.md),
                      ],
                      _FadeSlide(delay: 160, child: _buildDateSection()),
                      const SizedBox(height: _T.md),
                      _FadeSlide(delay: 200, child: _buildCategorySection()),
                      if (_isExpense) ...[
                        const SizedBox(height: _T.md),
                        _FadeSlide(delay: 240, child: _buildMoodSection()),
                      ],
                      const SizedBox(height: _T.md),
                      _FadeSlide(delay: 280, child: _buildDescriptionSection()),
                      const SizedBox(height: _T.md),
                      _FadeSlide(delay: 320, child: _buildLocationSection()),
                      const SizedBox(height: _T.xl),
                      _FadeSlide(delay: 380, child: _buildSaveButton()),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(_T.md, _T.sm, _T.sm, 0),
        child: Row(children: [
          _IconBtn(
            icon: Icons.close_rounded,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
          ),
          const Spacer(),
        ]),
      ),
    );
  }

  // Widget para seleccionar cuotas
Widget _buildInstallmentSection() {
  final c = _C(context);
  final interest = _isInterestFree ? 0.0 : _calculateInterestCost();
  final commonInstallments = [1, 2, 3, 6, 12, 18, 24, 36, 48];

  return _Section(
    label: 'Configuración de Cuotas',
    child: Column(
      children: [
        // Selector horizontal (Mucho más rápido)
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            itemCount: commonInstallments.length,
            itemBuilder: (context, index) {
              final n = commonInstallments[index];
              final isSel = _installments == n;
              return GestureDetector(
                onTap: () {
                  setState(() => _installments = n);
                  HapticFeedback.selectionClick();
                },
                child: AnimatedContainer(
                  duration: _T.fast,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSel ? _T.accent : _T.surfaceHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? _T.accent : _T.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n ${n == 1 ? 'Cuota' : 'Cuotas'}',
                    style: TextStyle(
                      color: isSel ? Colors.white : _T.textSecondary,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        const Divider(height: 1, color: _T.borderSubtle),

        // Switch de "Sin Intereses" (Punto 3)
        _TappableRow(
          onTap: () => setState(() => _isInterestFree = !_isInterestFree),
          child: Row(
            children: [
              const Icon(Iconsax.flash_1, size: 18, color: _T.incomeColor),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Promoción Sin Intereses', 
                      style: TextStyle(color: _T.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    Text('Activa si la tienda ofrece 0% de interés', 
                      style: TextStyle(color: _T.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isInterestFree,
                activeColor: _T.incomeColor,
                onChanged: (v) => setState(() => _isInterestFree = v),
              ),
            ],
          ),
        ),

        if (interest > 0) ...[
          const Divider(height: 1, color: _T.borderSubtle),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Iconsax.info_circle, size: 14, color: _T.expenseColor),
                const SizedBox(width: 8),
                Text(
                  'Costo total en intereses: \$${interest.toStringAsFixed(0)}',
                  style: const TextStyle(color: _T.expenseColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ]
      ],
    ),
  );
}  
  // ── MONTO HERO ────────────────────────────────────────────────────────────

  Widget _buildAmountHero() {
    return _FadeSlide(
      delay: 0,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final offset = ((_shakeAnimation.value * 4) % 2 == 0 ? 1 : -1) *
              _shakeAnimation.value * 8;
          return Transform.translate(offset: Offset(offset, 0), child: child);
        },
        child: Padding(
          padding:
              const EdgeInsets.fromLTRB(_T.md, _T.sm, _T.md, _T.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: _T.mid,
                child: Text(
                  key: ValueKey(_transactionType),
                  _isExpense ? 'Registrando gasto' : 'Registrando ingreso',
                  style: TextStyle(
                    fontSize: 13,
                    color: _typeColor.withOpacity(0.7),
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: _T.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: _T.mid,
                      curve: _T.curve,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: _amountHasValue ? _typeColor : _T.textTertiary,
                        height: 1,
                      ),
                      child: const Text('\$'),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: _amountHasValue ? _typeColor : _T.textTertiary,
                        letterSpacing: -1.5,
                        height: 1.1,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0',
                        hintStyle: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          color: _T.textTertiary,
                          letterSpacing: -1.5,
                          height: 1.1,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return '';
                        if (double.tryParse(v.replaceAll(',', '.')) == null) return '';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              AnimatedContainer(
                duration: _T.mid,
                curve: _T.curve,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _amountHasValue
                        ? [_typeColor.withOpacity(0.8), Colors.transparent]
                        : [_T.border, Colors.transparent],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SUGERENCIA INTELIGENTE ────────────────────────────────────────────────

  Widget _buildSmartSuggestion() {
    if (_smartSuggestion == null || _selectedFundSource != null) {
      return const SizedBox.shrink();
    }
    return _FadeSlide(
      delay: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_T.md, 0, _T.md, _T.md),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() {
              _selectedFundSource = _smartSuggestion;
              _smartSuggestion = null;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _T.accent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(_T.rMD),
              border: Border.all(color: _T.accent.withOpacity(0.30)),
            ),
            child: Row(children: [
              const Icon(Iconsax.magic_star5, size: 18, color: _T.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sugerencia inteligente',
                        style: TextStyle(
                            color: _T.accent.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5)),
                    Text("¿Usar dinero de '${_smartSuggestion!.name}'?",
                        style: const TextStyle(
                            color: _T.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.add_circle_outline_rounded,
                  size: 20, color: _T.accent),
            ]),
          ),
        ),
      ),
    );
  }

  // ── SELECTOR DE TIPO ──────────────────────────────────────────────────────

  Widget _buildTypeToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _T.surfaceRaised,
        borderRadius: BorderRadius.circular(_T.rMD),
        border: Border.all(color: _T.border, width: 0.5),
      ),
      child: Row(children: [
        _TypeSegment(
          label: 'Gasto',
          selected: _isExpense,
          selectedColor: _T.expenseColor,
          selectedBg: _T.expenseDim,
          onTap: () {
            if (!_isExpense) {
              HapticFeedback.selectionClick();
              setState(() {
                _transactionType  = 'Gasto';
                _selectedCategory = null;
                _selectedBudgetId = null;
                _selectedFundSource = null;
              });
            }
          },
        ),
        _TypeSegment(
          label: 'Ingreso',
          selected: !_isExpense,
          selectedColor: _T.incomeColor,
          selectedBg: _T.incomeDim,
          onTap: () {
            if (_isExpense) {
              HapticFeedback.selectionClick();
              setState(() {
                _transactionType  = 'Ingreso';
                _selectedCategory = null;
                _selectedBudgetId = null;
                _selectedFundSource = null;
              });
            }
          },
        ),
      ]),
    );
  }

  // ── FUENTE DE FONDOS ──────────────────────────────────────────────────────
  // FIX: _TappableRow + showModalBottomSheet en lugar de DropdownButtonFormField

  Widget _buildFundSourceSection() {
    final hasSelection = _selectedFundSource != null;
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return _Section(
      label: 'Fuente de dinero',
      labelAccent: hasSelection,
      child: _TappableRow(
        onTap: _showFundPicker,
        child: Row(children: [
          Icon(
            hasSelection ? Iconsax.lock_circle : Iconsax.wallet_3,
            size: 16,
            color: hasSelection ? _T.debtColor : _T.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasSelection
                  ? 'Préstamo: ${_selectedFundSource!.name}'
                  : 'Mi dinero libre',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: hasSelection ? _T.debtColor : _T.textPrimary,
              ),
            ),
          ),
          if (hasSelection)
            Text(
              fmt.format(_selectedFundSource!.spendingFund),
              style: const TextStyle(
                  fontSize: 13, color: _T.textSecondary),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: _T.textTertiary, size: 20),
        ]),
      ),
    );
  }

  // ── CUENTA ────────────────────────────────────────────────────────────────
  // FIX: FutureBuilder con _accountsFuture + _TappableRow + showModalBottomSheet
  // Elimina DropdownButtonFormField que causaba el assert parentDataDirty

  Widget _buildAccountSection() {
    return _Section(
      label: 'Cuenta',
      labelAccent: _selectedAccount != null,
      child: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snap) {
          // Cargando
          if (snap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: _T.md, vertical: 14),
              child: _ShimmerRow(),
            );
          }

          // Error explícito — ya no se silencia
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(_T.md),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 16, color: _T.expenseColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error al cargar cuentas: ${snap.error}',
                      style: const TextStyle(
                          fontSize: 13, color: _T.expenseColor)),
                ),
              ]),
            );
          }

          final accounts = snap.data ?? [];

          if (accounts.isEmpty) {
            return const _EmptyHint(text: 'Crea una cuenta primero');
          }

          // Si solo hay 1 cuenta y no está seleccionada, auto-seleccionarla
          if (_selectedAccount == null && accounts.length == 1) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedAccount = accounts.first);
            });
          }

          final fmt = NumberFormat.currency(
              locale: 'es_CO', symbol: '\$', decimalDigits: 0);
          final acc = _selectedAccount;
          final positive = acc == null || acc.balance >= 0;

          return _TappableRow(
            onTap: () => _showAccountPicker(accounts),
            child: Row(children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: acc == null
                      ? _T.textTertiary
                      : positive
                          ? _T.incomeColor
                          : _T.expenseColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  acc?.name ?? 'Selecciona una cuenta',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: acc == null ? _T.textSecondary : _T.textPrimary,
                  ),
                ),
              ),
              if (acc != null)
                Text(
                  fmt.format(acc.balance),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: positive ? _T.incomeColor : _T.expenseColor,
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: _T.textTertiary, size: 20),
            ]),
          );
        },
      ),
    );
  }

  // ── FECHA ─────────────────────────────────────────────────────────────────

  Widget _buildDateSection() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final label = isToday
        ? 'Hoy'
        : DateFormat.yMMMd('es_CO').format(_selectedDate);

    return _Section(
      label: 'Fecha',
      child: _TappableRow(
        onTap: _selectDate,
        child: Row(children: [
          Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isToday ? _T.accent : _T.textPrimary,
              )),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded,
              color: _T.textTertiary, size: 20),
        ]),
      ),
    );
  }

  // ── CATEGORÍAS ────────────────────────────────────────────────────────────

  Widget _buildCategorySection() {
    return _Section(
      label: _selectedCategory != null
          ? 'Categoría  ·  ${_selectedCategory!.name}'
          : 'Categoría',
      labelAccent: _selectedCategory != null,
      child: FutureBuilder<List<Category>>(
        future: _categoriesFuture,
        builder: (context, catSnap) {
          if (catSnap.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(_T.md),
              child: _ShimmerRow(),
            );
          }
          final all      = catSnap.data ?? [];
          final type     = _isExpense ? 'expense' : 'income';
          final filtered = all.where((c) => c.type.name == type).toList();

          if (filtered.isEmpty) {
            return const _EmptyHint(
                text: 'No hay categorías. Créalas en Ajustes.');
          }

          return FutureBuilder<List<Budget>>(
            future: _budgetsFuture,
            builder: (_, budgetSnap) {
              final budgets = budgetSnap.data ?? [];
              return Padding(
                padding: const EdgeInsets.all(_T.md),
                child: Wrap(
                  spacing: _T.sm,
                  runSpacing: _T.sm,
                  children: filtered.map((cat) {
                    final sel = _selectedCategory == cat;
                    return _CategoryChip(
                      category: cat,
                      selected: sel,
                      onTap: () {
                        if (sel) {
                          setState(() {
                            _selectedCategory = null;
                            _selectedBudgetId = null;
                          });
                        } else {
                          _onCategorySelected(cat, budgets);
                        }
                      },
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── ESTADO DE ÁNIMO ───────────────────────────────────────────────────────

  Widget _buildMoodSection() {
    return _Section(
      label: 'Ánimo  ·  Opcional',
      child: Padding(
        padding: const EdgeInsets.all(_T.md),
        child: Wrap(
          spacing: _T.sm,
          runSpacing: _T.sm,
          children: TransactionMood.values.map((mood) {
            final sel = _selectedMood == mood;
            return _MoodChip(
              mood: mood,
              selected: sel,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedMood = sel ? null : mood);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── DESCRIPCIÓN ───────────────────────────────────────────────────────────

  Widget _buildDescriptionSection() {
    return _Section(
      label: 'Nota  ·  Opcional',
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(_T.md, 0, _T.md, _T.md),
        child: TextField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(
              color: _T.textPrimary, fontSize: 15, height: 1.5),
          decoration: InputDecoration(
            hintText: 'Añade una nota...',
            hintStyle: TextStyle(
                color: _T.textTertiary.withOpacity(0.8)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  // ── UBICACIÓN ─────────────────────────────────────────────────────────────

  Widget _buildLocationSection() {
    final hasLocation = _selectedLocationName != null;

    return _Section(
      label: 'Ubicación  ·  Opcional',
      child: _TappableRow(
        onTap: () async {
          HapticFeedback.selectionClick();
          final result = await Navigator.push<Map<String, dynamic>>(
            context,
            MaterialPageRoute(
                builder: (context) => const PlaceSearchScreen()),
          );
          if (result != null && mounted) {
            setState(() {
              _selectedLocationName = result['name'];
              _selectedLat          = result['lat'];
              _selectedLng          = result['lng'];
            });
          }
        },
        child: Row(children: [
          Expanded(
            child: Text(
              hasLocation ? _selectedLocationName! : 'Buscar lugar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color:
                    hasLocation ? _T.textPrimary : _T.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: _T.sm),
          if (_isFetchingLocation)
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: _T.accent),
            )
          else
            GestureDetector(
              onTap: _getCurrentLocation,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _T.xs),
                child: Icon(Iconsax.gps,
                    size: 18,
                    color: hasLocation ? _T.accent : _T.textTertiary),
              ),
            ),
          if (hasLocation) ...[
            const SizedBox(width: _T.sm),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _selectedLocationName = null;
                  _selectedLat = null;
                  _selectedLng = null;
                });
              },
              child: const Icon(Icons.close_rounded,
                  size: 16, color: _T.textTertiary),
            ),
          ] else
            const Icon(Icons.chevron_right_rounded,
                color: _T.textTertiary, size: 20),
        ]),
      ),
    );
  }

  // ── BOTÓN GUARDAR ─────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _saveTransaction,
      child: AnimatedContainer(
        duration: _T.mid,
        curve: _T.curve,
        height: 54,
        decoration: BoxDecoration(
          color: _typeColor,
          borderRadius: BorderRadius.circular(_T.rMD),
          boxShadow: [
            BoxShadow(
              color: _typeColor.withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: _T.fast,
          child: _isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.8, color: Colors.white),
                )
              : Text(
                  key: ValueKey(_transactionType),
                  _isExpense ? 'Registrar gasto' : 'Registrar ingreso',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── COMPONENTES COMPARTIDOS ──────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  final bool labelAccent;

  const _Section({
    required this.label,
    required this.child,
    this.labelAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: _T.sm),
          child: AnimatedDefaultTextStyle(
            duration: _T.mid,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.9,
              color: labelAccent ? _T.accent : _T.textTertiary,
            ),
            child: Text(label.toUpperCase()),
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _T.surfaceRaised,
            borderRadius: BorderRadius.circular(_T.rMD),
            border: Border.all(color: _T.borderSubtle, width: 0.5),
          ),
          // IMPORTANTE: sin Clip.antiAlias ni clipBehavior — causaba parentDataDirty
          child: child,
        ),
      ],
    );
  }
}

class _TappableRow extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _TappableRow({required this.onTap, required this.child});

  @override
  State<_TappableRow> createState() => _TappableRowState();
}

class _TappableRowState extends State<_TappableRow> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressing ? _T.surfaceHighest : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: _T.md, vertical: 14),
        child: widget.child,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final Category category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.colorAsObject;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _T.mid,
        curve: _T.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.15) : _T.surfaceHighest,
          borderRadius: BorderRadius.circular(_T.rSM + 4),
          border: Border.all(
            color: selected ? color.withOpacity(0.6) : _T.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[
            Icon(category.icon ?? Iconsax.category,
                size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(category.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : _T.textSecondary,
              )),
        ]),
      ),
    );
  }
}

class _MoodChip extends StatelessWidget {
  final TransactionMood mood;
  final bool selected;
  final VoidCallback onTap;

  const _MoodChip({
    required this.mood,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: _T.mid,
        curve: _T.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _T.accent.withOpacity(0.12) : _T.surfaceHighest,
          borderRadius: BorderRadius.circular(_T.rSM + 4),
          border: Border.all(
            color: selected ? _T.accent.withOpacity(0.5) : _T.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(mood.icon,
              size: 14,
              color: selected ? _T.accent : _T.textSecondary),
          const SizedBox(width: 6),
          Text(mood.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? _T.accent : _T.textSecondary,
              )),
        ]),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final Color selectedColor;
  final Color selectedBg;
  final VoidCallback onTap;

  const _TypeSegment({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.selectedBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: _T.mid,
          curve: _T.curve,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(_T.rSM + 2),
          ),
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: _T.fast,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? selectedColor : _T.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: _T.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _T.border, width: 0.5),
        ),
        child: Icon(icon, size: 18, color: _T.textSecondary),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_T.md),
      child: Text(text,
          style: const TextStyle(fontSize: 14, color: _T.textSecondary)),
    );
  }
}

class _ShimmerRow extends StatefulWidget {
  const _ShimmerRow();
  @override State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: 16, width: 120,
        decoration: BoxDecoration(
          color: Color.lerp(_T.surfaceHighest, _T.border, _anim.value),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;
  const _FadeSlide({required this.child, required this.delay});
  @override State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _opacity;
  late Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl    = AnimationController(duration: _T.slow, vsync: this);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

// Tarjeta de consejo IA
class _AITipCard extends StatelessWidget {
  final String message;
  const _AITipCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _T.accent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(_T.rMD),
        border: Border.all(color: _T.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.lamp_on, color: _T.accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: _T.textSecondary, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}