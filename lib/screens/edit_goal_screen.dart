// lib/screens/edit_goal_screen.dart
// VERSIÓN PREMIUM CON IA FINANCIERA Y PROYECCIONES EN TIEMPO REAL

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/screens/goal_notes_editor_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;
import 'package:sasper/data/analysis_repository.dart'; // <-- AÑADIR

/// Pantalla premium de edición de metas con IA financiera
class EditGoalScreen extends StatefulWidget {
  final Goal goal;

  const EditGoalScreen({super.key, required this.goal});

  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen>
    with TickerProviderStateMixin {
  // Repositories
  final GoalRepository _goalRepository = GoalRepository.instance;
  final CategoryRepository _categoryRepository = CategoryRepository.instance;
  final AnalysisRepository _analysisRepository = AnalysisRepository.instance;

  // --- AÑADIR NUEVAS VARIABLES DE ESTADO PARA DATOS REALES ---
  double _realMonthlyIncome = 0.0;
  bool _isInitialDataLoading = true; // Renombramos para claridad

  // Form
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetAmountController;

  final List<_ConfettiParticle> _particles = [];

  // State
  DateTime? _targetDate;
  bool _isLoading = false;
  bool _isAdvancedMode = false;
  late GoalTimeframe _timeframe;
  late GoalPriority _priority;
  String? _selectedCategoryId;
  List<Category>? _categories;

  // Simulación IA
  Timer? _debounceTimer;
  FinancialProjection? _currentProjection;

  // Animaciones
  late AnimationController _projectionController;
  late AnimationController _pulseController;
  late AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    // Inicializar valores
    _nameController = TextEditingController(text: widget.goal.name);
    _targetAmountController = TextEditingController(
      text: widget.goal.targetAmount.toStringAsFixed(0),
    );
    _targetDate = widget.goal.targetDate;
    _timeframe = widget.goal.timeframe;
    _priority = widget.goal.priority;
    _selectedCategoryId = widget.goal.categoryId;

    // Animaciones
    _projectionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Cargar datos y calcular proyección inicial
    //_loadCategories();
    //calculateProjection();

    _loadInitialData();

    // Listeners para recalcular en tiempo real
    _targetAmountController.addListener(_onFieldChanged);
  }

  /// Carga o recarga las notas de la meta actual y actualiza la interfaz.
  void _loadNotes() {
    setState(() {
      // widget.goal.id es el ID de la meta que se está editando
    });
  }

  Future<void> _loadInitialData() async {
    // 1. Cargamos categorías y datos financieros en paralelo para más eficiencia.
    await Future.wait([
      _loadCategories(),
      _loadFinancialData(),
    ]);

    // 2. Una vez que tenemos los datos, calculamos la proyección inicial.
    _calculateProjection();

    // 3. Marcamos la carga como completa.
    if (mounted) {
      setState(() {
        _isInitialDataLoading = false;
      });
    }
  }

