// lib/screens/add_budget_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Nuevo Presupuesto — Apple-first redesign
//
// Eliminado:
// · SliverAppBar.large + FlexibleSpaceBar + LinearGradient → header blur sticky
// · _HeroSummaryCardDelegate SliverPersistentHeader 90px fijo → preview inline
// · _pulseController 1500ms repeat en ícono de categoría → eliminado
// · _confettiController + _ConfettiCelebration → HapticFeedback + pop inmediato
// · _successAnimController + Transform.scale botón → _SaveBtn patrón
// · AnimatedContainer morphing (width:64/infinity) → _SaveBtn patrón
// · LinearGradient + BoxShadow en botón → _kBlue sólido
// · .animate().slideY(begin:2, delay:500ms) en botón → visible inmediatamente
// · Future.delayed(800ms) artificial → eliminado
// · _isSuccess + Future.delayed(1800ms) → pop inmediato + NotificationHelper
// · _showHelpDialog() AlertDialog Material → eliminado
// · _buildSectionHeader × 3 con subtítulos obvios → _GroupLabel 11px uppercase
// · _AIInsightCard emojis + suggestedMin/Max falsos (avgSpending * 0.14/0.20)
//   → _InsightCard con solo datos reales: % del historial de la categoría
// · _FinancialHealthBar values hardcoded 0.9/0.6/0.3 → valor real calculado
// · _ImpactPreviewCard duplica el insight → unificada con _InsightCard
// · _PeriodicityPill LinearGradient + Border + BoxShadow → _SegmentedControl
// · _buildCustomDateSelector InkWell + LinearGradient → GestureDetector limpio
// · _buildCategorySelector InkWell + LinearGradient + Border variable → limpio
// · _CategoryTile RadialGradient + Border.all(width:2) → borderRadius + color
// · GridView 4 columnas en sheet → lista vertical con promedio histórico inline
// · _amountController text:'0' → text:'' (campo empieza vacío)
// · GoogleFonts.poppins + .inter → _T tokens DM Sans
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/analysis_models.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Enums ───────────────────────────────────────────────────────────────────
enum Periodicity { weekly, monthly, custom }

// ── Tokens ──────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c,
          letterSpacing: -0.4, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

// ── Paleta iOS ───────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

// ── Formato moneda ───────────────────────────────────────────────────────────
final _fmt = NumberFormat.currency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);

