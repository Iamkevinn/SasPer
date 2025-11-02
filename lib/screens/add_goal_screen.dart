// lib/screens/add_goal_screen.dart

import 'dart:ui' as ui;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/goal_model.dart';
import 'dart:developer' as developer;
import 'package:sasper/data/analysis_repository.dart';

enum ViabilityStatus { feasible, challenging, highRisk }

class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen>
    with TickerProviderStateMixin {
  final GoalRepository _goalRepository = GoalRepository.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController(text: '0');
  late ConfettiController _confettiController;
  final AnalysisRepository _analysisRepository = AnalysisRepository.instance;
  double _realMonthlyIncome = 0.0;
  bool _isDataLoading = true;
  Category? _selectedCategory;
  DateTime _targetDate = DateTime.now().add(const Duration(days: 365));
  GoalPriority _priority = GoalPriority.medium;
  bool _isLoading = false;
  bool _isSuccess = false;


  // Animaciones
  late AnimationController _viabilityAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _viabilityAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Animación de viabilidad
    _viabilityAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _viabilityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _viabilityAnimationController, curve: Curves.easeOutBack),
    );

    // Animación de progreso
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _progressAnimationController, curve: Curves.easeInOut),
    );

    _nameController.addListener(() {
      setState(() {});
      _viabilityAnimationController.forward(from: 0);
    });
    _targetAmountController.addListener(() {
      setState(() {});
      _progressAnimationController.forward(from: 0);
    });
    _loadFinancialData();
  }

   // <-- AÑADIR ESTE NUEVO MÉTODO -->
   Future<void> _loadFinancialData() async {
    // 1. Llama al método que ya existe y obtiene todos los datos
    final analysisData = await _analysisRepository.fetchAllAnalysisData();

    if (mounted) {
      // 2. Extrae la lista con el resumen de ingresos/gastos mensuales
      final monthlySummaries = analysisData.incomeExpenseBarData;
      double calculatedAverageIncome = 0.0;

      if (monthlySummaries.isNotEmpty) {
        // 3. Calcula el promedio de los ingresos de esa lista
        final totalIncome = monthlySummaries.fold<double>(
          0.0,
          (sum, summary) => sum + summary.totalIncome, // Asumiendo que el modelo tiene `totalIncome`
        );
        calculatedAverageIncome = totalIncome / monthlySummaries.length;
      }
      
      setState(() {
        // 4. Guarda el dato real en el estado
        _realMonthlyIncome = calculatedAverageIncome > 0 ? calculatedAverageIncome : 1.0; 
        _isDataLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _confettiController.dispose();
    _viabilityAnimationController.dispose();
    _progressAnimationController.dispose();
    super.dispose();
  }

  // Cálculos
  int get _monthsRemaining {
    final now = DateTime.now();
    if (_targetDate.isBefore(now)) return 0;
    return (_targetDate.year - now.year) * 12 + _targetDate.month - now.month;
  }

  double get _targetAmount {
    return double.tryParse(
            _targetAmountController.text.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0.0;
  }

  double get _monthlyContribution {
    final months = _monthsRemaining;
    if (months <= 0 || _targetAmount <= 0) return 0.0;
    return _targetAmount / months;
  }

  double get _percentageOfIncome {
    if (_realMonthlyIncome <= 0 || _monthlyContribution <= 0) return 0.0;
    return (_monthlyContribution / _realMonthlyIncome) * 100;
  }

  ViabilityStatus get _viabilityStatus {
    final percentage = _percentageOfIncome;
    if (percentage == 0) return ViabilityStatus.feasible;
    if (percentage > 50) return ViabilityStatus.highRisk;
    if (percentage > 25) return ViabilityStatus.challenging;
    return ViabilityStatus.feasible;
  }

  // Acciones
  Future<void> _selectDate(BuildContext context) async {
    HapticFeedback.lightImpact();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2101),
      locale: const Locale('es'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: Theme.of(context).colorScheme.surface,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      HapticFeedback.mediumImpact();
      setState(() => _targetDate = picked);
    }
  }

  void _showConfirmationModal() {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PremiumConfirmModal(
        goalName: _nameController.text,
        targetAmount: _targetAmount,
        targetDate: _targetDate,
        monthlyContribution: _monthlyContribution,
        viabilityStatus: _viabilityStatus,
        percentageOfIncome: _percentageOfIncome,
        onConfirm: _saveGoal,
      ),
    );
  }

  Future<void> _saveGoal() async {
    if (_isLoading || _isSuccess) return;
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      await _goalRepository.addGoal(
        name: _nameController.text.trim(),
        targetAmount: _targetAmount,
        targetDate: _targetDate,
        priority: _priority,
        categoryId: _selectedCategory?.id,
        timeframe: GoalTimeframe.custom,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        setState(() => _isSuccess = true);
        _confettiController.play();
        EventService.instance.fire(AppEvent.goalCreated);

        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) Navigator.of(context).pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: '¡Tu futuro acaba de mejorar! 🎯',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('🔥 FALLO AL CREAR META: $e', name: 'AddGoalScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
          message: 'Error al crear la meta.',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // AÑADIMOS UN LOADER PARA LA CARGA INICIAL DE DATOS
    if (_isDataLoading) {
      // Usamos un Stack para que el fondo se muestre mientras carga
      return Stack(
        children: [
          _DynamicGoalBackground(goalName: '', viabilityStatus: ViabilityStatus.feasible),
          const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    return Stack(
      children: [
        // Fondo dinámico
        _DynamicGoalBackground(
          goalName: _nameController.text,
          viabilityStatus: _viabilityStatus,
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // HEADER
              _buildPremiumHeader(),

              // HERO CARD FLOTANTE
              _buildFloatingHeroCard(colorScheme, isDark),

              // CONTENIDO
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),

                          // Definición de meta
                          _buildSectionLabel(
                              'Define tu meta', Iconsax.flag, colorScheme),
                          const SizedBox(height: 16),
                          _buildGoalDefinition(colorScheme),

                          const SizedBox(height: 32),

                          // Monto objetivo
                          _buildSectionLabel(
                              'Monto objetivo', Iconsax.dollar_circle, colorScheme),
                          const SizedBox(height: 16),
                          _PremiumAmountField(
                            controller: _targetAmountController,
                            colorScheme: colorScheme,
                          ),

                          const SizedBox(height: 32),

                          // Plazo y prioridad
                          _buildSectionLabel(
                              'Plazo y prioridad', Iconsax.calendar_1, colorScheme),
                          const SizedBox(height: 16),
                          _buildTimeframeSection(colorScheme),

                          const SizedBox(height: 32),

                          // Plan de ahorro sugerido
                          if (_monthlyContribution > 0) ...[
                            _buildSectionLabel('Plan de ahorro sugerido',
                                Iconsax.chart_success, colorScheme),
                            const SizedBox(height: 16),
                            AnimatedBuilder(
                              animation: _progressAnimation,
                              child: _SavingsPlanPremium(
                                monthlyContribution: _monthlyContribution,
                                targetAmount: _targetAmount,
                                monthsRemaining: _monthsRemaining,
                              ),
                              builder: (context, child) {
                                return FadeTransition(
                                  opacity: _progressAnimation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.2),
                                      end: Offset.zero,
                                    ).animate(_progressAnimation),
                                    child: child,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Viabilidad AI
                          if (_monthlyContribution > 0)
                            AnimatedBuilder(
                              animation: _viabilityAnimation,
                              child: _ViabilityAIIndicator(
                                viabilityStatus: _viabilityStatus,
                                percentageOfIncome: _percentageOfIncome,
                                monthlyContribution: _monthlyContribution,
                              ),
                              builder: (context, child) {
                                return ScaleTransition(
                                  scale: _viabilityAnimation,
                                  child: child,
                                );
                              },
                            ),

                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // BOTÓN FLOTANTE
        _buildFloatingActionButton(colorScheme),

        // CONFETTI
        _ConfettiCelebration(controller: _confettiController),
      ],
    );
  }

  // ==================== COMPONENTES ====================

  Widget _buildPremiumHeader() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.tertiary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      Iconsax.flag,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'Nueva Meta',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
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

  Widget _buildFloatingHeroCard(ColorScheme colorScheme, bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _HeroCardDelegate(
        minHeight: 140,
        maxHeight: 140,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.primary.withOpacity(0.15),
                colorScheme.tertiary.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _nameController.text.isEmpty
                                ? 'Tu próxima meta'
                                : _nameController.text,
                            key: ValueKey(_nameController.text),
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      _ViabilityBadgeMini(status: _viabilityStatus),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Text(
                            NumberFormat.currency(
                              locale: 'es_CO',
                              symbol: '\$',
                              decimalDigits: 0,
                            ).format(_targetAmount),
                            key: ValueKey(_targetAmount),
                            style: GoogleFonts.poppins(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'en $_monthsRemaining meses',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, IconData icon, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalDefinition(ColorScheme colorScheme) {
    return _PremiumTextField(
      controller: _nameController,
      hint: 'Ej: Viaje a Japón, Auto nuevo',
      icon: Iconsax.flag,
      colorScheme: colorScheme,
      validator: (value) =>
          (value == null || value.trim().isEmpty) ? 'El nombre es obligatorio' : null,
    );
  }

  Widget _buildTimeframeSection(ColorScheme colorScheme) {
    return Column(
      children: [
        // Selector de fecha
        Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _selectDate(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Iconsax.calendar_1, color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fecha límite',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('d MMMM yyyy', 'es_CO').format(_targetDate),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Iconsax.arrow_right_3,
                      size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Selector de prioridad
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: GoalPriority.values.map((p) {
              return Expanded(
                child: _PriorityButton(
                  priority: p,
                  isSelected: _priority == p,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _priority = p);
                  },
                  colorScheme: colorScheme,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton(ColorScheme colorScheme) {
    return Positioned(
      left: 20,
      right: 20,
      bottom: 30,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 64,
        decoration: BoxDecoration(
          gradient: _isSuccess
              ? LinearGradient(colors: [Colors.green, Colors.green.shade700])
              : LinearGradient(
                  colors: [colorScheme.primary, colorScheme.tertiary],
                ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  (_isSuccess ? Colors.green : colorScheme.primary).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading || _isSuccess ? null : _showConfirmationModal,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isSuccess ? Iconsax.tick_circle : Iconsax.add_square,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _isSuccess ? '¡Meta Creada!' : 'Crear Meta',
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
      ).animate().slideY(begin: 2, delay: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

// ==================== WIDGETS PERSONALIZADOS ====================

// 1. FONDO DINÁMICO
class _DynamicGoalBackground extends StatelessWidget {
  final String goalName;
  final ViabilityStatus viabilityStatus;

  const _DynamicGoalBackground({
    required this.goalName,
    required this.viabilityStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Color primaryColor;
    switch (viabilityStatus) {
      case ViabilityStatus.feasible:
        primaryColor = Colors.green;
        break;
      case ViabilityStatus.challenging:
        primaryColor = Colors.orange;
        break;
      case ViabilityStatus.highRisk:
        primaryColor = Colors.red;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(isDark ? 0.08 : 0.05),
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface,
          ],
        ),
      ),
    );
  }
}

// 2. CAMPO DE TEXTO PREMIUM
class _PremiumTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ColorScheme colorScheme;
  final String? Function(String?)? validator;

  const _PremiumTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.colorScheme,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 16),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: colorScheme.primary),
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      validator: validator,
    );
  }
}

// 3. CAMPO DE MONTO PREMIUM
class _PremiumAmountField extends StatelessWidget {
  final TextEditingController controller;
  final ColorScheme colorScheme;

  const _PremiumAmountField({
    required this.controller,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            'Monto que quieres ahorrar',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CurrencyInputFormatter(),
            ],
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '\$ 0',
              hintStyle: GoogleFonts.poppins(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface.withOpacity(0.2),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Ingresa un monto';
              final amount =
                  int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), ''));
              if (amount == null || amount <= 0) return 'Monto inválido';
              return null;
            },
          ),
        ],
      ),
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
    final format = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final newText = format.format(number);

    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}

// 4. BOTÓN DE PRIORIDAD
class _PriorityButton extends StatelessWidget {
  final GoalPriority priority;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const _PriorityButton({
    required this.priority,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              priority.name.toUpperCase(),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// 5. PLAN DE AHORRO PREMIUM
class _SavingsPlanPremium extends StatelessWidget {
  final double monthlyContribution;
  final double targetAmount;
  final int monthsRemaining;

  const _SavingsPlanPremium({
    required this.monthlyContribution,
    required this.targetAmount,
    required this.monthsRemaining,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    final weekly = monthlyContribution / 4.345;
    final daily = monthlyContribution / 30.437;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer.withOpacity(0.5),
            colorScheme.tertiaryContainer.withOpacity(0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
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
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.wallet_money,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Deberás ahorrar',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _ContributionCard(
                  label: 'Diario',
                  amount: daily,
                  format: currencyFormat,
                  icon: Iconsax.calendar_1,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContributionCard(
                  label: 'Semanal',
                  amount: weekly,
                  format: currencyFormat,
                  icon: Iconsax.calendar,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ContributionCard(
                  label: 'Mensual',
                  amount: monthlyContribution,
                  format: currencyFormat,
                  icon: Iconsax.calendar_tick,
                  colorScheme: colorScheme,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Barra de progreso hacia la meta
          _AnimatedProgressSparkline(
            targetAmount: targetAmount,
            monthsRemaining: monthsRemaining,
            monthlyContribution: monthlyContribution,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _ContributionCard extends StatelessWidget {
  final String label;
  final double amount;
  final NumberFormat format;
  final IconData icon;
  final ColorScheme colorScheme;
  final bool isHighlighted;

  const _ContributionCard({
    required this.label,
    required this.amount,
    required this.format,
    required this.icon,
    required this.colorScheme,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted
            ? colorScheme.primary.withOpacity(0.15)
            : colorScheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: isHighlighted
            ? Border.all(color: colorScheme.primary, width: 2)
            : null,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 20,
            color: isHighlighted ? colorScheme.primary : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            format.format(amount),
            style: GoogleFonts.poppins(
              fontSize: isHighlighted ? 16 : 14,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? colorScheme.primary : colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// 6. SPARKLINE DE PROGRESO ANIMADO
class _AnimatedProgressSparkline extends StatelessWidget {
  final double targetAmount;
  final int monthsRemaining;
  final double monthlyContribution;
  final ColorScheme colorScheme;

  const _AnimatedProgressSparkline({
    required this.targetAmount,
    required this.monthsRemaining,
    required this.monthlyContribution,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Proyección de ahorro',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '$monthsRemaining meses',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: 0,
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inicio',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              NumberFormat.compactCurrency(
                locale: 'es_CO',
                symbol: '\$',
                decimalDigits: 0,
              ).format(targetAmount),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// 7. INDICADOR DE VIABILIDAD AI
class _ViabilityAIIndicator extends StatelessWidget {
  final ViabilityStatus viabilityStatus;
  final double percentageOfIncome;
  final double monthlyContribution;

  const _ViabilityAIIndicator({
    required this.viabilityStatus,
    required this.percentageOfIncome,
    required this.monthlyContribution,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusMessage;

    switch (viabilityStatus) {
      case ViabilityStatus.feasible:
        statusColor = Colors.green;
        statusIcon = Iconsax.tick_circle;
        statusTitle = '¡Excelente plan!';
        statusMessage =
            'Este ahorro representa solo el ${percentageOfIncome.toStringAsFixed(1)}% de tu ingreso. Es un nivel muy saludable y sostenible. ✅';
        break;
      case ViabilityStatus.challenging:
        statusColor = Colors.orange;
        statusIcon = Iconsax.info_circle;
        statusTitle = 'Plan desafiante';
        statusMessage =
            'Deberás ahorrar el ${percentageOfIncome.toStringAsFixed(1)}% de tu ingreso mensual. Es posible, pero requerirá disciplina. Considera ajustar el plazo si lo necesitas.';
        break;
      case ViabilityStatus.highRisk:
        statusColor = Colors.red;
        statusIcon = Iconsax.danger;
        statusTitle = 'Alto compromiso requerido';
        statusMessage =
            '⚠️ Este plan requiere ahorrar el ${percentageOfIncome.toStringAsFixed(1)}% de tu ingreso. Te recomendamos extender el plazo o reducir el monto para que sea más alcanzable.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: statusColor.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [statusColor, statusColor.withOpacity(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(statusIcon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análisis de Viabilidad',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      statusTitle,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            statusMessage,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          // Barra de porcentaje
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Porcentaje de tu ingreso',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${percentageOfIncome.toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (percentageOfIncome / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 8. BADGE DE VIABILIDAD MINI
class _ViabilityBadgeMini extends StatelessWidget {
  final ViabilityStatus status;

  const _ViabilityBadgeMini({required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case ViabilityStatus.feasible:
        statusColor = Colors.green;
        statusIcon = Iconsax.tick_circle;
        break;
      case ViabilityStatus.challenging:
        statusColor = Colors.orange;
        statusIcon = Iconsax.info_circle;
        break;
      case ViabilityStatus.highRisk:
        statusColor = Colors.red;
        statusIcon = Iconsax.danger;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Icon(statusIcon, size: 16, color: statusColor),
    );
  }
}

// 9. MODAL DE CONFIRMACIÓN PREMIUM
class _PremiumConfirmModal extends StatelessWidget {
  final String goalName;
  final double targetAmount;
  final DateTime targetDate;
  final double monthlyContribution;
  final ViabilityStatus viabilityStatus;
  final double percentageOfIncome;
  final VoidCallback onConfirm;

  const _PremiumConfirmModal({
    required this.goalName,
    required this.targetAmount,
    required this.targetDate,
    required this.monthlyContribution,
    required this.viabilityStatus,
    required this.percentageOfIncome,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.tertiary],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.flag, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 24),
          Text(
            '¿Crear esta meta?',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _ConfirmRow('Meta', goalName),
                const Divider(height: 24),
                _ConfirmRow('Monto', currencyFormat.format(targetAmount)),
                const Divider(height: 24),
                _ConfirmRow(
                    'Fecha', DateFormat('d MMM yyyy', 'es_CO').format(targetDate)),
                const Divider(height: 24),
                _ConfirmRow(
                    'Ahorro mensual', currencyFormat.format(monthlyContribution)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Iconsax.tick_circle),
                  label: const Text('Confirmar'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmRow extends StatelessWidget {
  final String label;
  final String value;

  const _ConfirmRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// 10. CONFETTI CELEBRATION
class _ConfettiCelebration extends StatelessWidget {
  final ConfettiController controller;
  const _ConfettiCelebration({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: controller,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        numberOfParticles: 40,
        gravity: 0.3,
        colors: const [
          Colors.green,
          Colors.blue,
          Colors.pink,
          Colors.orange,
          Colors.purple,
          Colors.amber,
        ],
      ),
    );
  }
}

// 11. HERO CARD DELEGATE
class _HeroCardDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  _HeroCardDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}