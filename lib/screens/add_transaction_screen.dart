// lib/screens/add_transaction_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO                                                    │
// │  ─────────────────                                                      │
// │  • Una sola decisión a la vez. El usuario no se siente abrumado.       │
// │  • El monto es el protagonista. Todo lo demás es soporte.              │
// │  • Sin decoración gratuita. Cada pixel tiene un propósito.             │
// │  • Micro-feedback en cada interacción (haptic + animación).            │
// │  • Jerarquía de información: lo crítico primero, lo opcional al final. │
// └─────────────────────────────────────────────────────────────────────────┘

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
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

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
abstract class _T {
  // Superficie
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF111118);
  static const Color surfaceRaised = Color(0xFF181820);
  static const Color surfaceHighest = Color(0xFF1E1E28);
  static const Color border = Color(0xFF252530);
  static const Color borderSubtle = Color(0xFF1A1A22);

  // Texto
  static const Color textPrimary = Color(0xFFF0ECE4);
  static const Color textSecondary = Color(0xFF7A7688);
  static const Color textTertiary = Color(0xFF3C3A48);

  // Acento único — champagne cálido (consistente con ManifestationsScreen)
  static const Color accent = Color(0xFFC9A96E);
  static const Color accentDim = Color(0xFF6B5535);

  // Semánticos — mínimos y refinados
  static const Color expenseColor = Color(0xFFE05555);
  static const Color expenseDim = Color(0xFF3A1515);
  static const Color incomeColor = Color(0xFF4EA87A);
  static const Color incomeDim = Color(0xFF122A1E);

  // Espaciado
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Radios
  static const double rSM = 8;
  static const double rMD = 14;
  static const double rLG = 20;
  static const double rXL = 28;

  // Animaciones — Apple timing
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration mid = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 480);

  static const Curve curve = Curves.easeInOutCubic;
  static const Curve curveOut = Curves.easeOutCubic;
}