String _fmtShort(double v) {
  if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '\$${(v / 1000).toStringAsFixed(0)}K';
  return '\$${v.toStringAsFixed(0)}';
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AddBudgetScreen extends StatefulWidget {
  const AddBudgetScreen({super.key});
  @override State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen>
    with SingleTickerProviderStateMixin {
  final _budgetRepo   = BudgetRepository.instance;
  final _categoryRepo = CategoryRepository.instance;
  final _analysisRepo = AnalysisRepository.instance;
  final _formKey      = GlobalKey<FormState>();
  final _amountCtrl   = TextEditingController();   // empieza vacío — no '0'

  Category?   _selectedCategory;
  Periodicity _periodicity = Periodicity.monthly;
  DateTime    _startDate   = DateTime.now();
  DateTime    _endDate     = DateTime.now();
  bool        _loading     = false;

  // Datos reales de análisis
  AnalysisData? _analysisData;
  bool          _analysisLoading = true;
  double        _categoryHistAvg = 0.0;

  // Categorías
  late Future<List<Category>> _categoriesFuture;

  // Fade-in único
  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _fadeCtrl.forward();
    _categoriesFuture = _categoryRepo.getExpenseCategories();
    _calculateDates(Periodicity.monthly);
    _loadAnalysis();
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Datos reales ──────────────────────────────────────────────────────────

  Future<void> _loadAnalysis() async {
    final data = await _analysisRepo.fetchAllAnalysisData();
    if (mounted) setState(() { _analysisData = data; _analysisLoading = false; });
  }

  void _onCategorySelected(Category cat) {
    HapticFeedback.selectionClick();
    Navigator.pop(context);

    double avg = 0.0;
    if (_analysisData != null) {
      final r = _analysisData!.categoryAverages.firstWhere(
        (a) => a.categoryName == cat.name,
        orElse: () => const CategoryAverageResult(
            categoryName: '', averageAmount: 0),
      );
      avg = r.averageAmount;
    }

    setState(() {
      _selectedCategory  = cat;
      _categoryHistAvg   = avg;
    });
  }

  // ── Fechas ────────────────────────────────────────────────────────────────

  void _calculateDates(Periodicity p) {
    final now = DateTime.now();
    setState(() {
      _periodicity = p;
      switch (p) {
        case Periodicity.weekly:
          _startDate = now.subtract(Duration(days: now.weekday - 1));
          _endDate   = now.add(Duration(days: 7 - now.weekday));
        case Periodicity.monthly:
          _startDate = DateTime(now.year, now.month, 1);
          _endDate   = DateTime(now.year, now.month + 1, 0);
        case Periodicity.custom:
          break; // fechas se seleccionan con datepicker
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context:            context,
      firstDate:          DateTime(2020),
      lastDate:           DateTime(2101),
      initialDateRange:   DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() { _startDate = picked.start; _endDate = picked.end; });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();

    if (_selectedCategory == null) {
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Selecciona una categoría primero.',
          type: NotificationType.error);
      return;
    }
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact(); return;
    }

    setState(() => _loading = true);

    try {
      final amount = double.parse(
          _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));

      await _budgetRepo.addBudget(
        categoryName: _selectedCategory!.name,
        amount:       amount,
        startDate:    _startDate,
        endDate:      _endDate,
        periodicity:  _periodicity.name,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        EventService.instance.fire(AppEvent.budgetsChanged);
        Navigator.of(context).pop(true);
        NotificationHelper.show(
            message: 'Presupuesto creado',
            type: NotificationType.success);
      }
    } catch (e) {
      developer.log('Error al crear presupuesto: $e', name: 'AddBudgetScreen');
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al crear presupuesto.',
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Category sheet ────────────────────────────────────────────────────────

  void _openCategorySheet(List<Category> cats) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize:     0.92,
        expand:           false,
        builder: (_, ctrl) => _CategorySheet(
          categories:          cats,
          scrollController:    ctrl,
          analysisData:        _analysisData,
          onCategorySelected:  _onCategorySelected,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final bottomP = MediaQuery.of(context).viewInsets.bottom;
    final amount  = double.tryParse(
        _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    final avgSpending =
        _analysisData?.monthlyAverage.averageSpending ?? 0.0;
    final dateF = DateFormat('d MMM', 'es_CO');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          // ── Header blur sticky ─────────────────────────────────────────
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                color: theme.scaffoldBackgroundColor.withOpacity(0.93),
                padding: EdgeInsets.only(
                    top: statusH + 10, left: 8,
                    right: 20, bottom: 14),
                child: Row(children: [
                  _BackBtn(),
                  const SizedBox(width: 4),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('SASPER',
                          style: _T.label(10,
                              w: FontWeight.w700,
                              c: onSurf.withOpacity(0.35))),
                      Text('Nuevo presupuesto',
                          style: _T.display(28, c: onSurf)),
                    ],
                  )),
                ]),
              ),
            ),
          ),

          // ── Preview compacto del presupuesto ──────────────────────────
          // Visible solo cuando hay categoría seleccionada.
          // Sin SliverPersistentHeader, sin pulsación, sin gradientes.
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: _selectedCategory != null
                ? _BudgetPreview(
                    category:  _selectedCategory!,
                    amount:    amount,
                    period:    _periodicity,
                    startDate: _startDate,
                    endDate:   _endDate,
                  )
                : const SizedBox.shrink(),
          ),

          // ── Scroll ────────────────────────────────────────────────────
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 24,
                bottom: bottomP > 0 ? bottomP + 100 : 120,
              ),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [

                      // ── Periodicidad ─────────────────────────────────
                      _GroupLabel('PERIODICIDAD'),
                      const SizedBox(height: 10),
                      _PeriodicityControl(
                        selected:  _periodicity,
                        onChanged: (p) {
                          HapticFeedback.selectionClick();
                          _calculateDates(p);
                        },
                      ),

                      // Selector de fechas custom
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: _periodicity == Periodicity.custom
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: _DateRangeTile(
                                  startDate: _startDate,
                                  endDate:   _endDate,
                                  onTap:     _pickDateRange,
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 28),

                      // ── Categoría ─────────────────────────────────────
                      _GroupLabel('CATEGORÍA'),
                      const SizedBox(height: 10),
                      FutureBuilder<List<Category>>(
                        future: _categoriesFuture,
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return _SkeletonTile();
                          }
                          return _CategoryTrigger(
                            category: _selectedCategory,
                            histAvg:  _categoryHistAvg,
                            onTap:    () =>
                                _openCategorySheet(snap.data!),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // ── Monto ─────────────────────────────────────────
                      _GroupLabel('LÍMITE DEL PERÍODO'),
                      const SizedBox(height: 10),
                      _AmountField(controller: _amountCtrl),
                      const SizedBox(height: 28),

                      // ── Insight — solo con categoría + monto reales ──
                      // Nunca muestra datos inventados.
                      // Aparece cuando: hay categoría + amount > 0.
                      // Si no hay historial de la categoría, muestra
                      // el % sobre el gasto mensual total (también real).
                      if (_selectedCategory != null && amount > 0)
                        _InsightSection(
                          amount:      amount,
                          histAvg:     _categoryHistAvg,
                          monthlyAvg:  avgSpending,
                          isLoading:   _analysisLoading,
                          categoryName: _selectedCategory!.name,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Botón guardar sticky ───────────────────────────────────────
          _SaveBtn(loading: _loading, onTap: _save),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUDGET PREVIEW — preview compacto sin pulsación
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetPreview extends StatelessWidget {
  final Category  category;
  final double    amount;
  final Periodicity period;
  final DateTime  startDate, endDate;
  const _BudgetPreview({
    required this.category,
    required this.amount,
    required this.period,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);
    final dateF  = DateFormat('d MMM', 'es_CO');
    final color  = category.colorAsObject;

    final periodLabel = switch (period) {
      Periodicity.weekly  => 'Semanal',
      Periodicity.monthly => 'Mensual',
      Periodicity.custom  => 'Personalizado',
    };

    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(children: [
        // Ícono sin gradiente ni borde animado
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Center(child: Icon(category.icon, size: 17, color: color)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category.name,
                style: _T.label(13, w: FontWeight.w700, c: onSurf)),
            const SizedBox(height: 1),
            Text(
              '$periodLabel · ${dateF.format(startDate)} – ${dateF.format(endDate)}',
              style: _T.label(11, c: onSurf.withOpacity(0.42))),
          ],
        )),
        // Monto — si es 0 muestra placeholder
        Text(
          amount > 0 ? _fmt.format(amount) : '—',
          style: _T.mono(16,
              c: amount > 0 ? onSurf : onSurf.withOpacity(0.25)),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERIODICITY CONTROL — segmented control iOS patrón establecido en la app
// ─────────────────────────────────────────────────────────────────────────────

class _PeriodicityControl extends StatelessWidget {
  final Periodicity selected;
  final ValueChanged<Periodicity> onChanged;
  const _PeriodicityControl({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final bg      = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final pillBg  = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    const labels = ['Semanal', 'Mensual', 'Personaliz.'];
    const values = [Periodicity.weekly, Periodicity.monthly, Periodicity.custom];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: List.generate(3, (i) {
          final isSel = selected == values[i];
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(values[i]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSel ? pillBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSel && !isDark
                      ? [BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(child: Text(labels[i],
                    style: _T.label(13,
                        w: isSel ? FontWeight.w700 : FontWeight.w500,
                        c: isSel
                            ? onSurf
                            : onSurf.withOpacity(0.45)))),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE RANGE TILE — selector de rango personalizado
// ─────────────────────────────────────────────────────────────────────────────

class _DateRangeTile extends StatefulWidget {
  final DateTime startDate, endDate;
  final VoidCallback onTap;
  const _DateRangeTile({
    required this.startDate, required this.endDate, required this.onTap});
  @override State<_DateRangeTile> createState() => _DateRangeTileState();
}

class _DateRangeTileState extends State<_DateRangeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final dateF  = DateFormat.yMMMd('es_CO');

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.98, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(Iconsax.calendar_edit, size: 16,
                  color: _kBlue),
              const SizedBox(width: 12),
              Expanded(child: Text(
                '${dateF.format(widget.startDate)}  →  ${dateF.format(widget.endDate)}',
                style: _T.label(13, c: onSurf, w: FontWeight.w600),
              )),
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: onSurf.withOpacity(0.25)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY TRIGGER — tile que abre el sheet de selección
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryTrigger extends StatefulWidget {
  final Category? category;
  final double    histAvg;
  final VoidCallback onTap;
  const _CategoryTrigger({
    required this.category,
    required this.histAvg,
    required this.onTap,
  });
  @override State<_CategoryTrigger> createState() => _CategoryTriggerState();
}

class _CategoryTriggerState extends State<_CategoryTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final cat   = widget.category;
    final color = cat?.colorAsObject ?? _kBlue;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              // Ícono de categoría — sin gradiente, sin borde animado
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(
                  cat?.icon ?? Iconsax.category,
                  size: 16,
                  color: color,
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cat?.name ?? 'Selecciona una categoría',
                    style: _T.label(14,
                        w: FontWeight.w600,
                        c: cat != null
                            ? onSurf
                            : onSurf.withOpacity(0.40)),
                  ),
                  // Promedio histórico si existe — dato real, útil antes de definir el monto
                  if (cat != null && widget.histAvg > 0) ...[
                    const SizedBox(height: 2),
                    Text('Promedio histórico: ${_fmtShort(widget.histAvg)}',
                        style: _T.label(11,
                            c: onSurf.withOpacity(0.40))),
                  ],
                ],
              )),
              Icon(Icons.chevron_right_rounded, size: 18,
                  color: onSurf.withOpacity(0.25)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AMOUNT FIELD — campo de monto principal
// ─────────────────────────────────────────────────────────────────────────────

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(18)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text('\$', style: _T.display(28, c: onSurf.withOpacity(0.35))),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller:   controller,
            textAlign:    TextAlign.left,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _CurrencyFormatter(),
            ],
            style: _T.display(40, c: onSurf),
            decoration: InputDecoration(
              border:      InputBorder.none,
              hintText:    '0',
              hintStyle:   _T.display(40, c: onSurf.withOpacity(0.15)),
              isDense:     true,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa un monto';
              final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
              if (n == null || n <= 0) return 'Monto inválido';
              return null;
            },
            onChanged: (_) => HapticFeedback.selectionClick(),
          ),
        ),
        Text('COP',
            style: _T.label(12,
                c: onSurf.withOpacity(0.30),
                w: FontWeight.w700)),
      ]),
    );
  }
}

class _CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue nw) {
    if (nw.text.isEmpty) return nw.copyWith(text: '');
    final n = int.tryParse(nw.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final t = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(n);
    return nw.copyWith(
        text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INSIGHT SECTION — solo datos reales, sin emojis, sin copy motivacional
// ─────────────────────────────────────────────────────────────────────────────
// Aparece solo cuando: categoría seleccionada + amount > 0.
// Muestra dos datos:
//   1. % del límite vs historial de la categoría (si existe).
//   2. % del límite vs gasto mensual total (siempre que haya datos).
// La barra usa el valor real calculado, no 0.9/0.6/0.3 hardcodeados.

class _InsightSection extends StatelessWidget {
  final double amount;
  final double histAvg;      // promedio histórico de la categoría
  final double monthlyAvg;   // gasto mensual promedio total
  final bool   isLoading;
  final String categoryName;

  const _InsightSection({
    required this.amount,
    required this.histAvg,
    required this.monthlyAvg,
    required this.isLoading,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: _SkeletonTile(),
      );
    }

    // ── Insight 1: vs historial de la categoría ──────────────────────────
    // Solo si hay historial. Sin historial, no inventamos datos.
    Widget? histInsight;
    if (histAvg > 0) {
      final pct  = amount / histAvg;       // 1.0 = igual al histórico
      final diff = amount - histAvg;
      final isOver  = diff > 0;
      final color   = isOver ? _kOrange : _kGreen;
      final barVal  = pct.clamp(0.0, 1.5) / 1.5; // normalizado para la barra

      final label = isOver
          ? '${_pct((diff / histAvg) * 100)} por encima de tu gasto histórico en $categoryName'
          : '${_pct(((histAvg - amount) / histAvg) * 100)} por debajo de tu gasto histórico';

      histInsight = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _InsightDot(color: color),
            const SizedBox(width: 8),
            Expanded(child:
              Text(label, style: _T.label(12, c: onSurf.withOpacity(0.65)))),
            Text(_fmtShort(histAvg),
                style: _T.mono(12, c: onSurf.withOpacity(0.40))),
          ]),
          const SizedBox(height: 8),
          _ProgressBar(value: barVal.clamp(0.0, 1.0), color: color),
        ],
      );
    }

    // ── Insight 2: % del gasto mensual total ─────────────────────────────
    Widget? monthlyInsight;
    if (monthlyAvg > 0) {
      final pct   = amount / monthlyAvg;
      final pctStr = _pct(pct * 100);
      Color color;
      if (pct > 0.40) {
        color = _kRed;
      } else if (pct > 0.20) {
        color = _kOrange;
      } else {
        color = _kGreen;
      }

      monthlyInsight = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _InsightDot(color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(
              '$pctStr de tu gasto mensual promedio',
              style: _T.label(12, c: onSurf.withOpacity(0.65)))),
            Text(_fmtShort(monthlyAvg),
                style: _T.mono(12, c: onSurf.withOpacity(0.40))),
          ]),
          const SizedBox(height: 8),
          _ProgressBar(value: pct.clamp(0.0, 1.0), color: color),
        ],
      );
    }

    // Sin datos de ningún tipo → no mostrar nada
    if (histInsight == null && monthlyInsight == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contexto del presupuesto',
                style: _T.label(12,
                    w: FontWeight.w700,
                    c: onSurf.withOpacity(0.50))),
            const SizedBox(height: 14),
            if (histInsight != null) histInsight,
            if (histInsight != null && monthlyInsight != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                    height: 0.5,
                    color: onSurf.withOpacity(0.08)),
              ),
            if (monthlyInsight != null) monthlyInsight,
          ],
        ),
      ),
    );
  }

  String _pct(double v) => '${v.toStringAsFixed(0)}%';
}

