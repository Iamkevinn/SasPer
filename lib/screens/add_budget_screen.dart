import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:developer' as developer;
import 'package:sasper/data/analysis_repository.dart'; // <-- CAMBIO: Añadir importación
import 'package:sasper/models/analysis_models.dart';

import 'package:sasper/widgets/shared/custom_notification_widget.dart';

enum Periodicity { weekly, monthly, custom }

enum FinancialHealth { critical, medium, high }

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen>
    with TickerProviderStateMixin {
  final BudgetRepository _budgetRepository = BudgetRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '0');
  late ConfettiController _confettiController;
  late AnimationController _successAnimController;
  late AnimationController _pulseController;
  final AnalysisRepository _analysisRepository = AnalysisRepository.instance;

  Category? _selectedCategory;
  Periodicity _selectedPeriodicity = Periodicity.monthly;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  bool _isLoading = false;
  bool _isSuccess = false;

  // --- VARIABLES DE ESTADO PARA DATOS REALES ---
  AnalysisData?
      _analysisData; // <-- NUEVO: Almacenará todos los datos de análisis
  double _realHistoricalAvgForCategory =
      0.0; // <-- NUEVO: Promedio para la categoría seleccionada
  bool _isDataLoading =
      true; // <-- NUEVO: Para controlar el estado de carga inicial

  late Future<List<Category>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepository.getExpenseCategories();
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 2));
    _successAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadAnalysisData();
    _calculateDatesForPeriodicity(Periodicity.monthly);
    _amountController.addListener(() => setState(() {}));
  }

  // <-- NUEVO: Método para cargar los datos de análisis una sola vez -->
  Future<void> _loadAnalysisData() async {
    // Llama al método que ya tienes, que es súper eficiente.
    final data = await _analysisRepository.fetchAllAnalysisData();
    if (mounted) {
      setState(() {
        _analysisData = data;
        _isDataLoading = false;
      });
    }
  }

  // <-- CAMBIO: Modificamos el método que se ejecuta al seleccionar una categoría -->
  void _onCategorySelected(Category category) {
    HapticFeedback.mediumImpact();

    // Cerramos el selector
    Navigator.pop(context);

    // Buscamos el promedio en los datos que ya tenemos cargados
    double foundAverage = 0.0;
    if (_analysisData != null) {
      final categoryAverage = _analysisData!.categoryAverages.firstWhere(
        (avg) => avg.categoryName == category.name,
        orElse: () =>
            const CategoryAverageResult(categoryName: '', averageAmount: 0),
      );
      foundAverage = categoryAverage.averageAmount;
    }

    setState(() {
      _selectedCategory = category;
      _realHistoricalAvgForCategory = foundAverage;
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _confettiController.dispose();
    _successAnimController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _calculateDatesForPeriodicity(Periodicity period) {
    final now = DateTime.now();
    setState(() {
      _selectedPeriodicity = period;
      if (period == Periodicity.weekly) {
        _startDate = now.subtract(Duration(days: now.weekday - 1));
        _endDate = now.add(Duration(days: DateTime.daysPerWeek - now.weekday));
      } else if (period == Periodicity.monthly) {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = DateTime(now.year, now.month + 1, 0);
      }
    });
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Colors.transparent,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _saveBudget() async {
    HapticFeedback.mediumImpact();

    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    if (_selectedCategory == null) {
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Por favor, selecciona una categoría.',
          type: NotificationType.error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await Future.delayed(
          const Duration(milliseconds: 800)); // Simular guardado

      await _budgetRepository.addBudget(
        categoryName: _selectedCategory!.name,
        amount: double.parse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')),
        startDate: _startDate,
        endDate: _endDate,
        periodicity: _selectedPeriodicity.name,
      );

      if (mounted) {
        setState(() => _isSuccess = true);
        HapticFeedback.heavyImpact();
        _successAnimController.forward();
        _confettiController.play();
        EventService.instance.fire(AppEvent.budgetsChanged);

        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
              message: '¡Presupuesto creado con éxito! 🎉',
              type: NotificationType.success);
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR PRESUPUESTO: $e',
          name: 'AddBudgetScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al crear presupuesto.',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🤖 IA: Cálculo de salud financiera
FinancialHealth _calculateFinancialHealth(double amount, double averageMonthlyFlow) { // <-- CAMBIO: Añadimos un parámetro
  // Prevenimos una división por cero si el usuario no tiene historial.
  if (averageMonthlyFlow <= 0) {
    return FinancialHealth.high; // Un presupuesto sin historial de gastos es "saludable" por defecto.
  }
  
  final percentage = (amount / averageMonthlyFlow) * 100; // <-- CAMBIO: Usamos el parámetro con datos reales
  
  if (percentage > 40) return FinancialHealth.critical;
  if (percentage > 20) return FinancialHealth.medium;
  return FinancialHealth.high;
}

  @override
  Widget build(BuildContext context) {
    final double amount = double.tryParse(
            _amountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    final double realAvgMonthlySpending =
        _analysisData?.monthlyAverage.averageSpending ?? 0.0;

    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: true,
          body: CustomScrollView(
            slivers: [
              _buildGlassAppBar(),
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeroSummaryCardDelegate(
                  category: _selectedCategory,
                  amount: amount,
                  periodicity: _selectedPeriodicity,
                  startDate: _startDate,
                  endDate: _endDate,
                  pulseController: _pulseController,
                ),
              ),
              SliverToBoxAdapter(
                child: _isDataLoading
                    ? const Center(child: Padding(padding: EdgeInsets.all(40.0), child: CircularProgressIndicator())) // <-- NUEVO: Loader inicial
                : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),

                        // 🤖 IA INSIGHT CARD
                        _AIInsightCard(
                          amount: amount,
                          // Usamos el gasto promedio real como base para el análisis
                          avgIncome: realAvgMonthlySpending > 0
                              ? realAvgMonthlySpending
                              : 1.0, // <-- DATO REAL
                          historicalAvg: _realHistoricalAvgForCategory,
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Periodicidad',
                            'Elige la frecuencia de tu presupuesto.'),
                        const SizedBox(height: 16),
                        _buildPeriodicitySelector(),

                        AnimatedSize(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          child: _selectedPeriodicity == Periodicity.custom
                              ? _buildCustomDateSelector()
                                  .animate()
                                  .fadeIn(duration: 300.ms)
                                  .slideY(begin: -0.1)
                              : const SizedBox.shrink(),
                        ),

                        const SizedBox(height: 32),
                        _buildSectionHeader('Categoría',
                            'Selecciona la categoría a presupuestar.'),
                        const SizedBox(height: 16),
                        _buildCategorySelector(),

                        const SizedBox(height: 32),
                        _buildSectionHeader(
                            'Monto', 'Define el límite para este período.'),
                        const SizedBox(height: 16),
                        _AmountInputField(controller: _amountController),

                        const SizedBox(height: 24),

                        // 🎯 BARRA DE PROGRESO INTELIGENTE
                        _FinancialHealthBar(
                          amount: amount,
                          health: _calculateFinancialHealth(amount,realAvgMonthlySpending),
                        ).animate().fadeIn(delay: 300.ms),

                        const SizedBox(height: 32),
                        _ImpactPreviewCard(
                          amount: amount,
                          avgSpending: _realHistoricalAvgForCategory,
                        ),

                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
        _buildAdaptiveSaveButton(),
        _ConfettiCelebration(
          controller: _confettiController,
          category: _selectedCategory,
        ),
      ],
    );
  }

  // --- GLASSMORPHISM APP BAR ---
  Widget _buildGlassAppBar() {
    return SliverAppBar.large(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface.withOpacity(0.7),
                  Theme.of(context).colorScheme.surface.withOpacity(0.5),
                ],
              ),
            ),
            child: FlexibleSpaceBar(
              title: Text(
                'Nuevo Presupuesto',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                ),
              ),
              centerTitle: false,
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Iconsax.info_circle),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showHelpDialog();
          },
          tooltip: '¿Qué es un presupuesto?',
        )
      ],
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('💡 Presupuestos Inteligentes',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Un presupuesto es tu aliado para mantener el control financiero. '
          'La IA de Sasper analiza tus patrones y te sugiere montos saludables basados en tus ingresos.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style:
                GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14)),
      ],
    );
  }

  Widget _buildPeriodicitySelector() {
    return Row(
      children: Periodicity.values.map((period) {
        return Expanded(
          child: _PeriodicityPill(
            label: period.name
                .replaceFirst(period.name[0], period.name[0].toUpperCase()),
            icon: period == Periodicity.weekly
                ? Iconsax.calendar_1
                : period == Periodicity.monthly
                    ? Iconsax.calendar
                    : Iconsax.setting_4,
            isSelected: _selectedPeriodicity == period,
            onTap: () {
              HapticFeedback.selectionClick();
              _calculateDatesForPeriodicity(period);
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomDateSelector() {
    final dateFormat = DateFormat.yMMMd('es_CO');
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: InkWell(
        onTap: _selectDateRange,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                Theme.of(context).colorScheme.surfaceContainer,
              ],
            ),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Iconsax.calendar_edit, size: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
                    style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              Icon(Iconsax.arrow_right_3,
                  color: Theme.of(context).colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return FutureBuilder<List<Category>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            _showCategoryPicker(snapshot.data ?? []);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  (_selectedCategory?.colorAsObject ??
                          Theme.of(context).colorScheme.primary)
                      .withOpacity(0.05),
                  Theme.of(context).colorScheme.surfaceContainer,
                ],
              ),
              border: Border.all(
                color: _selectedCategory?.colorAsObject.withOpacity(0.3) ??
                    Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_selectedCategory?.colorAsObject ??
                            Theme.of(context).colorScheme.primary)
                        .withOpacity(0.1),
                  ),
                  child: Icon(
                    _selectedCategory?.icon ?? Iconsax.category,
                    color: _selectedCategory?.colorAsObject ??
                        Theme.of(context).colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _selectedCategory?.name ?? 'Selecciona una categoría',
                    style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: _selectedCategory != null
                            ? FontWeight.w600
                            : FontWeight.normal),
                  ),
                ),
                Icon(Iconsax.arrow_down_1,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryPicker(List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return _CategoryPickerSheet(
              categories: categories,
              scrollController: controller,
              // Usamos el nuevo método centralizado
              onCategorySelected: _onCategorySelected,
            );
          },
        );
      },
    );
  }

  // 🚀 BOTÓN ADAPTIVO CON ANIMACIONES AVANZADAS
  Widget _buildAdaptiveSaveButton() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: AnimatedBuilder(
          animation: _successAnimController,
          builder: (context, child) {
            return Transform.scale(
              scale:
                  _isSuccess ? 1.0 + (_successAnimController.value * 0.1) : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
                width: _isLoading ? 64 : double.infinity,
                height: 64,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_isLoading ? 32 : 20),
                  gradient: LinearGradient(
                    colors: _isSuccess
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [
                            Theme.of(context).colorScheme.primary,
                            Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.8),
                          ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isSuccess
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: (_isLoading || _isSuccess) ? null : _saveBudget,
                    borderRadius: BorderRadius.circular(_isLoading ? 32 : 20),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _isLoading
                            ? const SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : _isSuccess
                                ? const Icon(Iconsax.tick_circle5,
                                    color: Colors.white, size: 32)
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Iconsax.save_2,
                                          color: Colors.white, size: 24),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Crear Presupuesto',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ).animate().slideY(
        begin: 2,
        end: 0,
        delay: 500.ms,
        duration: 600.ms,
        curve: Curves.easeOutCubic);
  }
}