// ─── PANTALLA PRINCIPAL ────────────────────────────────────────────────────────
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  // Repositorios
  final _txRepo = TransactionRepository.instance;
  final _accountRepo = AccountRepository.instance;
  final _budgetRepo = BudgetRepository.instance;
  final _categoryRepo = CategoryRepository.instance;

  // Controladores
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scrollController = ScrollController();

  // Animación de error (shake)
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // Estado
  DateTime _selectedDate = DateTime.now();
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
  bool _amountHasValue = false;

  // Futures
  late Future<List<Account>> _accountsFuture;
  late Future<List<Budget>> _budgetsFuture;
  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _accountRepo.getAccounts();
    _budgetsFuture = _budgetRepo.getBudgets();
    _categoriesFuture = _categoryRepo.getCategories();

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
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _shakeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool get _isExpense => _transactionType == 'Gasto';
  Color get _typeColor => _isExpense ? _T.expenseColor : _T.incomeColor;
  Color get _typeDimColor => _isExpense ? _T.expenseDim : _T.incomeDim;

  // ─── LÓGICA DE NEGOCIO ────────────────────────────────────────────────────

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
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCategory == null ||
        _selectedAccountId == null) {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      NotificationHelper.show(
        message: 'Completa monto, cuenta y categoría',
        type: NotificationType.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.lightImpact();

    double amount = double.tryParse(
          _amountController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    amount = _isExpense ? -amount.abs() : amount.abs();

    try {
      await _txRepo.addTransaction(
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
        if (_isExpense && userId != null) {
          _checkBudgetOnBackend(
              userId: userId, categoryName: _selectedCategory!.name);
        }
        HapticFeedback.heavyImpact();
        EventService.instance.fire(AppEvent.transactionCreated);
        Navigator.of(context).pop(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Transacción guardada',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 $e', name: 'AddTransactionScreen');
      if (mounted) {
        HapticFeedback.vibrate();
        NotificationHelper.show(
          message: 'Error al guardar',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBudgetOnBackend(
      {required String userId, required String categoryName}) async {
    try {
      await http.post(
        Uri.parse('https://sasper.onrender.com/check-budget-on-transaction'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'category': categoryName}),
      );
    } catch (_) {}
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
          type: NotificationType.warning,
        );
        setState(() => _isFetchingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final name = await _reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _selectedLat = pos.latitude;
          _selectedLng = pos.longitude;
          _selectedLocationName = name;
          _isFetchingLocation = false;
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

  // ─── BUILD ─────────────────────────────────────────────────────────────────

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
              // ── CABECERA ──────────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ── MONTO — el protagonista ───────────────────────────────────
              SliverToBoxAdapter(child: _buildAmountHero()),

              // ── SELECTOR DE TIPO ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _FadeSlide(
                  delay: 60,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        _T.md, 0, _T.md, _T.lg),
                    child: _buildTypeToggle(),
                  ),
                ),
              ),

              // ── SECCIONES DEL FORMULARIO ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _T.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FadeSlide(delay: 120, child: _buildAccountSection()),
                      const SizedBox(height: _T.md),
                      _FadeSlide(delay: 160, child: _buildDateSection()),
                      const SizedBox(height: _T.md),
                      _FadeSlide(delay: 200, child: _buildCategorySection()),
                      if (_isExpense) ...[
                        const SizedBox(height: _T.md),
                        _FadeSlide(delay: 240, child: _buildMoodSection()),
                      ],
                      const SizedBox(height: _T.md),
                      _FadeSlide(
                          delay: 280, child: _buildDescriptionSection()),
                      const SizedBox(height: _T.md),
                      _FadeSlide(
                          delay: 320, child: _buildLocationSection()),
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

  // ── CABECERA ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_T.md, _T.sm, _T.sm, 0),
        child: Row(
          children: [
            // Botón de cerrar — minimalista, sin ruido
            _IconBtn(
              icon: Icons.close_rounded,
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  // ── MONTO HERO ──────────────────────────────────────────────────────────────
  // El número grande que comunica de inmediato de qué va esta pantalla.
  Widget _buildAmountHero() {
    return _FadeSlide(
      delay: 0,
      child: AnimatedBuilder(
        animation: _shakeAnimation,
        builder: (context, child) {
          final offset =
              ((_shakeAnimation.value * 4) % 2 == 0 ? 1 : -1) *
                  _shakeAnimation.value *
                  8;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_T.md, _T.sm, _T.md, _T.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Eyebrow label
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

              // Monto grande
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Símbolo de moneda
                  Padding(
                    padding: const EdgeInsets.only(right: 4, top: 10),
                    child: AnimatedDefaultTextStyle(
                      duration: _T.mid,
                      curve: _T.curve,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: _amountHasValue
                            ? _typeColor
                            : _T.textTertiary,
                        height: 1,
                      ),
                      child: const Text('\$'),
                    ),
                  ),

                  // Input de monto
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
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
                        if (double.tryParse(v.replaceAll(',', '.')) == null) {
                          return '';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              // Línea divisoria animada — la única decoración "activa"
              AnimatedContainer(
                duration: _T.mid,
                curve: _T.curve,
                height: 1.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _amountHasValue
                        ? [_typeColor.withOpacity(0.8), Colors.transparent]
                        : [_T.border, Colors.transparent],
                    stops: const [0.0, 1.0],
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

  // ── SELECTOR DE TIPO ─────────────────────────────────────────────────────────
  // Dos opciones. Sin iconos excesivos. Solo texto con color semántico.
  Widget _buildTypeToggle() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _T.surfaceRaised,
        borderRadius: BorderRadius.circular(_T.rMD),
        border: Border.all(color: _T.border, width: 0.5),
      ),
      child: Row(
        children: [
          _TypeSegment(
            label: 'Gasto',
            selected: _isExpense,
            selectedColor: _T.expenseColor,
            selectedBg: _T.expenseDim,
            onTap: () {
              if (!_isExpense) {
                HapticFeedback.selectionClick();
                setState(() {
                  _transactionType = 'Gasto';
                  _selectedCategory = null;
                  _selectedBudgetId = null;
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
                  _transactionType = 'Ingreso';
                  _selectedCategory = null;
                  _selectedBudgetId = null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // ── CUENTA ───────────────────────────────────────────────────────────────────
  Widget _buildAccountSection() {
    return _Section(
      label: 'Cuenta',
      child: FutureBuilder<List<Account>>(
        future: _accountsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _ShimmerRow();
          }
          final accounts = snapshot.data ?? [];
          if (accounts.isEmpty) {
            return const _EmptyHint(text: 'Crea una cuenta primero');
          }
          final currencyFmt = NumberFormat.currency(
              locale: 'es_CO', symbol: '\$', decimalDigits: 0);

          return DropdownButtonFormField<String>(
            value: _selectedAccountId,
            dropdownColor: _T.surfaceRaised,
            style: const TextStyle(
              color: _T.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            icon: const Icon(Icons.unfold_more_rounded,
                color: _T.textSecondary, size: 18),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: _T.md, vertical: 14),
              hintText: 'Selecciona una cuenta',
              hintStyle: TextStyle(color: _T.textSecondary, fontSize: 15),
            ),
            items: accounts.map((a) {
              final positive = a.balance >= 0;
              return DropdownMenuItem<String>(
                value: a.id,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: positive ? _T.incomeColor : _T.expenseColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _T.textPrimary),
                      ),
                    ),
                    Text(
                      currencyFmt.format(a.balance),
                      style: TextStyle(
                        fontSize: 13,
                        color: positive ? _T.incomeColor : _T.expenseColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              setState(() => _selectedAccountId = v);
            },
            validator: (v) => v == null ? '' : null,
          );
        },
      ),
    );
  }

  // ── FECHA ────────────────────────────────────────────────────────────────────
  Widget _buildDateSection() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final label = isToday
        ? 'Hoy'
        : DateFormat.yMMMd('es_CO').format(_selectedDate);

    return _Section(
      label: 'Fecha',
      child: _TappableRow(
        onTap: _selectDate,
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isToday ? _T.accent : _T.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: _T.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }

  // ── CATEGORÍAS ────────────────────────────────────────────────────────────────
  // Chips limpios. Sin bordes dobles. Selección clara.
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
          final all = catSnap.data ?? [];
          final type = _isExpense ? 'expense' : 'income';
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

  // ── ESTADO DE ÁNIMO ───────────────────────────────────────────────────────────
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

  // ── DESCRIPCIÓN ───────────────────────────────────────────────────────────────
  Widget _buildDescriptionSection() {
    return _Section(
      label: 'Nota  ·  Opcional',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_T.md, 0, _T.md, _T.md),
        child: TextField(
          controller: _descriptionController,
          maxLines: 3,
          style: const TextStyle(
            color: _T.textPrimary,
            fontSize: 15,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: 'Añade una nota...',
            hintStyle: TextStyle(color: _T.textTertiary.withOpacity(0.8)),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  // ── UBICACIÓN ─────────────────────────────────────────────────────────────────
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
              _selectedLat = result['lat'];
              _selectedLng = result['lng'];
            });
          }
        },
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasLocation ? _selectedLocationName! : 'Buscar lugar',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: hasLocation ? _T.textPrimary : _T.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: _T.sm),
            // GPS — botón secundario dentro de la fila
            if (_isFetchingLocation)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _T.accent,
                ),
              )
            else
              GestureDetector(
                onTap: _getCurrentLocation,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _T.xs),
                  child: Icon(
                    Iconsax.gps,
                    size: 18,
                    color: hasLocation ? _T.accent : _T.textTertiary,
                  ),
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
          ],
        ),
      ),
    );
  }

  // ── BOTÓN GUARDAR ─────────────────────────────────────────────────────────────
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
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: Colors.white,
                  ),
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

/// Sección con label y contenedor de superficie — el patrón base de la UI.
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
        // Label de sección — pequeño, discreto, informativo
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

        // Contenedor de la sección
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _T.surfaceRaised,
            borderRadius: BorderRadius.circular(_T.rMD),
            border: Border.all(color: _T.borderSubtle, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ],
    );
  }
}

/// Fila tappable con feedback de prensa sutil.
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
        color: _pressing
            ? _T.surfaceHighest
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: _T.md, vertical: 14),
        child: widget.child,
      ),
    );
  }
}