class _InsightDot extends StatelessWidget {
  final Color color;
  const _InsightDot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 6, height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final Color  color;
  const _ProgressBar({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.onSurface.withOpacity(0.07);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value:           value,
        minHeight:       4,
        backgroundColor: bg,
        valueColor:      AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CATEGORY SHEET — lista vertical con promedio histórico inline
// ─────────────────────────────────────────────────────────────────────────────
// Lista vertical en lugar de grid 4 columnas.
// Cada fila: ícono + nombre + promedio histórico (si disponible).
// El usuario ve el histórico ANTES de seleccionar — evita tener que
// seleccionar, ver el insight, volver y cambiar.

class _CategorySheet extends StatelessWidget {
  final List<Category>      categories;
  final ScrollController    scrollController;
  final AnalysisData?       analysisData;
  final Function(Category)  onCategorySelected;

  const _CategorySheet({
    required this.categories,
    required this.scrollController,
    required this.analysisData,
    required this.onCategorySelected,
  });

  double _avgFor(String name) {
    if (analysisData == null) return 0.0;
    return analysisData!.categoryAverages
        .firstWhere(
          (a) => a.categoryName == name,
          orElse: () => const CategoryAverageResult(
              categoryName: '', averageAmount: 0),
        )
        .averageAmount;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurf = theme.colorScheme.onSurface;
    final bg     = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg,
          child: Column(children: [
            // Handle
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: onSurf.withOpacity(0.15),
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Text('Categoría',
                    style: _T.display(22, c: onSurf))),
              ]),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: ListView.separated(
                controller:  scrollController,
                physics:     const BouncingScrollPhysics(),
                padding:     const EdgeInsets.symmetric(horizontal: 20),
                itemCount:   categories.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 36 + 12),
                  child: Container(
                      height: 0.5,
                      color: onSurf.withOpacity(0.07)),
                ),
                itemBuilder: (ctx, i) {
                  final cat   = categories[i];
                  final avg   = _avgFor(cat.name);
                  final color = cat.colorAsObject;

                  return _CategoryRow(
                    category: cat,
                    histAvg:  avg,
                    onTap:    () => onCategorySelected(cat),
                  );
                },
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
          ]),
        ),
      ),
    );
  }
}