// =============================================================================
// 🤖 WIDGETS INTELIGENTES CON IA
// =============================================================================

class _AIInsightCard extends StatelessWidget {
  final double amount;
  final double avgIncome;
  final double historicalAvg;

  const _AIInsightCard({
    required this.amount,
    required this.avgIncome,
    required this.historicalAvg,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (amount / avgIncome) * 100;
    final suggestedMin = avgIncome * 0.14;
    final suggestedMax = avgIncome * 0.20;

    String message;
    IconData icon;
    Color color;

    if (amount == 0) {
      message =
          '💡 La IA sugiere: Entre ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(suggestedMin)} y ${NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(suggestedMax)} es saludable para tus ingresos';
      icon = Iconsax.lamp_on5;
      color = Theme.of(context).colorScheme.primary;
    } else if (percentage > 40) {
      message =
          '⚠️ Este presupuesto representa el ${percentage.toStringAsFixed(0)}% de tus ingresos. Considera reducirlo para mantener balance';
      icon = Iconsax.warning_25;
      color = Colors.orange;
    } else if (percentage > 25) {
      message =
          '👍 Presupuesto moderado (${percentage.toStringAsFixed(0)}% de ingresos). Estás construyendo estabilidad financiera';
      icon = Iconsax.shield_tick5;
      color = Colors.blue;
    } else {
      message =
          '🚀 ¡Excelente decisión! Este presupuesto te acerca a tus metas de independencia financiera';
      icon = Iconsax.medal_star5;
      color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.03),
          ],
        ),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Análisis de IA',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialHealthBar extends StatelessWidget {
  final double amount;
  final FinancialHealth health;