/// Chip de categoría — sin ruido, solo color e ícono cuando está seleccionada.
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(category.icon ?? Iconsax.category,
                  size: 14, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              category.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? color : _T.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de estado de ánimo.
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
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? _T.accent.withOpacity(0.12)
              : _T.surfaceHighest,
          borderRadius: BorderRadius.circular(_T.rSM + 4),
          border: Border.all(
            color: selected ? _T.accent.withOpacity(0.5) : _T.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(mood.icon,
                size: 14,
                color: selected ? _T.accent : _T.textSecondary),
            const SizedBox(width: 6),
            Text(
              mood.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? _T.accent : _T.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmento del tipo de transacción.
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
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? selectedColor : _T.textSecondary,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

/// Botón ícono — minimalista.
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
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

/// Hint de estado vacío dentro de una sección.
class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_T.md),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, color: _T.textSecondary),
      ),
    );
  }
}

/// Shimmer placeholder mientras cargan datos.
class _ShimmerRow extends StatefulWidget {
  const _ShimmerRow();

  @override
  State<_ShimmerRow> createState() => _ShimmerRowState();
}

class _ShimmerRowState extends State<_ShimmerRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_T.md),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          height: 16,
          width: 120,
          decoration: BoxDecoration(
            color: Color.lerp(
                _T.surfaceHighest, _T.border, _anim.value),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Animación de entrada: fade + slide hacia arriba. Stagger por delay.
class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay; // en milisegundos

  const _FadeSlide({required this.child, required this.delay});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: _T.slow, vsync: this);
    _opacity =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}