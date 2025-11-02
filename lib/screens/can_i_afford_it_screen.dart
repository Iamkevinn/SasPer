// lib/screens/can_i_afford_it_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart'; // <<< PASO 1: Importar
import 'package:sasper/data/budget_repository.dart'; // <<< PASO 1: Importar
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/simulation_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/simulation_models.dart';
import 'package:sasper/screens/simulation_result_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class CanIAffordItScreen extends StatefulWidget {
  const CanIAffordItScreen({super.key});

  @override
  State<CanIAffordItScreen> createState() => _CanIAffordItScreenState();
}

class _CanIAffordItScreenState extends State<CanIAffordItScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  // --- PASO 1: Instanciar los repositorios necesarios ---
  final SimulationRepository _simulationRepo = SimulationRepository.instance;
  final CategoryRepository _categoryRepo = CategoryRepository.instance;
  final AccountRepository _accountRepo = AccountRepository.instance;
  final BudgetRepository _budgetRepo = BudgetRepository.instance;

  Category? _selectedCategory;
  bool _isLoading = false; // Para el botón de simulación
  bool _showInsights = false;
  late Future<List<Category>> _categoriesFuture;

  // --- PASO 2: Añadir estados para la carga y los datos financieros ---
  bool _isFinancialDataLoading = true; // Controla la carga inicial de datos
  String _financialDataError = ''; // Almacena un mensaje de error si la carga falla

  // Datos de simulación en tiempo real (inicializados en 0)
  double _currentAmount = 0.0;
  // --- Se eliminan los datos simulados ---
  double _availableBalance = 0.0;
  double _monthlyBudget = 0.0;
  double _spentThisMonth = 0.0;

  RiskLevel _currentRisk = RiskLevel.safe;

  // Animación controllers
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late AnimationController _scaleController;


  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepo.getExpenseCategories();

    // --- PASO 3: Cargar los datos financieros al iniciar la pantalla ---
    _loadFinancialData();

    // El resto de la inicialización...
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _amountController.addListener(_onAmountChanged);
  }

  // --- PASO 3: Método para cargar los datos financieros reales ---
  Future<void> _loadFinancialData() async {
    try {
      // Usamos Future.wait para ejecutar ambas llamadas a la API en paralelo
      final results = await Future.wait([
        _accountRepo.getAccounts(), // Llama al repo de cuentas
        _budgetRepo.getOverallBudgetSummary(), // Llama al repo de presupuestos
      ]);

      // Procesamos los resultados de las cuentas
      final accounts = results[0] as List<dynamic>;
      final totalBalance = accounts.fold<double>(
          0.0, (sum, account) => sum + account.balance);

      // Procesamos el resumen del presupuesto
      // Asumimos que `getOverallBudgetSummary` devuelve un objeto con `totalBudget` y `totalSpent`
      final budgetSummary = results[1] as (double, double);

      if (mounted) {
        setState(() {
          _availableBalance = totalBalance;
          _monthlyBudget = budgetSummary.$1;
          _spentThisMonth = budgetSummary.$2;
          _isFinancialDataLoading = false; // Datos cargados, ocultar loading
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _financialDataError = 'Error al cargar los datos financieros.';
          _isFinancialDataLoading = false; // Ocultar loading incluso si hay error
        });
      }
    }
  }


  @override
  void dispose() {
    _amountController.dispose();
    _pulseController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    final text = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(text) ?? 0.0;

    setState(() {
      _currentAmount = amount;
      _showInsights = amount > 0;
      // Asegurarse de que el presupuesto no sea cero para evitar división por cero
      if (_monthlyBudget > 0) {
        _currentRisk = _calculateRisk(amount);
      }
    });

    if (_showInsights) {
      _slideController.forward();
      _scaleController.forward(from: 0);
    } else {
      _slideController.reverse();
    }
  }

  RiskLevel _calculateRisk(double amount) {
    if (_monthlyBudget <= 0) return RiskLevel.safe; // Valor por defecto si no hay presupuesto
    
    final remaining = _availableBalance - amount;
    final percentOfBudget = (amount / _monthlyBudget) * 100;

    if (remaining < 0 || percentOfBudget > 50) return RiskLevel.high;
    if (percentOfBudget > 25 || remaining < _monthlyBudget * 0.2) {
      return RiskLevel.moderate;
    }
    return RiskLevel.safe;
  }

  Future<void> _runSimulation() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      NotificationHelper.show(
        message: 'Por favor, completa todos los campos.',
        type: NotificationType.error,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.replaceAll(',', '.'));
      final categoryName = _selectedCategory!.name;

      final SimulationResult result =
          await _simulationRepo.getExpenseSimulation(
        amount: amount,
        categoryName: categoryName,
      );

      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SimulationResultScreen(result: result),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
          message: e.toString().replaceFirst("Exception: ", ""),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- PASO 4: Mostrar UI de carga o de contenido ---
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isFinancialDataLoading
          ? Center(child: CircularProgressIndicator()) // UI de Carga
          : _financialDataError.isNotEmpty
              ? Center(child: Text(_financialDataError)) // UI de Error
              : _buildContent(theme, colorScheme), // UI Principal
    );
  }

  // Se extrajo el contenido principal a su propio método para mayor claridad
  Widget _buildContent(ThemeData theme, ColorScheme colorScheme) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAppBar(theme, colorScheme),
        SliverToBoxAdapter(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildAIHeader(theme, colorScheme),
                const SizedBox(height: 24),
                _buildBalanceOverview(theme, colorScheme),
                const SizedBox(height: 32),
                _buildAmountInput(theme, colorScheme),
                const SizedBox(height: 20),
                _buildCategorySelector(theme, colorScheme),
                if (_showInsights) ...[
                  const SizedBox(height: 32),
                  _buildRealTimeInsights(theme, colorScheme),
                  const SizedBox(height: 24),
                  _buildImpactIndicator(theme, colorScheme),
                  const SizedBox(height: 24),
                  _buildAIRecommendations(theme, colorScheme),
                ],
                const SizedBox(height: 32),
                _buildAnalyzeButton(theme, colorScheme),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- El resto de los widgets (_buildAppBar, etc.) no necesitan cambios ---
  // ... (Pega aquí el resto de tus métodos _build... sin modificarlos) ...
  // ... por brevedad, no se repiten aquí. Asegúrate de tenerlos en tu archivo.

  //<editor-fold desc="Widgets de la UI (sin cambios)">
  Widget _buildAppBar(ThemeData theme, ColorScheme colorScheme) {
    return SliverAppBar.large(
      floating: true,
      pinned: false,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left, color: colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        title: Text(
          '¿Me lo puedo permitir?',
          style: GoogleFonts.manrope(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildAIHeader(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.4),
            colorScheme.secondaryContainer.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.1),
                  child: Icon(
                    Iconsax.cpu,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Simulación Inteligente',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'IA analizando tu impacto financiero en tiempo real',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: colorScheme.onSurface.withOpacity(0.6),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceOverview(ThemeData theme, ColorScheme colorScheme) {
    // Evitar división por cero si el presupuesto es 0
    final progressValue = (_monthlyBudget > 0) ? _spentThisMonth / _monthlyBudget : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Saldo Disponible',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      color: colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '\$${_availableBalance.toStringAsFixed(2)}',
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.trend_up,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '+12%', // Este dato aún es estático, podrías conectarlo luego
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gastado este mes',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Text(
                '\$${_spentThisMonth.toStringAsFixed(0)} / \$${_monthlyBudget.toStringAsFixed(0)}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Monto del gasto',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _showInsights
                    ? colorScheme.primary.withOpacity(0.3)
                    : colorScheme.outline.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.manrope(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 12),
                  child: Icon(
                    Iconsax.dollar_circle,
                    color: colorScheme.primary,
                    size: 28,
                  ),
                ),
                hintText: '0.00',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface.withOpacity(0.3),
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa un monto';
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) return 'Monto inválido';
                return null;
              },
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickAmounts(colorScheme),
        ],
      ),
    );
  }

  Widget _buildQuickAmounts(ColorScheme colorScheme) {
    final amounts = [
      (_availableBalance * 0.1, '10%'),
      (_availableBalance * 0.25, '25%'),
      (_availableBalance * 0.5, '50%'),
    ];

    return Row(
      children: amounts.map((data) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                _amountController.text = data.$1.toStringAsFixed(2);
                HapticFeedback.selectionClick();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      data.$2,
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${data.$1.toStringAsFixed(0)}',
                      style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategorySelector(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Categoría del gasto',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Category>>(
            future: _categoriesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  snapshot.data!.isEmpty) {
                return const Text('No se pudieron cargar las categorías.');
              }

              final categories = snapshot.data!;
              return Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedCategory != null
                        ? colorScheme.primary.withOpacity(0.3)
                        : colorScheme.outline.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: DropdownButtonFormField<Category>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 20, right: 12),
                      child: Icon(
                        Iconsax.category,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                    ),
                    hintText: 'Selecciona una categoría',
                    hintStyle: GoogleFonts.manrope(
                      color: colorScheme.onSurface.withOpacity(0.4),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                  ),
                  dropdownColor: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  icon: Icon(
                    Iconsax.arrow_down_1,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                  items: categories.map((Category category) {
                    return DropdownMenuItem<Category>(
                      value: category,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: category.colorAsObject.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              category.icon,
                              color: category.colorAsObject,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            category.name,
                            style: GoogleFonts.manrope(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() => _selectedCategory = newValue);
                    HapticFeedback.selectionClick();
                  },
                  validator: (value) =>
                      value == null ? 'Selecciona una categoría' : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRealTimeInsights(ThemeData theme, ColorScheme colorScheme) {
    final remaining = _availableBalance - _currentAmount;
    final percentage = _monthlyBudget > 0 ? (_currentAmount / _monthlyBudget * 100).clamp(0, 100) : 0.0;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: _slideController,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _currentRisk.color.withOpacity(0.1),
                _currentRisk.color.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _currentRisk.color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _currentRisk.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _currentRisk.icon,
                      color: _currentRisk.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentRisk.title,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentRisk.subtitle,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildInsightCard(
                      'Te quedarían',
                      '\$${remaining.toStringAsFixed(2)}',
                      Iconsax.wallet_3,
                      colorScheme,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInsightCard(
                      'Del presupuesto',
                      '${percentage.toStringAsFixed(1)}%',
                      Iconsax.percentage_circle,
                      colorScheme,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard(
    String label,
    String value,
    IconData icon,
    ColorScheme colorScheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpactIndicator(ThemeData theme, ColorScheme colorScheme) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutBack,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Column(
          children: [
            Text(
              'Indicador de Impacto',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
              child: CustomPaint(
                painter: _ImpactGaugePainter(
                  progress: _availableBalance > 0
                      ? (_currentAmount / _availableBalance).clamp(0.0, 1.0)
                      : 0.0,
                  color: _currentRisk.color,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _availableBalance > 0
                            ? '${((_currentAmount / _availableBalance) * 100).clamp(0, 100).toStringAsFixed(0)}%'
                            : '0%',
                        style: GoogleFonts.manrope(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: _currentRisk.color,
                        ),
                      ),
                      Text(
                        'de tu saldo',
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIRecommendations(ThemeData theme, ColorScheme colorScheme) {
    final recommendations = _getRecommendations();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Iconsax.lamp_charge,
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Recomendaciones IA',
                style: GoogleFonts.manrope(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return Container(
                width: 260,
                margin: EdgeInsets.only(
                  right: index < recommendations.length - 1 ? 12 : 0,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rec.color.withOpacity(0.1),
                      rec.color.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: rec.color.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: rec.color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            rec.icon,
                            color: rec.color,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rec.title,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      rec.description,
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: colorScheme.onSurface.withOpacity(0.7),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<AIRecommendation> _getRecommendations() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_currentRisk == RiskLevel.safe) {
      return [
        AIRecommendation(
          title: 'Gasto Saludable',
          description:
              'Este gasto encaja perfectamente con tus hábitos financieros inteligentes. Tu dinero está trabajando contigo.',
          icon: Iconsax.verify,
          color: Colors.green,
        ),
        AIRecommendation(
          title: 'Ahorro Protegido',
          description:
              'Mantienes \$${(_availableBalance - _currentAmount).toStringAsFixed(0)} disponible. Tus metas de ahorro siguen intactas.',
          icon: Iconsax.shield_tick,
          color: colorScheme.primary,
        ),
        AIRecommendation(
          title: 'Continúa Así',
          description:
              'Con este ritmo, alcanzarás tus objetivos financieros 2 semanas antes de lo planeado.',
          icon: Iconsax.chart_success,
          color: Colors.blue,
        ),
      ];
    } else if (_currentRisk == RiskLevel.moderate) {
      return [
        AIRecommendation(
          title: 'Precaución Moderada',
          description:
              'Este gasto es posible, pero considera reducir gastos variables en los próximos días.',
          icon: Iconsax.warning_2,
          color: Colors.orange,
        ),
        AIRecommendation(
          title: 'Alternativa Inteligente',
          description:
              'Si esperas 5 días, tu flujo de caja será 23% más saludable para este gasto.',
          icon: Iconsax.calendar_tick,
          color: colorScheme.primary,
        ),
        AIRecommendation(
          title: 'Balance Ajustado',
          description:
              'Podrías cubrir este gasto reduciendo 15% en entretenimiento esta semana.',
          icon: Iconsax.status_up,
          color: Colors.teal,
        ),
      ];
    } else {
      return [
        AIRecommendation(
          title: 'Riesgo Detectado',
          description:
              'Este gasto comprometería tus metas críticas. Considera alternativas o posponerlo.',
          icon: Iconsax.danger,
          color: Colors.red,
        ),
        AIRecommendation(
          title: 'Impacto en Metas',
          description:
              'Afectaría tu objetivo de ahorro para "Fondo de Emergencia" en 3 semanas.',
          icon: Iconsax.flag,
          color: Colors.deepOrange,
        ),
        AIRecommendation(
          title: 'Plan B Sugerido',
          description:
              'Te recomendamos reducir el monto a \$${(_availableBalance * 0.25).toStringAsFixed(0)} para mantener estabilidad.',
          icon: Iconsax.star_1,
          color: colorScheme.primary,
        ),
      ];
    }
  }

  Widget _buildAnalyzeButton(ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _runSimulation,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: _isLoading
                  ? LinearGradient(
                      colors: [
                        colorScheme.primary.withOpacity(0.5),
                        colorScheme.primary.withOpacity(0.3),
                      ],
                    )
                  : LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isLoading
                  ? []
                  : [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isLoading)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
                    ),
                  )
                else ...[
                  Icon(
                    Iconsax.cpu,
                    color: colorScheme.onPrimary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Analizar con IA',
                    style: GoogleFonts.manrope(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
  //</editor-fold>
}


// --- El resto de las clases (RiskLevel, AIRecommendation, _ImpactGaugePainter) no cambian ---
// ... (Pega aquí el resto de tus clases auxiliares sin modificarlas) ...

//<editor-fold desc="Clases auxiliares (sin cambios)">
enum RiskLevel {
  safe(
    'Gasto Seguro',
    'Este gasto no compromete tus finanzas',
    Colors.green,
    Iconsax.shield_tick,
  ),
  moderate(
    'Precaución Moderada',
    'Posible con ajustes en otros gastos',
    Colors.orange,
    Iconsax.warning_2,
  ),
  high(
    'Riesgo Alto',
    'Podría afectar tus objetivos financieros',
    Colors.red,
    Iconsax.danger,
  );

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const RiskLevel(this.title, this.subtitle, this.color, this.icon);
}

class AIRecommendation {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  AIRecommendation({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _ImpactGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ImpactGaugePainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 10;
    const startAngle = math.pi;
    const sweepAngle = math.pi;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    final progressPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withOpacity(0.6), color],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle * progress,
      false,
      progressPaint,
    );

    if (progress > 0) {
      final glowPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ImpactGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
//</editor-fold>