class _CategoryRow extends StatefulWidget {
  final Category category;
  final double   histAvg;
  final VoidCallback onTap;
  const _CategoryRow({
    required this.category, required this.histAvg, required this.onTap});
  @override State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = widget.category.colorAsObject;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.50, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              // Ícono — borderRadius, sin RadialGradient ni Border
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(child: Icon(
                    widget.category.icon, size: 16, color: color)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.category.name,
                      style: _T.label(14, w: FontWeight.w600, c: onSurf)),
                  // Promedio histórico visible en la lista — dato real
                  if (widget.histAvg > 0) ...[
                    const SizedBox(height: 1),
                    Text('Promedio: ${_fmtShort(widget.histAvg)}',
                        style: _T.label(11,
                            c: onSurf.withOpacity(0.38))),
                  ],
                ],
              )),
              Icon(Icons.chevron_right_rounded, size: 16,
                  color: onSurf.withOpacity(0.20)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SAVE BUTTON — sticky bottom
// ─────────────────────────────────────────────────────────────────────────────

class _SaveBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SaveBtn({required this.loading, required this.onTap});
  @override State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: theme.scaffoldBackgroundColor.withOpacity(0.93),
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: GestureDetector(
            onTapDown: (_) {
              if (!widget.loading) {
                _c.forward(); HapticFeedback.mediumImpact();
              }
            },
            onTapUp:     (_) { _c.reverse(); if (!widget.loading) widget.onTap(); },
            onTapCancel: () => _c.reverse(),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Transform.scale(
                scale: lerpDouble(1.0, 0.97, _c.value)!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.loading
                        ? _kBlue.withOpacity(0.55) : _kBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white))
                        : Text('Crear presupuesto',
                            style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11,
            w: FontWeight.w700, c: onSurf.withOpacity(0.35)));
  }
}

class _SkeletonTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    return Container(
      height: 52,
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _BackBtn extends StatefulWidget {
  @override State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); Navigator.of(context).pop(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: _kBlue),
          ),
        ),
      ),
    );
  }
}