  // <-- AÑADIR ESTE NUEVO MÉTODO -->
  Future<void> _loadFinancialData() async {
    final analysisData = await _analysisRepository.fetchAllAnalysisData();

    if (mounted) {
      final monthlySummaries = analysisData.incomeExpenseBarData;
      double calculatedAverageIncome = 0.0;

      if (monthlySummaries.isNotEmpty) {
        final totalIncome = monthlySummaries.fold<double>(
          0.0,
          (sum, summary) => sum + summary.totalIncome,
        );
        calculatedAverageIncome = totalIncome / monthlySummaries.length;
      }

      // Guardamos el dato real en el estado
      _realMonthlyIncome =
          calculatedAverageIncome > 0 ? calculatedAverageIncome : 1.0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _debounceTimer?.cancel();
    _projectionController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _createConfettiParticles() {
    _particles.clear(); // Limpiamos las partículas anteriores
    final random = math.Random();
    final screenWidth = MediaQuery.of(context).size.width;
    final colors = [
      Colors.blue,
      Colors.pink,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange
    ];

    // Creamos 100 partículas de confeti
    for (int i = 0; i < 100; i++) {
      _particles.add(
        _ConfettiParticle(
          // Posición inicial aleatoria en la parte superior de la pantalla
          position: Offset(random.nextDouble() * screenWidth, 0),
          // Velocidad inicial aleatoria hacia abajo y hacia los lados
          velocity: Offset(
            random.nextDouble() * 4 - 2, // -2 a +2 horizontalmente
            random.nextDouble() * 4 + 2, // 2 a 6 verticalmente
          ),
          color: colors[random.nextInt(colors.length)],
          size: random.nextDouble() * 8 + 4, // Tamaño de 4 a 12
          rotation: random.nextDouble() * 2 * math.pi,
          angularVelocity: random.nextDouble() * 0.2 - 0.1, // -0.1 a +0.1
        ),
      );
    }
  }

  Future<void> _loadCategories() async {
    final categories = await _categoryRepository.getCategories();
    if (mounted) {
      setState(() {
        _categories =
            categories.where((c) => c.type == CategoryType.expense).toList();
      });
    }
  }

  void _onFieldChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _calculateProjection();
    });
  }

  void _calculateProjection() {
    final amountText = _targetAmountController.text.replaceAll(',', '.');
    final targetAmount =
        double.tryParse(amountText) ?? widget.goal.targetAmount;
    final currentAmount = widget.goal.currentAmount;
    final remainingAmount = targetAmount - currentAmount;

    final projection = FinancialProjection.calculate(
      remainingAmount: remainingAmount,
      targetDate: _targetDate,
      timeframe: _timeframe,
      userMonthlyIncome: _realMonthlyIncome,
    );

    if (mounted) {
      setState(() => _currentProjection = projection);
      _projectionController.forward(from: 0);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
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

    if (picked != null && picked != _targetDate) {
      HapticFeedback.selectionClick();
      setState(() => _targetDate = picked);
      _calculateProjection();
    }
  }

  Future<void> _showCategoryPicker() async {
    if (_categories == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryPickerSheet(
        categories: _categories!,
        selectedId: _selectedCategoryId,
        onSelected: (category) {
          setState(() => _selectedCategoryId = category.id);
          HapticFeedback.selectionClick();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _applyRecommendation(RecommendationType type) {
    if (_currentProjection == null) return;

    switch (type) {
      case RecommendationType.extendDeadline:
        final suggestion = _currentProjection!.suggestedMonths;
        final newDate = DateTime.now().add(Duration(days: suggestion * 30));
        setState(() => _targetDate = newDate);
        break;

      case RecommendationType.increaseContribution:
        // Mostrar modal con simulación
        _showRecommendationModal(type);
        return;

      case RecommendationType.reduceTarget:
        final reduction = _currentProjection!.remainingAmount * 0.2;
        final newTarget = widget.goal.targetAmount - reduction;
        _targetAmountController.text = newTarget.toStringAsFixed(0);
        break;
    }

    _calculateProjection();
    HapticFeedback.mediumImpact();

    NotificationHelper.show(
      message: 'Sugerencia aplicada. Revisa los cambios.',
      type: NotificationType.info,
    );
  }

  Future<void> _showRecommendationModal(RecommendationType type) async {
    await showDialog(
      context: context,
      builder: (context) => _RecommendationModal(
        type: type,
        projection: _currentProjection!,
        currentGoal: widget.goal,
        onApply: (newDate, newAmount) {
          Navigator.pop(context);
          if (newDate != null) {
            setState(() => _targetDate = newDate);
          }
          if (newAmount != null) {
            _targetAmountController.text = newAmount.toStringAsFixed(0);
          }
          _calculateProjection();
        },
      ),
    );
  }

  Future<void> _showConfirmationModal() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmUpdateModal(
        goal: widget.goal,
        newName: _nameController.text.trim(),
        newAmount: double.parse(
          _targetAmountController.text.replaceAll(',', '.'),
        ),
        newDate: _targetDate,
        projection: _currentProjection,
      ),
    );

    if (confirmed == true) {
      await _updateGoal();
    }
  }

  Future<void> _updateGoal() async {
    setState(() => _isLoading = true);
    final navigator = Navigator.of(context);

    try {
      final updatedGoal = widget.goal.copyWith(
        name: _nameController.text.trim(),
        targetAmount: double.parse(
          _targetAmountController.text.replaceAll(',', '.'),
        ),
        targetDate: _targetDate,
        priority: _priority,
        categoryId: _selectedCategoryId,
        timeframe: _timeframe,
      );

      await _goalRepository.updateGoal(updatedGoal);

      if (mounted) {
        // Confetti animation
        _createConfettiParticles(); // 1. Creamos las partículas
        _confettiController.forward(
            from: 0); // 2. Reiniciamos y lanzamos la animación

        // Esperar animación
        await Future.delayed(const Duration(milliseconds: 800));

        EventService.instance.fire(AppEvent.goalUpdated);

        navigator.pop(true);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: '¡Meta actualizada con éxito! 🎯',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      developer.log('Error al actualizar meta: $e', name: 'EditGoalScreen');

      if (mounted) {
        NotificationHelper.show(
          message: 'Error: ${e.toString().replaceFirst("Exception: ", "")}',
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

    if (_isInitialDataLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: AppBar(
            backgroundColor:
                colorScheme.surface), // AppBar para consistencia visual
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(colorScheme),
              SliverPersistentHeader(
                pinned: true,
                delegate: _HeroCardDelegate(
                  goal: widget.goal,
                  nameController: _nameController,
                  projection: _currentProjection,
                  category: _categories?.firstWhere(
                    (c) => c.id == _selectedCategoryId,
                    orElse: () => _categories!.first,
                  ),
                  pulseAnimation: _pulseController,
                ),
              ),
              SliverToBoxAdapter(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildModeToggle(colorScheme),
                      const SizedBox(height: 24),
                      _buildBasicFields(colorScheme),
                      if (_currentProjection != null) ...[
                        const SizedBox(height: 24),
                        _buildProjectionCard(colorScheme),
                      ],
                      if (_isAdvancedMode) ...[
                        const SizedBox(height: 24),
                        _buildAdvancedFields(colorScheme),
                      ],
                      if (_currentProjection != null &&
                          _currentProjection!.status !=
                              ViabilityStatus.feasible) ...[
                        const SizedBox(height: 24),
                        _buildRecommendations(colorScheme),
                      ],

                      // --- AÑADE ESTAS LÍNEAS AQUÍ ---
                      const SizedBox(height: 24),
                      _buildNotesSection(),
                      const SizedBox(height: 32),
                      // --- FIN ---

                      _buildActionButtons(colorScheme),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Confetti overlay
          if (_confettiController.isAnimating)
            IgnorePointer(
              child: CustomPaint(
                // ESTA ES LA LLAMADA CORRECTA
                painter: _ConfettiPainter(
                  particles: _particles,
                  animation: _confettiController,
                ),
                child: const SizedBox.expand(),
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGET 1: La sección principal que contiene todo ---
  Widget _buildNotesSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas y Apuntes',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
            ),
            child: ListTile(
              leading:
                  Icon(Iconsax.document_text_1, color: colorScheme.primary),
              title: const Text('Abrir editor de notas'),
              subtitle:
                  const Text('Añade enlaces, ideas y apuntes importantes.'),
              trailing: const Icon(Iconsax.arrow_right_3),
              onTap: () async {
                // Navegamos a la nueva pantalla del editor
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GoalNotesEditorScreen(
                      goal: widget.goal, // Pasamos la meta completa
                    ),
                  ),
                );

                // Opcional pero recomendado: Si el editor devuelve la meta actualizada,
                // la podemos usar para refrescar el estado de esta pantalla si fuera necesario.
                if (result is Goal && mounted) {
                  // Aquí podrías, por ejemplo, actualizar el objeto 'goal' del estado si
                  // necesitaras reflejar algún cambio inmediatamente en EditGoalScreen.
                  // Por ahora, solo con navegar es suficiente.
                  developer.log('Se ha vuelto del editor de notas.',
                      name: 'EditGoalScreen');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(ColorScheme colorScheme) {
    return SliverAppBar(
      floating: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Iconsax.arrow_left, color: colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Editar Meta',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildModeToggle(ColorScheme colorScheme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              label: 'Rápido',
              icon: Iconsax.flash_1,
              isSelected: !_isAdvancedMode,
              onTap: () {
                setState(() => _isAdvancedMode = false);
                HapticFeedback.selectionClick();
              },
            ),
          ),
          Expanded(
            child: _ModeButton(
              label: 'Avanzado',
              icon: Iconsax.setting_2,
              isSelected: _isAdvancedMode,
              onTap: () {
                setState(() => _isAdvancedMode = true);
                HapticFeedback.selectionClick();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFields(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Monto Objetivo
          Text(
            'Monto Objetivo',
            style: GoogleFonts.poppins(
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
                color: colorScheme.primary.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: TextFormField(
              controller: _targetAmountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                prefixText: '\$ ',
                prefixStyle: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.primary,
                ),
                hintText: '0',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa un monto';
                }
                final amount = double.tryParse(value.replaceAll(',', '.'));
                if (amount == null || amount <= 0) {
                  return 'Monto inválido';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: 20),

          // Fecha Límite
          Text(
            'Fecha Límite',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _targetDate != null
                      ? colorScheme.primary.withOpacity(0.2)
                      : colorScheme.outline.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Iconsax.calendar_1,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _targetDate == null
                          ? 'Seleccionar fecha'
                          : DateFormat('d \'de\' MMMM, yyyy', 'es')
                              .format(_targetDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _targetDate != null
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                  if (_targetDate != null)
                    IconButton(
                      icon: Icon(
                        Iconsax.close_circle,
                        color: colorScheme.onSurface.withOpacity(0.5),
                      ),
                      onPressed: () {
                        setState(() => _targetDate = null);
                        _calculateProjection();
                      },
                    )
                  else
                    Icon(
                      Iconsax.arrow_right_3,
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectionCard(ColorScheme colorScheme) {
    final projection = _currentProjection!;

    return FadeTransition(
      opacity: _projectionController,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _projectionController,
          curve: Curves.easeOutCubic,
        )),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                projection.status.color.withOpacity(0.1),
                projection.status.color.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: projection.status.color.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: projection.status.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      projection.status.icon,
                      color: projection.status.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          projection.status.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          projection.status.subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _ProjectionMetrics(projection: projection),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdvancedFields(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración Avanzada',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Categoría
          InkWell(
            onTap: _showCategoryPicker,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(Iconsax.category, color: colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _selectedCategoryId != null && _categories != null
                          ? _categories!
                              .firstWhere((c) => c.id == _selectedCategoryId)
                              .name
                          : 'Seleccionar categoría',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Iconsax.arrow_right_3,
                    color: colorScheme.onSurface.withOpacity(0.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Prioridad
          Text(
            'Prioridad',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _PrioritySelector(
            selected: _priority,
            onChanged: (value) => setState(() => _priority = value),
          ),
          const SizedBox(height: 16),

          // Timeframe
          Text(
            'Plazo',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          _TimeframeSelector(
            selected: _timeframe,
            onChanged: (value) {
              setState(() => _timeframe = value);
              _calculateProjection();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Iconsax.lamp_charge, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Recomendaciones IA',
                style: GoogleFonts.poppins(
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
          height: 120,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _RecommendationCard(
                title: 'Extender Plazo',
                subtitle: '+${_currentProjection!.suggestedMonths} meses',
                icon: Iconsax.calendar_add,
                color: Colors.blue,
                onTap: () => _applyRecommendation(
                  RecommendationType.extendDeadline,
                ),
              ),
              const SizedBox(width: 12),
              _RecommendationCard(
                title: 'Aumentar Aporte',
                subtitle: 'Ver simulación',
                icon: Iconsax.arrow_up_1,
                color: Colors.green,
                onTap: () => _applyRecommendation(
                  RecommendationType.increaseContribution,
                ),
              ),
              const SizedBox(width: 12),
              _RecommendationCard(
                title: 'Reducir Objetivo',
                subtitle: '-20% del monto',
                icon: Iconsax.arrow_down_1,
                color: Colors.orange,
                onTap: () => _applyRecommendation(
                  RecommendationType.reduceTarget,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isLoading ? null : _showConfirmationModal,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
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
                    Icon(Iconsax.tick_circle, color: colorScheme.onPrimary),
                    const SizedBox(width: 12),
                    Text(
                      'Actualizar Meta',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODELS & LOGIC
// ============================================================================

enum ViabilityStatus {
  feasible('Realista', 'Va por buen camino', Colors.green, Iconsax.verify),
  challenging('Desafiante', 'Requiere ahorro intenso', Colors.orange,
      Iconsax.warning_2),
  highRisk('Alto Riesgo', 'Compromete presupuesto', Colors.red, Iconsax.danger);

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  const ViabilityStatus(this.title, this.subtitle, this.color, this.icon);
}

enum RecommendationType {
  extendDeadline,
  increaseContribution,
  reduceTarget,
}

class FinancialProjection {
  final double remainingAmount;
  final int monthsRemaining;
  final double monthlyNeeded;
  final double percentageOfIncome;
  final ViabilityStatus status;
  final int suggestedMonths;

  FinancialProjection({
    required this.remainingAmount,
    required this.monthsRemaining,
    required this.monthlyNeeded,
    required this.percentageOfIncome,
    required this.status,
    required this.suggestedMonths,
  });

  static FinancialProjection calculate({
    required double remainingAmount,
    required DateTime? targetDate,
    required GoalTimeframe timeframe,
    required double userMonthlyIncome,
  }) {
    int months = _calculateMonthsRemaining(targetDate, timeframe);
    if (months <= 0) months = 1;

    final monthlyNeeded = remainingAmount / months;
    final percentage = (monthlyNeeded / userMonthlyIncome) * 100;

    final status = _evaluateViability(percentage);
    final suggestedMonths = _calculateSuggestedMonths(
      remainingAmount,
      userMonthlyIncome,
    );

    return FinancialProjection(
      remainingAmount: remainingAmount,
      monthsRemaining: months,
      monthlyNeeded: monthlyNeeded,
      percentageOfIncome: percentage,
      status: status,
      suggestedMonths: suggestedMonths,
    );
  }

  static int _calculateMonthsRemaining(
      DateTime? targetDate, GoalTimeframe timeframe) {
    if (targetDate == null) {
      // Usar timeframe por defecto
      switch (timeframe) {
        case GoalTimeframe.short:
          return 6;
        case GoalTimeframe.medium:
          return 12;
        case GoalTimeframe.long:
          return 36;
        case GoalTimeframe.custom:
          return 12;
      }
    }

    final now = DateTime.now();
    if (targetDate.isBefore(now)) return 0;

    return (targetDate.year - now.year) * 12 + (targetDate.month - now.month);
  }

  static ViabilityStatus _evaluateViability(double percentage) {
    if (percentage <= 25) return ViabilityStatus.feasible;
    if (percentage <= 50) return ViabilityStatus.challenging;
    return ViabilityStatus.highRisk;
  }

  static int _calculateSuggestedMonths(double remaining, double income) {
    final idealMonthly = income * 0.20; // 20% del ingreso
    return (remaining / idealMonthly).ceil();
  }
}

// ============================================================================
// HERO CARD DELEGATE
// ============================================================================

class _HeroCardDelegate extends SliverPersistentHeaderDelegate {
  final Goal goal;
  final TextEditingController nameController;
  final FinancialProjection? projection;
  final Category? category;
  final AnimationController pulseAnimation;

  _HeroCardDelegate({
    required this.goal,
    required this.nameController,
    required this.projection,
    required this.category,
    required this.pulseAnimation,
  });

  @override
  double get minExtent => 180;

  @override
  double get maxExtent => 220;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = goal.currentAmount / goal.targetAmount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(0.6),
            colorScheme.secondaryContainer.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (category != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: category!.colorAsObject.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    category!.icon,
                    color: category!.colorAsObject,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  nameController.text.isEmpty
                      ? 'Nueva Meta'
                      : nameController.text,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (projection != null)
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 1.0 + (pulseAnimation.value * 0.1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: projection!.status.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              projection!.status.icon,
                              color: projection!.status.color,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              projection!.status.title,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: projection!.status.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Objetivo',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat('#,##0', 'es').format(goal.targetAmount),
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Progreso',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(progress * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeroCardDelegate oldDelegate) {
    return oldDelegate.projection != projection ||
        oldDelegate.nameController.text != nameController.text;
  }
}

// ============================================================================
// PROJECTION METRICS WIDGET
// ============================================================================

class _ProjectionMetrics extends StatelessWidget {
  final FinancialProjection projection;

  const _ProjectionMetrics({required this.projection});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Aporte Mensual',
            value: NumberFormat('#,##0', 'es').format(projection.monthlyNeeded),
            icon: Iconsax.wallet_money,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Meses Restantes',
            value: '${projection.monthsRemaining}',
            icon: Iconsax.calendar,
            colorScheme: colorScheme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MetricCard(
            label: 'Del Ingreso',
            value: '${projection.percentageOfIncome.toStringAsFixed(0)}%',
            icon: Iconsax.percentage_circle,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final ColorScheme colorScheme;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODE BUTTON
// ============================================================================

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PRIORITY SELECTOR
// ============================================================================

class _PrioritySelector extends StatelessWidget {
  final GoalPriority selected;
  final ValueChanged<GoalPriority> onChanged;

  const _PrioritySelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GoalPriority.values.map((priority) {
        final isSelected = priority == selected;
        final color = _getPriorityColor(priority);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onChanged(priority),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.2)
                      // Usamos un color con mejor contraste para el estado no seleccionado
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _getPriorityLabel(priority),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? color
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _getPriorityColor(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return Colors.red;
      case GoalPriority.medium:
        return Colors.orange;
      case GoalPriority.low:
        return Colors.green;
    }
  }

  String _getPriorityLabel(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.high:
        return 'Alta';
      case GoalPriority.medium:
        return 'Media';
      case GoalPriority.low:
        return 'Baja';
    }
  }
}

// ============================================================================
// TIMEFRAME SELECTOR
// ============================================================================

class _TimeframeSelector extends StatelessWidget {
  final GoalTimeframe selected;
  final ValueChanged<GoalTimeframe> onChanged;

  const _TimeframeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: GoalTimeframe.values.map((timeframe) {
        final isSelected = timeframe == selected;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () => onChanged(timeframe),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                      // Usamos un color con mejor contraste para el estado no seleccionado
                      : Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Text(
                  _getTimeframeLabel(timeframe),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getTimeframeLabel(GoalTimeframe timeframe) {
    switch (timeframe) {
      case GoalTimeframe.short:
        return 'Corto';
      case GoalTimeframe.medium:
        return 'Medio';
      case GoalTimeframe.long:
        return 'Largo';
      case GoalTimeframe.custom:
        return 'Custom';
    }
  }
}

// ============================================================================
// RECOMMENDATION CARD
// ============================================================================

class _RecommendationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RecommendationCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const Spacer(),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CATEGORY PICKER SHEET
// ============================================================================

class _CategoryPickerSheet extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<Category> onSelected;

  const _CategoryPickerSheet({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withOpacity(0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Seleccionar Categoría',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selectedId;

              return InkWell(
                onTap: () => onSelected(category),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? category.colorAsObject.withOpacity(0.2)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? category.colorAsObject
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        category.icon,
                        color: category.colorAsObject,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        category.name,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================================
// RECOMMENDATION MODAL
// ============================================================================

class _RecommendationModal extends StatelessWidget {
  final RecommendationType type;
  final FinancialProjection projection;
  final Goal currentGoal;
  final Function(DateTime?, double?) onApply;

  const _RecommendationModal({
    required this.type,
    required this.projection,
    required this.currentGoal,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    String title;
    String description;
    String beforeLabel;
    String afterLabel;
    String beforeValue;
    String afterValue;

    switch (type) {
      case RecommendationType.extendDeadline:
        //final newDate = DateTime.now().add(
        //Duration(days: projection.suggestedMonths * 30),
        //);
        title = 'Extender Plazo';
        description = 'Aumentar el plazo reduce el aporte mensual necesario';
        beforeLabel = 'Plazo actual';
        afterLabel = 'Nuevo plazo';
        beforeValue = '${projection.monthsRemaining} meses';
        afterValue = '${projection.suggestedMonths} meses';
        break;

      case RecommendationType.increaseContribution:
        title = 'Aumentar Aporte';
        description =
            'Aportar más mensualmente te ayuda a cumplir tu meta más rápido';
        beforeLabel = 'Aporte actual';
        afterLabel = 'Aporte sugerido';
        beforeValue =
            NumberFormat('#,##0', 'es').format(projection.monthlyNeeded);
        afterValue =
            NumberFormat('#,##0', 'es').format(projection.monthlyNeeded * 1.5);
        break;

      case RecommendationType.reduceTarget:
        final newAmount = currentGoal.targetAmount * 0.8;
        title = 'Reducir Objetivo';
        description =
            'Un objetivo menor es más alcanzable con tu presupuesto actual';
        beforeLabel = 'Objetivo actual';
        afterLabel = 'Nuevo objetivo';
        beforeValue =
            NumberFormat('#,##0', 'es').format(currentGoal.targetAmount);
        afterValue = NumberFormat('#,##0', 'es').format(newAmount);
        break;
    }

    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        beforeLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        beforeValue,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Iconsax.arrow_right,
                  color: colorScheme.primary,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        afterLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        afterValue,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Apply logic based on type
                      if (type == RecommendationType.extendDeadline) {
                        final newDate = DateTime.now().add(
                          Duration(days: projection.suggestedMonths * 30),
                        );
                        onApply(newDate, null);
                      } else if (type == RecommendationType.reduceTarget) {
                        final newAmount = currentGoal.targetAmount * 0.8;
                        onApply(null, newAmount);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Aplicar',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CONFIRM UPDATE MODAL
// ============================================================================

class _ConfirmUpdateModal extends StatelessWidget {
  final Goal goal;
  final String newName;
  final double newAmount;
  final DateTime? newDate;
  final FinancialProjection? projection;

  const _ConfirmUpdateModal({
    required this.goal,
    required this.newName,
    required this.newAmount,
    this.newDate,
    this.projection,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // --- Lógica precisa para detectar si hubo cambios reales ---
    final nameChanged = newName.trim() != goal.name;
    final amountChanged = newAmount != goal.targetAmount;
    // Compara fechas de forma segura, manejando el caso de que la fecha original sea nula
    final dateChanged = newDate != null &&
        (goal.targetDate == null ||
            !newDate!.isAtSameMomentAs(goal.targetDate!));
    final hasChanges = nameChanged || amountChanged || dateChanged;

    // --- Formateadores para mostrar los datos de forma legible ---
    final currencyFormat =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateFormat = DateFormat.yMMMd('es_CO');

    // --- Widget a mostrar si NO hay cambios ---
    if (!hasChanges) {
      return _buildNoChangesDialog(context, colorScheme);
    }

    // --- Widget principal si SÍ hay cambios ---
    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: SingleChildScrollView(
          // Para evitar overflow si el contenido es mucho
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Encabezado ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Iconsax.edit,
                  color: colorScheme.primary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¿Actualizar Meta?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Revisa los cambios antes de confirmar.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),

              // --- Contenedor de Resumen de Cambios ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: colorScheme.surfaceContainer,
                  border:
                      Border.all(color: colorScheme.outline.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _buildChangeRow(
                      context: context,
                      label: 'Nombre',
                      oldValue: goal.name,
                      newValue: newName,
                      isDifferent: nameChanged,
                    ),
                    _buildChangeRow(
                      context: context,
                      label: 'Monto',
                      oldValue: currencyFormat.format(goal.targetAmount),
                      newValue: currencyFormat.format(newAmount),
                      isDifferent: amountChanged,
                    ),
                    if (newDate != null)
                      _buildChangeRow(
                        context: context,
                        label: 'Fecha',
                        oldValue: goal.targetDate != null
                            ? dateFormat.format(goal.targetDate!)
                            : 'N/A',
                        newValue: dateFormat.format(newDate!),
                        isDifferent: dateChanged,
                      ),
                  ],
                ),
              ),

              // --- Sección de Proyección de IA (si existe) ---
              if (projection != null) ...[
                const SizedBox(height: 20),
                _buildProjectionInfo(context, projection!, currencyFormat),
              ],

              const SizedBox(height: 28),

              // --- Botones de Acción ---
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                            color: colorScheme.outline.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Confirmar',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
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

  /// Widget que muestra una fila de cambio (valor antiguo -> nuevo valor).
  Widget _buildChangeRow({
    required BuildContext context,
    required String label,
    required String oldValue,
    required String newValue,
    required bool isDifferent,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: colorScheme.onSurface.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (!isDifferent)
            Text(
              newValue,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            )
          else
            Flexible(
              // Para evitar overflow si los textos son largos
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    oldValue,
                    style: GoogleFonts.poppins(
                      color: colorScheme.onSurface.withOpacity(0.5),
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Icon(
                      Iconsax.arrow_right_3,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  Flexible(
                    // El nuevo valor puede ser largo
                    child: Text(
                      newValue,
                      style: GoogleFonts.poppins(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Widget que muestra la información de la proyección financiera.
  Widget _buildProjectionInfo(BuildContext context,
      FinancialProjection projection, NumberFormat currencyFormat) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.primaryContainer.withOpacity(0.2),
        border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.cpu, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Proyección Local', // Cambiamos el título para ser claros
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProjectionDetailRow(
            context: context,
            icon: Iconsax.money_recive,
            label: 'Ahorro mensual necesario',
            // ESTA ES LA LÍNEA CORRECTA
            value: currencyFormat.format(projection.monthlyNeeded),
          ),
          const SizedBox(height: 8),
          _buildProjectionDetailRow(
            context: context,
            icon: Iconsax.calendar_tick,
            label: 'Meses para lograrlo',
            // ESTA ES LA LÍNEA CORRECTA
            value: '${projection.monthsRemaining} meses',
          ),
        ],
      ),
    );
  }

  /// Widget para mostrar una fila de detalle dentro de la proyección.
  Widget _buildProjectionDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colorScheme.onSurface.withOpacity(0.7)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 13),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Widget que se muestra cuando no se ha realizado ningún cambio.
  Widget _buildNoChangesDialog(BuildContext context, ColorScheme colorScheme) {
    return Dialog(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Iconsax.info_circle,
                color: colorScheme.secondary,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Sin Cambios',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No has modificado ningún campo de la meta.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context)
                  .pop(), // Cierra el modal, no devuelve valor
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                'Entendido',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Representa una única partícula de confeti.
class _ConfettiParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double rotation;
  double angularVelocity;

  _ConfettiParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.rotation,
    required this.angularVelocity,
  });

  /// Actualiza la posición y rotación de la partícula para el siguiente frame.
  void update() {
    position += velocity;
    rotation += angularVelocity;
    // Agrega un poco de gravedad
    velocity = velocity.translate(0, 0.1);
  }
}

/// El CustomPainter que dibuja todas las partículas de confeti en el lienzo.
class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final Animation<double> animation;

  _ConfettiPainter({required this.particles, required this.animation})
      : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (final particle in particles) {
      // Actualizamos la posición de la partícula en cada repintado
      particle.update();

      paint.color = particle.color.withOpacity(1.0 - animation.value);

      // Guardamos el estado del lienzo, aplicamos la rotación y luego lo restauramos
      canvas.save();
      canvas.translate(particle.position.dx, particle.position.dy);
      canvas.rotate(particle.rotation);
      canvas.translate(-particle.position.dx, -particle.position.dy);

      canvas.drawRect(
        Rect.fromLTWH(
          particle.position.dx - particle.size / 2,
          particle.position.dy - particle.size / 2,
          particle.size,
          particle.size * 1.2, // Hacemos el confeti rectangular
        ),
        paint,
      );

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    // No necesitamos que repinte si los objetos son los mismos,
    // porque la animación ya lo controla.
    return false;
  }
}