  const _FinancialHealthBar({
    required this.amount,
    required this.health,
  });

  @override
  Widget build(BuildContext context) {
    Color healthColor;
    String healthLabel;

    switch (health) {
      case FinancialHealth.critical:
        healthColor = Colors.red;
        healthLabel = 'Crítico';
        break;
      case FinancialHealth.medium:
        healthColor = Colors.orange;
        healthLabel = 'Moderado';
        break;
      case FinancialHealth.high:
        healthColor = Colors.green;
        healthLabel = 'Saludable';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Salud Financiera',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: healthColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: healthColor.withOpacity(0.3)),
              ),
              child: Text(
                healthLabel,
                style: GoogleFonts.inter(
                  color: healthColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            value: health == FinancialHealth.high
                ? 0.9
                : health == FinancialHealth.medium
                    ? 0.6
                    : 0.3,
            minHeight: 12,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            valueColor: AlwaysStoppedAnimation<Color>(healthColor),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HERO CARD CON GLASSMORPHISM
// =============================================================================

class _HeroSummaryCardDelegate extends SliverPersistentHeaderDelegate {
  final Category? category;
  final double amount;
  final Periodicity periodicity;
  final DateTime startDate;
  final DateTime endDate;
  final AnimationController pulseController;

  _HeroSummaryCardDelegate({
    required this.category,
    required this.amount,
    required this.periodicity,
    required this.startDate,
    required this.endDate,
    required this.pulseController,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$ ', decimalDigits: 0);
    final dateFormat = DateFormat('d MMM', 'es_CO');

    return ClipRRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.surface.withOpacity(0.9),
                colorScheme.surface.withOpacity(0.7),
              ],
            ),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (pulseController.value * 0.05),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            (category?.colorAsObject ?? colorScheme.primary)
                                .withOpacity(0.2),
                            (category?.colorAsObject ?? colorScheme.primary)
                                .withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color:
                              (category?.colorAsObject ?? colorScheme.primary)
                                  .withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        category?.icon ?? Iconsax.category_2,
                        size: 32,
                        color: category?.colorAsObject ?? colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      currencyFormat.format(amount),
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${periodicity.name.toUpperCase()} • ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                      style: GoogleFonts.inter(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 90.0;

  @override
  double get minExtent => 90.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}

// =============================================================================
// PILLS CON MICROINTERACCIONES
// =============================================================================

class _PeriodicityPill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodicityPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PeriodicityPill> createState() => _PeriodicityPillState();
}

class _PeriodicityPillState extends State<_PeriodicityPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: GestureDetector(
        onTapDown: (_) => _bounceController.forward(),
        onTapUp: (_) {
          _bounceController.reverse();
          widget.onTap();
        },
        onTapCancel: () => _bounceController.reverse(),
        child: AnimatedBuilder(
          animation: _bounceAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _bounceAnimation.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: widget.isSelected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.primaryContainer.withOpacity(0.7),
                          ],
                        )
                      : null,
                  color:
                      widget.isSelected ? null : colorScheme.surfaceContainer,
                  border: Border.all(
                    color: widget.isSelected
                        ? colorScheme.primary.withOpacity(0.5)
                        : colorScheme.outlineVariant.withOpacity(0.3),
                    width: widget.isSelected ? 2 : 1,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    Icon(
                      widget.icon,
                      color: widget.isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 28,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.label,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: widget.isSelected
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// =============================================================================
// AMOUNT INPUT
// =============================================================================

class _AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountInputField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(
        fontSize: 56,
        fontWeight: FontWeight.bold,
        color: colorScheme.primary,
        letterSpacing: -2,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        _CurrencyInputFormatter()
      ],
      decoration: InputDecoration(
        border: InputBorder.none,
        hintText: '\$ 0',
        hintStyle: GoogleFonts.poppins(
          fontSize: 56,
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface.withOpacity(0.15),
          letterSpacing: -2,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Ingresa un monto';
        final amount = int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
        if (amount == null || amount <= 0) return 'Ingresa un monto válido';
        return null;
      },
      onChanged: (_) => HapticFeedback.selectionClick(),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');

    final number =
        int.tryParse(newValue.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final format =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final newText = format.format(number);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// =============================================================================
// IMPACT PREVIEW
// =============================================================================

class _ImpactPreviewCard extends StatelessWidget {
  final double amount;
  final double avgSpending;
  const _ImpactPreviewCard({
    required this.amount,
    required this.avgSpending,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = avgSpending > 0 ? (amount / avgSpending) * 100 : 0;
    final isHigh = percentage > 120;
    final isLow = percentage < 80;

    String message;
    IconData icon;
    Color color;

    if (amount == 0) {
      message = 'Define un monto para ver el impacto en tus finanzas';
      icon = Iconsax.chart_215;
      color = Theme.of(context).colorScheme.primary;
    } else if (isHigh) {
      message =
          'Este presupuesto es un ${percentage.toStringAsFixed(0)}% más alto que tu promedio histórico. Mantén el control 💪';
      icon = Iconsax.warning_25;
      color = Colors.orange;
    } else if (isLow) {
      message =
          '¡Excelente! Estás ${(100 - percentage).toStringAsFixed(0)}% por debajo de tu promedio. Sigue así 🎯';
      icon = Iconsax.trend_down5;
      color = Colors.green;
    } else {
      message =
          'Este monto está alineado con tus patrones de gasto. ¡Buen objetivo! 👍';
      icon = Iconsax.chart_success5;
      color = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.08),
            color.withOpacity(0.03),
          ],
        ),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.15),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Impacto Proyectado',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CATEGORY PICKER SHEET
// =============================================================================

class _CategoryPickerSheet extends StatelessWidget {
  final List<Category> categories;
  final ScrollController scrollController;
  final Function(Category) onCategorySelected;

  const _CategoryPickerSheet({
    required this.categories,
    required this.scrollController,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                "Selecciona una Categoría",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return _CategoryTile(
                      category: category,
                      onTap: () => onCategorySelected(category),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.onTap,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.category.colorAsObject.withOpacity(0.2),
                        widget.category.colorAsObject.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: widget.category.colorAsObject.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    widget.category.icon,
                    color: widget.category.colorAsObject,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// CONFETTI PERSONALIZADO
// =============================================================================

class _ConfettiCelebration extends StatelessWidget {
  final ConfettiController controller;
  final Category? category;

  const _ConfettiCelebration({
    required this.controller,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 30,
        gravity: 0.3,
        emissionFrequency: 0.05,
        colors: category != null
            ? [
                category!.colorAsObject,
                category!.colorAsObject.withOpacity(0.7),
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.secondary,
              ]
            : [
                Colors.blue,
                Colors.green,
                Colors.orange,
                Colors.purple,
                Colors.pink,
              ],
      ),
    );
  }
}
