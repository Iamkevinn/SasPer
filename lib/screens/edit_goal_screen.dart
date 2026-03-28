// lib/screens/edit_goal_screen.dart
//
// Cambios respecto a la versión anterior:
//  · _notificationTime (TimeOfDay) — nueva variable de estado.
//  · initState: carga notificationHour/Minute desde widget.goal.
//  · _RitualCard y _DaySelector reciben notificationTime + onTimeChanged.
//  · _TimeTile — nuevo widget selector de hora (mismo estilo que el screen add).
//  · _save: pasa notificationHour/Minute a updated.copyWith y a scheduleGoalReminder.
//  · _requestSave: detecta cambio de hora como cambio relevante.
//  · scheduleGoalReminder recibe notificationHour + notificationMinute.
//  · _calculateNextReminderDate usa hora real.
//  Todo lo demás sin cambios estructurales.

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/screens/goal_notes_editor_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/smart_notification_worker.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

import 'package:workmanager/workmanager.dart';

// ─── Tokens ───────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s,
          fontWeight: w,
          color: c,
          letterSpacing: -0.4,
          height: 1.1);
  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);
}

const _kBlue = Color(0xFF0A84FF);
const _kGreen = Color(0xFF30D158);
const _kRed = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kPurple = Color(0xFFBF5AF2);

const _kPriorityColors = {
  GoalPriority.high: _kRed,
  GoalPriority.medium: _kOrange,
  GoalPriority.low: _kGreen,
};
const _kPriorityLabels = {
  GoalPriority.high: 'Alta',
  GoalPriority.medium: 'Media',
  GoalPriority.low: 'Baja',
};
const _kTimeframeLabels = {
  GoalTimeframe.short: 'Corto',
  GoalTimeframe.medium: 'Medio',
  GoalTimeframe.long: 'Largo',
  GoalTimeframe.custom: 'Custom',
};

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class EditGoalScreen extends StatefulWidget {
  final Goal goal;
  const EditGoalScreen({super.key, required this.goal});
  @override
  State<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen>
    with TickerProviderStateMixin {
  final _goalRepo = GoalRepository.instance;
  final _categoryRepo = CategoryRepository.instance;
  final _analysisRepo = AnalysisRepository.instance;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _targetCtrl;

  DateTime? _targetDate;
  GoalTimeframe _timeframe = GoalTimeframe.medium;
  GoalPriority _priority = GoalPriority.medium;
  String? _selectedCategoryId;

  bool _loading = false;
  bool _projectionReady = false;

  double _realMonthlyIncome = 0.0;
  FinancialProjection? _projection;
  List<Category>? _categories;

  Timer? _debounce;

  GoalSavingsFrequency? _savingsFrequency;
  int? _selectedDay;
  double? _savingsAmount;
  // ── NUEVO: hora de la notificación ────────────────────────────────────────
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);

  late final AnimationController _fadeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
  late final Animation<double> _fadeAnim =
      CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

  late final AnimationController _projCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final Animation<double> _projOpacity =
      CurvedAnimation(parent: _projCtrl, curve: Curves.easeOut);

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _nameCtrl = TextEditingController(text: g.name);
    _targetCtrl =
        TextEditingController(text: g.targetAmount.toStringAsFixed(0));
    _targetDate = g.targetDate;
    _timeframe = g.timeframe;
    _priority = g.priority;
    _selectedCategoryId = g.categoryId;
    _savingsFrequency = g.savingsFrequency;
    _selectedDay = g.savingsDayOfWeek ?? g.savingsDayOfMonth;
    _savingsAmount = g.savingsAmount;
    // ── Cargar hora guardada en el modelo ────────────────────────────────
    _notificationTime =
        TimeOfDay(hour: g.notificationHour, minute: g.notificationMinute);

    _targetCtrl.addListener(_onAmountChanged);
    _fadeCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    _debounce?.cancel();
    _fadeCtrl.dispose();
    _projCtrl.dispose();
    super.dispose();
  }

  // ── Cálculo de próxima fecha con hora real ────────────────────────────────
  DateTime? _calculateNextReminderDate({
    required GoalSavingsFrequency frequency,
    int? dayOfWeek,
    int? dayOfMonth,
  }) {
    final now = DateTime.now();
    final hour = _notificationTime.hour;
    final min = _notificationTime.minute;

    DateTime base = DateTime(now.year, now.month, now.day, hour, min);
    if (base.isBefore(now)) base = base.add(const Duration(days: 1));

    switch (frequency) {
      case GoalSavingsFrequency.daily:
        return base;
      case GoalSavingsFrequency.weekly:
        if (dayOfWeek == null) return base;
        while (base.weekday != dayOfWeek) {
          base = base.add(const Duration(days: 1));
        }
        if (base.isBefore(now)) base = base.add(const Duration(days: 7));
        return base;
      case GoalSavingsFrequency.monthly:
        if (dayOfMonth == null) return base;
        base = DateTime(now.year, now.month, dayOfMonth, hour, min);
        if (base.isBefore(now)) {
          base = DateTime(now.year, now.month + 1, dayOfMonth, hour, min);
        }
        return base;
    }
  }

  // ── Carga de datos ────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    await Future.wait([_loadCategories(), _loadFinancialData()]);
    _recalculate();
    if (mounted) setState(() => _projectionReady = true);
  }

  Future<void> _loadFinancialData() async {
    try {
      final data = await _analysisRepo.fetchAllAnalysisData();
      final summaries = data.incomeExpenseBarData;
      if (summaries.isNotEmpty) {
        _realMonthlyIncome =
            summaries.fold<double>(0.0, (s, e) => s + e.totalIncome) /
                summaries.length;
      }
    } catch (e) {
      developer.log('Error cargando análisis: $e', name: 'EditGoalScreen');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _categoryRepo.getCategories();
      if (mounted) {
        setState(() {
          _categories =
              cats.where((c) => c.type == CategoryType.expense).toList();
        });
      }
    } catch (e) {
      developer.log('Error cargando categorías: $e', name: 'EditGoalScreen');
    }
  }

  // ── Proyección ────────────────────────────────────────────────────────────
  void _onAmountChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _recalculate);
  }

  void _recalculate() {
    final amount = double.tryParse(_targetCtrl.text.replaceAll(',', '.')) ??
        widget.goal.targetAmount;
    final remaining = amount - widget.goal.currentAmount;
    if (_realMonthlyIncome < 1.0) return;

    final p = FinancialProjection.calculate(
      remainingAmount: remaining,
      targetDate: _targetDate,
      timeframe: _timeframe,
      userMonthlyIncome: _realMonthlyIncome,
      savingsFrequency: _savingsFrequency, // ← pasar la frecuencia
    );
    if (mounted) {
      setState(() => _projection = p);
      _projCtrl.forward(from: 0);
    }
  }

  // ── Selectores ────────────────────────────────────────────────────────────
  Future<void> _selectDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2101),
      locale: const Locale('es'),
    );
    if (picked != null && picked != _targetDate && mounted) {
      setState(() => _targetDate = picked);
      _recalculate();
    }
  }

  Future<void> _selectTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _notificationTime = picked);
    }
  }

  void _openCategorySheet() {
    if (_categories == null || _categories!.isEmpty) return;
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ctrl) => _CategorySheet(
          categories: _categories!,
          selectedId: _selectedCategoryId,
          scrollController: ctrl,
          onSelected: (cat) {
            HapticFeedback.selectionClick();
            setState(() => _selectedCategoryId = cat.id);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _applySuggestion(RecommendationType type) {
    if (_projection == null) return;
    HapticFeedback.mediumImpact();
    switch (type) {
      case RecommendationType.extendDeadline:
        setState(() => _targetDate = DateTime.now()
            .add(Duration(days: _projection!.suggestedMonths * 30)));
        break;
      case RecommendationType.reduceTarget:
        _targetCtrl.text = (widget.goal.targetAmount * 0.8).toStringAsFixed(0);
        break;
      case RecommendationType.increaseContribution:
        break;
    }
    _recalculate();
    NotificationHelper.show(
        message: 'Sugerencia aplicada', type: NotificationType.info);
  }

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _requestSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    final newName = _nameCtrl.text.trim();
    final newAmount = double.parse(_targetCtrl.text.replaceAll(',', '.'));
    final g = widget.goal;

    final hasChanges = newName != g.name ||
        newAmount != g.targetAmount ||
        _targetDate != g.targetDate ||
        _selectedCategoryId != g.categoryId ||
        _priority != g.priority ||
        _timeframe != g.timeframe ||
        _savingsFrequency != g.savingsFrequency ||
        _selectedDay != (g.savingsDayOfWeek ?? g.savingsDayOfMonth)
        // ── NUEVO: cambio de hora también es cambio relevante ────────────
        ||
        _notificationTime.hour != g.notificationHour ||
        _notificationTime.minute != g.notificationMinute;

    if (!hasChanges) {
      await _showNoChangesSheet();
      return;
    }

    final confirmed = await _showConfirmSheet(
      newName: newName,
      newAmount: newAmount,
      nameChanged: newName != g.name,
      amountChanged: newAmount != g.targetAmount,
      dateChanged: _targetDate != g.targetDate,
    );
    if (confirmed == true) await _save();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final targetAmt = double.parse(_targetCtrl.text.replaceAll(',', '.'));
      final remaining = targetAmt - widget.goal.currentAmount;
      final days = FinancialProjection._days(_targetDate, _timeframe);
      final safeDays = days > 0 ? days : 1;

      final currentDaily = remaining / safeDays;
      final currentWeekly = remaining / math.max(1, (safeDays / 7).ceil());
      final currentMonthly =
          remaining / math.max(1, (safeDays / 30.437).ceil());

      final nextReminder = (_savingsFrequency != null &&
              (_savingsFrequency == GoalSavingsFrequency.daily ||
                  _selectedDay != null))
          ? _calculateNextReminderDate(
              frequency: _savingsFrequency!,
              dayOfWeek: _savingsFrequency == GoalSavingsFrequency.weekly
                  ? _selectedDay
                  : null,
              dayOfMonth: _savingsFrequency == GoalSavingsFrequency.monthly
                  ? _selectedDay
                  : null,
            )
          : null;

      final updated = widget.goal.copyWith(
        name: _nameCtrl.text.trim(),
        targetAmount: double.parse(_targetCtrl.text.replaceAll(',', '.')),
        targetDate: _targetDate,
        priority: _priority,
        categoryId: _selectedCategoryId,
        timeframe: _timeframe,
        savingsFrequency: _savingsFrequency,
        savingsDayOfWeek: _savingsFrequency == GoalSavingsFrequency.weekly
            ? _selectedDay
            : null,
        savingsDayOfMonth: _savingsFrequency == GoalSavingsFrequency.monthly
            ? _selectedDay
            : null,
        savingsAmount: _savingsFrequency == null
            ? null
            : (switch (_savingsFrequency!) {
                GoalSavingsFrequency.daily => currentDaily,
                GoalSavingsFrequency.weekly => currentWeekly,
                GoalSavingsFrequency.monthly => currentMonthly,
              }),
        nextReminderDate: nextReminder,
        notificationHour: _notificationTime.hour,
        notificationMinute: _notificationTime.minute,
      );

      await _goalRepo.updateGoal(updated);

      if (updated.savingsFrequency == null) {
        // Si el usuario apagó el recordatorio, cancelamos los slots de inmediato.
        await NotificationService.instance.cancelGoalReminder(updated.id);
      } else {
        // 1. Limpiar flags para permitir reajustes si fueran necesarios hoy
        final prefs = await SharedPreferences.getInstance();
        final now = DateTime.now();
        final dedupToday = '${now.year}_${now.month}_${now.day}';
        await prefs.remove('reajuste_${updated.id}_$dedupToday');

        // 2. Despertamos al Worker. Analizará si agendar para hoy (si pusiste una hora futura)
        // o para mañana (si pusiste una hora pasada).
        Workmanager().registerOneOffTask(
          "force_goal_check_${DateTime.now().millisecondsSinceEpoch}",
          smartGoalTask,
          initialDelay: const Duration(seconds: 3),
        );
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      EventService.instance.fire(AppEvent.goalUpdated);
      Navigator.of(context).pop(true);
      NotificationHelper.show(
          message: 'Meta actualizada', type: NotificationType.success);
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
            message: 'Error al actualizar.', type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Sheets ────────────────────────────────────────────────────────────────
  Future<bool?> _showConfirmSheet({
    required String newName,
    required double newAmount,
    required bool nameChanged,
    required bool amountChanged,
    required bool dateChanged,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(
        goal: widget.goal,
        newName: newName,
        newAmount: newAmount,
        newDate: _targetDate,
        nameChanged: nameChanged,
        amountChanged: amountChanged,
        dateChanged: dateChanged,
        projection: _projection,
      ),
    );
  }

  Future<void> _showNoChangesSheet() {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
        final onSurf = theme.colorScheme.onSurface;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: bg,
              padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 8,
                  bottom: MediaQuery.of(context).padding.bottom + 24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: onSurf.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(15)),
                  child: const Center(
                      child:
                          Icon(Iconsax.info_circle, size: 22, color: _kBlue)),
                ),
                const SizedBox(height: 14),
                Text('Sin cambios', style: _T.display(19, c: onSurf)),
                const SizedBox(height: 8),
                Text('No modificaste ningún campo.',
                    textAlign: TextAlign.center,
                    style: _T.label(14,
                        c: onSurf.withOpacity(0.50), w: FontWeight.w400)),
                const SizedBox(height: 24),
                _SheetBtn(
                    label: 'Entendido',
                    color: _kBlue,
                    onTap: () => Navigator.pop(context)),
              ]),
            ),
          ),
        );
      },
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurf = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final bottomP = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Column(children: [
          // Header blur
          ClipRect(
              child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.93),
              padding: EdgeInsets.only(
                  top: statusH + 10, left: 8, right: 16, bottom: 14),
              child: Row(children: [
                _BackBtn(),
                const SizedBox(width: 4),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SASPER',
                        style: _T.label(10,
                            w: FontWeight.w700, c: onSurf.withOpacity(0.35))),
                    Text('Editar meta', style: _T.display(28, c: onSurf)),
                  ],
                )),
              ]),
            ),
          )),

          Expanded(
              child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: bottomP > 0 ? bottomP + 100 : 120,
            ),
            children: [
              Form(
                key: _formKey,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GoalContextCard(goal: widget.goal),
                      const SizedBox(height: 28),
                      _GroupLabel('NOMBRE'),
                      const SizedBox(height: 10),
                      _NameField(controller: _nameCtrl),
                      const SizedBox(height: 28),
                      _GroupLabel('MONTO OBJETIVO'),
                      const SizedBox(height: 10),
                      _AmountField(controller: _targetCtrl),
                      const SizedBox(height: 28),
                      _GroupLabel('FECHA LÍMITE  ·  OPCIONAL'),
                      const SizedBox(height: 10),
                      _DateTile(
                        date: _targetDate,
                        onTap: _selectDate,
                        onClear: () {
                          HapticFeedback.lightImpact();
                          setState(() => _targetDate = null);
                          _recalculate();
                        },
                      ),
                      const SizedBox(height: 28),
                      if (_projectionReady) ...[
                        if (_projection != null) ...[
                          _GroupLabel('PROYECCIÓN'),
                          const SizedBox(height: 10),
                          FadeTransition(
                            opacity: _projOpacity,
                            child: _ProjectionCard(projection: _projection!),
                          ),
                          if (_projection!.status !=
                              ViabilityStatus.feasible) ...[
                            const SizedBox(height: 16),
                            _GroupLabel('SUGERENCIAS'),
                            const SizedBox(height: 10),
                            _SuggestionsRow(
                                projection: _projection!,
                                onApply: _applySuggestion),
                          ],
                          const SizedBox(height: 28),

                          // ── RITUAL CON HORA ──────────────────────────────────
                          _GroupLabel('RECORDATORIO DE AHORRO'),
                          const SizedBox(height: 10),
                          _RitualCard(
                            savingsFrequency: _savingsFrequency,
                            selectedDay: _selectedDay,
                            notificationTime: _notificationTime,
                            onFrequencyChanged: (freq) => setState(() {
                              _savingsFrequency = freq;
                              _selectedDay = null;
                            }),
                            onDayChanged: (day) =>
                                setState(() => _selectedDay = day),
                            onTimeChanged: (t) =>
                                setState(() => _notificationTime = t),
                          ),
                          const SizedBox(height: 28),
                        ],
                      ] else ...[
                        _GroupLabel('PROYECCIÓN'),
                        const SizedBox(height: 10),
                        _SkeletonRow(),
                        const SizedBox(height: 28),
                      ],
                      _GroupLabel('PRIORIDAD'),
                      const SizedBox(height: 10),
                      _PriorityTiles(
                        selected: _priority,
                        onChanged: (p) {
                          HapticFeedback.selectionClick();
                          setState(() => _priority = p);
                        },
                      ),
                      const SizedBox(height: 28),
                      _GroupLabel('PLAZO'),
                      const SizedBox(height: 10),
                      _TimeframeTiles(
                        selected: _timeframe,
                        onChanged: (t) {
                          HapticFeedback.selectionClick();
                          setState(() => _timeframe = t);
                          _recalculate();
                        },
                      ),
                      const SizedBox(height: 28),
                      _GroupLabel('CATEGORÍA  ·  OPCIONAL'),
                      const SizedBox(height: 10),
                      _CategoryTrigger(
                          categories: _categories,
                          selectedId: _selectedCategoryId,
                          onTap: _openCategorySheet),
                      const SizedBox(height: 28),
                      _GroupLabel('NOTAS  ·  OPCIONAL'),
                      const SizedBox(height: 10),
                      _NoteTile(onTap: () async {
                        await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    GoalNotesEditorScreen(goal: widget.goal)));
                      }),
                    ]),
              )
            ],
          )),

          _SaveBtn(loading: _loading, onTap: _requestSave),
        ]),
      ),
    );
  }
}

// ─── _RitualCard (con hora) ───────────────────────────────────────────────────
class _RitualCard extends StatelessWidget {
  final GoalSavingsFrequency? savingsFrequency;
  final int? selectedDay;
  final TimeOfDay notificationTime;
  final Function(GoalSavingsFrequency?) onFrequencyChanged;
  final Function(int) onDayChanged;
  final Function(TimeOfDay) onTimeChanged;

  const _RitualCard({
    required this.savingsFrequency,
    required this.selectedDay,
    required this.notificationTime,
    required this.onFrequencyChanged,
    required this.onDayChanged,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(children: [
        Row(children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _kPurple.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
                child:
                    Icon(Iconsax.notification_bing, size: 14, color: _kPurple)),
          ),
          const SizedBox(width: 10),
          Text('Activar recordatorio',
              style: _T.label(13,
                  w: FontWeight.w700,
                  c: Theme.of(context).colorScheme.onSurface)),
        ]),
        const SizedBox(height: 14),

        _FrequencySelector(
            selected: savingsFrequency, onChanged: onFrequencyChanged),

        if (savingsFrequency != null &&
            savingsFrequency != GoalSavingsFrequency.daily)
          _DaySelector(
            frequency: savingsFrequency!,
            selectedDay: selectedDay,
            onDayChanged: onDayChanged,
          ),

        // ── NUEVO: Selector de hora ────────────────────────────────────
        if (savingsFrequency != null) ...[
          const SizedBox(height: 12),
          _TimeTile(
            time: notificationTime,
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: notificationTime,
                builder: (ctx, child) => MediaQuery(
                  data:
                      MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
                  child: child!,
                ),
              );
              if (picked != null) onTimeChanged(picked);
            },
          ),
        ],
      ]),
    );
  }
}

// ─── _TimeTile ────────────────────────────────────────────────────────────────
class _TimeTile extends StatefulWidget {
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeTile({required this.time, required this.onTap});
  @override
  State<_TimeTile> createState() => _TimeTileState();
}

class _TimeTileState extends State<_TimeTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final timeStr = widget.time.format(context);

    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: _kPurple.withOpacity(0.25), width: 0.5)),
            child: Row(children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _kPurple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                    child: Icon(Iconsax.clock, size: 14, color: _kPurple)),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Hora del recordatorio',
                        style: _T.label(11,
                            c: onSurf.withOpacity(0.45), w: FontWeight.w400)),
                    const SizedBox(height: 2),
                    Text(timeStr,
                        style: _T.label(14, c: _kPurple, w: FontWeight.w700)),
                  ])),
              Icon(Icons.keyboard_arrow_down_rounded,
                  size: 15, color: onSurf.withOpacity(0.28)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Resto de widgets (sin cambios) ──────────────────────────────────────────

class _GoalContextCard extends StatelessWidget {
  final Goal goal;
  const _GoalContextCard({required this.goal});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.black.withOpacity(0.03);
    final fmt =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);
    final pct = (progress * 100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(goal.name,
                  style: _T.label(14, w: FontWeight.w700, c: onSurf),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
          Text('$pct%', style: _T.mono(14, c: _kBlue, w: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: onSurf.withOpacity(0.08),
              valueColor: const AlwaysStoppedAnimation(_kBlue),
            )),
        const SizedBox(height: 10),
        Row(children: [
          Text(fmt.format(goal.currentAmount),
              style: _T.mono(12, c: _kGreen, w: FontWeight.w600)),
          Text(' de ', style: _T.label(12, c: onSurf.withOpacity(0.40))),
          Text(fmt.format(goal.targetAmount),
              style: _T.mono(12, c: onSurf.withOpacity(0.60))),
        ]),
      ]),
    );
  }
}

class _NameField extends StatefulWidget {
  final TextEditingController controller;
  const _NameField({required this.controller});
  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  final _focus = FocusNode();
  bool _hasFocus = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _hasFocus = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: _hasFocus
              ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5)),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        style: _T.label(15, c: onSurf),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          hintText: 'Nombre de la meta',
          hintStyle: _T.label(15, c: onSurf.withOpacity(0.28)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(Iconsax.flag,
                  size: 17,
                  color: _hasFocus ? _kBlue : onSurf.withOpacity(0.30))),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        validator: (v) => (v == null || v.trim().isEmpty)
            ? 'El nombre no puede estar vacío'
            : null,
      ),
    );
  }
}

class _AmountField extends StatefulWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});
  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  final _focus = FocusNode();
  bool _hasFocus = false;
  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _hasFocus = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final hasVal = widget.controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: _hasFocus
              ? Border.all(color: _kBlue.withOpacity(0.60), width: 1.5)
              : Border.all(color: Colors.transparent, width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text('\$',
              style: _T.mono(22,
                  c: hasVal ? _kBlue : onSurf.withOpacity(0.25),
                  w: FontWeight.w400)),
          const SizedBox(width: 8),
          Expanded(
              child: TextFormField(
            controller: widget.controller,
            focusNode: _focus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: _T.mono(28, c: hasVal ? onSurf : onSurf.withOpacity(0.25)),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: _T.mono(28, c: onSurf.withOpacity(0.20)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa un monto';
              final n = double.tryParse(v.replaceAll(',', '.'));
              if (n == null || n <= 0) return 'Monto inválido';
              return null;
            },
          )),
          Text('COP',
              style: _T.label(11,
                  c: onSurf.withOpacity(0.28), w: FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _DateTile extends StatefulWidget {
  final DateTime? date;
  final VoidCallback onTap, onClear;
  const _DateTile(
      {required this.date, required this.onTap, required this.onClear});
  @override
  State<_DateTile> createState() => _DateTileState();
}

class _DateTileState extends State<_DateTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final hasDate = widget.date != null;
    final dateStr = hasDate
        ? DateFormat('d \'de\' MMMM, yyyy', 'es').format(widget.date!)
        : 'Seleccionar fecha';
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: hasDate
                        ? _kBlue.withOpacity(0.10)
                        : onSurf.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                      child: Icon(Iconsax.calendar_1,
                          size: 15,
                          color: hasDate ? _kBlue : onSurf.withOpacity(0.30)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(dateStr,
                      style: _T.label(14,
                          w: FontWeight.w600,
                          c: hasDate ? onSurf : onSurf.withOpacity(0.38)))),
              if (hasDate)
                GestureDetector(
                  onTap: widget.onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.close_rounded,
                          size: 15, color: onSurf.withOpacity(0.28))),
                )
              else
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: onSurf.withOpacity(0.22)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  final FinancialProjection projection;
  const _ProjectionCard({required this.projection});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final p = projection;
    final fmt =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final statusColor = switch (p.status) {
      ViabilityStatus.feasible => _kGreen,
      ViabilityStatus.challenging => _kOrange,
      ViabilityStatus.highRisk => _kRed,
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: statusColor)),
          const SizedBox(width: 8),
          Text(p.status.title,
              style: _T.label(13, w: FontWeight.w700, c: statusColor)),
          const SizedBox(width: 6),
          Text('· ${p.status.subtitle}',
              style: _T.label(12,
                  c: onSurf.withOpacity(0.45), w: FontWeight.w400)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          // Cuota real según frecuencia del usuario
          _ProjMetric(
            label: p.periodLabel, // "Diario" / "Semanal" / "Mensual"
            value: fmt.format(p.periodicAmount),
            color: statusColor,
          ),
          _ProjDot(c: onSurf),
          // Número de cuotas restantes
          _ProjMetric(
            label: p.periodLabel == 'Diario'
                ? 'Días'
                : p.periodLabel == 'Semanal'
                    ? 'Semanas'
                    : 'Meses',
            value: '${p.periodsRemaining}',
            color: onSurf,
          ),
          _ProjDot(c: onSurf),
          _ProjMetric(
            label: 'Del ingreso',
            value: '${p.percentageOfIncome.toStringAsFixed(0)}%',
            color: p.percentageOfIncome > 50 ? _kRed : onSurf,
          ),
        ]),
      ]),
    );
  }
}

class _ProjMetric extends StatelessWidget {
  final String label, value;
  final Color color;
  const _ProjMetric(
      {required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Expanded(
        child: Column(children: [
      Text(value, style: _T.mono(15, c: color, w: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label,
          style: _T.label(10, c: onSurf.withOpacity(0.40)),
          textAlign: TextAlign.center),
    ]));
  }
}

class _ProjDot extends StatelessWidget {
  final Color c;
  const _ProjDot({required this.c});
  @override
  Widget build(BuildContext context) => Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration:
          BoxDecoration(shape: BoxShape.circle, color: c.withOpacity(0.15)));
}

class _SuggestionsRow extends StatelessWidget {
  final FinancialProjection projection;
  final ValueChanged<RecommendationType> onApply;
  const _SuggestionsRow({required this.projection, required this.onApply});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final fmt =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final p = projection;
    final items = [
      _SuggestionItem(
          type: RecommendationType.extendDeadline,
          label: 'Extender plazo',
          detail: '+${p.suggestedMonths} meses',
          icon: Iconsax.calendar_add,
          color: _kBlue),
      _SuggestionItem(
          type: RecommendationType.increaseContribution,
          label: 'Aumentar aporte',
          detail: fmt.format(p.monthlyNeeded * 1.5),
          icon: Iconsax.arrow_up_1,
          color: _kGreen,
          readOnly: true),
      _SuggestionItem(
          type: RecommendationType.reduceTarget,
          label: 'Reducir objetivo',
          detail: '-20% (${fmt.format(p.remainingAmount * 0.8)})',
          icon: Iconsax.arrow_down_1,
          color: _kOrange),
    ];
    return Container(
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: items.indexed.map((e) {
          final (i, item) = e;
          return _SuggestionTile(
              item: item,
              showDivider: i < items.length - 1,
              onApply: item.readOnly ? null : () => onApply(item.type));
        }).toList(),
      ),
    );
  }
}

class _SuggestionItem {
  final RecommendationType type;
  final String label, detail;
  final IconData icon;
  final Color color;
  final bool readOnly;
  const _SuggestionItem(
      {required this.type,
      required this.label,
      required this.detail,
      required this.icon,
      required this.color,
      this.readOnly = false});
}

class _SuggestionTile extends StatefulWidget {
  final _SuggestionItem item;
  final bool showDivider;
  final VoidCallback? onApply;
  const _SuggestionTile(
      {required this.item, required this.showDivider, this.onApply});
  @override
  State<_SuggestionTile> createState() => _SuggestionTileState();
}

class _SuggestionTileState extends State<_SuggestionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final item = widget.item;
    final canTap = widget.onApply != null;
    return GestureDetector(
      onTapDown: canTap
          ? (_) {
              _c.forward();
              HapticFeedback.selectionClick();
            }
          : null,
      onTapUp: canTap
          ? (_) {
              _c.reverse();
              widget.onApply!();
            }
          : null,
      onTapCancel: canTap ? () => _c.reverse() : null,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, canTap ? 0.55 : 1.0, _c.value)!,
          child: Column(children: [
            Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: Row(children: [
                  Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: item.color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                          child: Icon(item.icon, size: 15, color: item.color))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(item.label,
                          style: _T.label(14, w: FontWeight.w600, c: onSurf))),
                  Text(item.detail,
                      style: _T.mono(12,
                          c: canTap ? item.color : onSurf.withOpacity(0.40),
                          w: FontWeight.w600)),
                  if (canTap) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.chevron_right_rounded,
                        size: 15, color: onSurf.withOpacity(0.22)),
                  ],
                ])),
            if (widget.showDivider)
              Padding(
                  padding: const EdgeInsets.only(left: 14 + 34 + 12),
                  child:
                      Container(height: 0.5, color: onSurf.withOpacity(0.07))),
          ]),
        ),
      ),
    );
  }
}

class _PriorityTiles extends StatelessWidget {
  final GoalPriority selected;
  final ValueChanged<GoalPriority> onChanged;
  const _PriorityTiles({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final pillBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
          children: GoalPriority.values.map((p) {
        final isSel = p == selected;
        final color = _kPriorityColors[p]!;
        return Expanded(
            child: GestureDetector(
          onTap: () => onChanged(p),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSel ? pillBg : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: isSel && !isDark
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Text(_kPriorityLabels[p]!,
                textAlign: TextAlign.center,
                style: _T.label(13,
                    w: isSel ? FontWeight.w700 : FontWeight.w500,
                    c: isSel
                        ? color
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.45))),
          ),
        ));
      }).toList()),
    );
  }
}

class _TimeframeTiles extends StatelessWidget {
  final GoalTimeframe selected;
  final ValueChanged<GoalTimeframe> onChanged;
  const _TimeframeTiles({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final pillBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
          children: GoalTimeframe.values.map((t) {
        final isSel = t == selected;
        return Expanded(
            child: GestureDetector(
          onTap: () => onChanged(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: isSel ? pillBg : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: isSel && !isDark
                  ? [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 6,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
            child: Text(_kTimeframeLabels[t]!,
                textAlign: TextAlign.center,
                style: _T.label(13,
                    w: isSel ? FontWeight.w700 : FontWeight.w500,
                    c: isSel ? _kBlue : onSurf.withOpacity(0.45))),
          ),
        ));
      }).toList()),
    );
  }
}

class _CategoryTrigger extends StatefulWidget {
  final List<Category>? categories;
  final String? selectedId;
  final VoidCallback onTap;
  const _CategoryTrigger(
      {required this.categories,
      required this.selectedId,
      required this.onTap});
  @override
  State<_CategoryTrigger> createState() => _CategoryTriggerState();
}

class _CategoryTriggerState extends State<_CategoryTrigger>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final cats = widget.categories;
    final cat = cats
        ?.cast<Category?>()
        .firstWhere((c) => c!.id == widget.selectedId, orElse: () => null);
    final color = cat?.colorAsObject ?? _kBlue;
    final loading = cats == null;
    return GestureDetector(
      onTapDown: loading
          ? null
          : (_) {
              _c.forward();
              HapticFeedback.selectionClick();
            },
      onTapUp: loading
          ? null
          : (_) {
              _c.reverse();
              widget.onTap();
            },
      onTapCancel: loading ? null : () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: loading
                ? Row(children: [
                    Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: onSurf.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10))),
                    const SizedBox(width: 12),
                    Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                            color: onSurf.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(4))),
                  ])
                : Row(children: [
                    Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(10)),
                        child: Center(
                            child: Icon(cat?.icon ?? Iconsax.category,
                                size: 15, color: color))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(cat?.name ?? 'Seleccionar categoría',
                            style: _T.label(14,
                                w: FontWeight.w600,
                                c: cat != null
                                    ? onSurf
                                    : onSurf.withOpacity(0.38)))),
                    Icon(Icons.chevron_right_rounded,
                        size: 17, color: onSurf.withOpacity(0.22)),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _CategorySheet extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ScrollController scrollController;
  final ValueChanged<Category> onSelected;
  const _CategorySheet(
      {required this.categories,
      required this.selectedId,
      required this.scrollController,
      required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
            color: bg,
            child: Column(children: [
              const SizedBox(height: 8),
              Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: onSurf.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Categoría', style: _T.display(22, c: onSurf))),
              const SizedBox(height: 12),
              Expanded(
                  child: ListView.separated(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: categories.length,
                separatorBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.only(left: 46),
                  child:
                      Container(height: 0.5, color: onSurf.withOpacity(0.07)),
                ),
                itemBuilder: (_, i) => _CatRow(
                  category: categories[i],
                  isSelected: categories[i].id == selectedId,
                  onTap: () => onSelected(categories[i]),
                ),
              )),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ])),
      ),
    );
  }
}

class _CatRow extends StatefulWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;
  const _CatRow(
      {required this.category, required this.isSelected, required this.onTap});
  @override
  State<_CatRow> createState() => _CatRowState();
}

class _CatRowState extends State<_CatRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color = widget.category.colorAsObject;
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.50, _c.value)!,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(children: [
                Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Icon(widget.category.icon ?? Iconsax.category,
                            size: 15, color: color))),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(widget.category.name,
                        style: _T.label(14, w: FontWeight.w600, c: onSurf))),
                AnimatedOpacity(
                  opacity: widget.isSelected ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child:
                      const Icon(Icons.check_rounded, size: 17, color: _kBlue),
                ),
              ])),
        ),
      ),
    );
  }
}

class _NoteTile extends StatefulWidget {
  final VoidCallback onTap;
  const _NoteTile({required this.onTap});
  @override
  State<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<_NoteTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Opacity(
          opacity: lerpDouble(1.0, 0.55, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Center(
                      child: Icon(Iconsax.document_text_1,
                          size: 15, color: _kBlue))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Abrir editor de notas',
                        style: _T.label(14,
                            w: FontWeight.w600,
                            c: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 1),
                    Text('Añade enlaces, ideas y apuntes importantes',
                        style: _T.label(11,
                            c: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.40),
                            w: FontWeight.w400)),
                  ])),
              Icon(Icons.chevron_right_rounded,
                  size: 17,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.22)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final Goal goal;
  final String newName;
  final double newAmount;
  final DateTime? newDate;
  final bool nameChanged, amountChanged, dateChanged;
  final FinancialProjection? projection;
  const _ConfirmSheet(
      {required this.goal,
      required this.newName,
      required this.newAmount,
      required this.newDate,
      required this.nameChanged,
      required this.amountChanged,
      required this.dateChanged,
      this.projection});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final fmt =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final dateF = DateFormat.yMMMd('es_CO');
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg,
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: MediaQuery.of(context).padding.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: onSurf.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('Confirmar cambios', style: _T.display(19, c: onSurf)),
            const SizedBox(height: 6),
            Text('Revisa antes de guardar',
                style: _T.label(13,
                    c: onSurf.withOpacity(0.45), w: FontWeight.w400)),
            const SizedBox(height: 20),
            if (nameChanged)
              _ChangeRow(
                  label: 'Nombre',
                  oldValue: goal.name,
                  newValue: newName,
                  onSurf: onSurf),
            if (amountChanged)
              _ChangeRow(
                  label: 'Monto',
                  oldValue: fmt.format(goal.targetAmount),
                  newValue: fmt.format(newAmount),
                  onSurf: onSurf),
            if (dateChanged)
              _ChangeRow(
                  label: 'Fecha',
                  oldValue: goal.targetDate != null
                      ? dateF.format(goal.targetDate!)
                      : 'Sin fecha',
                  newValue:
                      newDate != null ? dateF.format(newDate!) : 'Sin fecha',
                  onSurf: onSurf),
            if (projection != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Icon(Iconsax.cpu, size: 14, color: _kBlue),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                    'Aporte mensual proyectado: '
                    '${fmt.format(projection!.monthlyNeeded)} '
                    'durante ${projection!.monthsRemaining} meses',
                    style: _T.label(12,
                        c: onSurf.withOpacity(0.60), w: FontWeight.w400),
                  )),
                ]),
              ),
            ],
            const SizedBox(height: 24),
            _SheetBtn(
                label: 'Guardar cambios',
                color: _kBlue,
                onTap: () => Navigator.pop(context, true)),
            const SizedBox(height: 10),
            _SheetBtn(
                label: 'Cancelar',
                color: onSurf.withOpacity(0.08),
                textColor: onSurf,
                onTap: () => Navigator.pop(context, false)),
          ]),
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final String label, oldValue, newValue;
  final Color onSurf;
  const _ChangeRow(
      {required this.label,
      required this.oldValue,
      required this.newValue,
      required this.onSurf});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          SizedBox(
              width: 60,
              child: Text(label,
                  style: _T.label(13, c: onSurf.withOpacity(0.45)))),
          Expanded(
              child: Text(oldValue,
                  style: _T
                      .label(13,
                          c: onSurf.withOpacity(0.38), w: FontWeight.w400)
                      .copyWith(decoration: TextDecoration.lineThrough),
                  overflow: TextOverflow.ellipsis)),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 13, color: _kBlue)),
          Expanded(
              child: Text(newValue,
                  style: _T.label(13, c: _kBlue, w: FontWeight.w700),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11, w: FontWeight.w700, c: onSurf.withOpacity(0.35)));
  }
}

class _SkeletonRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    return Container(
        height: 72,
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)));
  }
}

class _SheetBtn extends StatefulWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;
  const _SheetBtn(
      {required this.label,
      required this.color,
      required this.onTap,
      this.textColor});
  @override
  State<_SheetBtn> createState() => _SheetBtnState();
}

class _SheetBtnState extends State<_SheetBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Container(
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
                color: widget.color, borderRadius: BorderRadius.circular(14)),
            child: Center(
                child: Text(widget.label,
                    style: _T.label(16,
                        c: widget.textColor ?? Colors.white,
                        w: FontWeight.w700))),
          ),
        ),
      ),
    );
  }
}

class _SaveBtn extends StatefulWidget {
  final bool loading;
  final VoidCallback onTap;
  const _SaveBtn({required this.loading, required this.onTap});
  @override
  State<_SaveBtn> createState() => _SaveBtnState();
}

class _SaveBtnState extends State<_SaveBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 80));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRect(
        child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        color: theme.scaffoldBackgroundColor.withOpacity(0.93),
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12),
        child: GestureDetector(
          onTapDown: (_) {
            if (!widget.loading) {
              _c.forward();
              HapticFeedback.mediumImpact();
            }
          },
          onTapUp: (_) {
            _c.reverse();
            if (!widget.loading) widget.onTap();
          },
          onTapCancel: () => _c.reverse(),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Transform.scale(
              scale: lerpDouble(1.0, 0.97, _c.value)!,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 54,
                decoration: BoxDecoration(
                  color: widget.loading ? _kBlue.withOpacity(0.55) : _kBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                    child: widget.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Text('Guardar cambios',
                            style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white))),
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class _BackBtn extends StatefulWidget {
  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        HapticFeedback.selectionClick();
      },
      onTapUp: (_) {
        _c.reverse();
        Navigator.of(context).pop();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: _kBlue)),
        ),
      ),
    );
  }
}

class _FrequencySelector extends StatelessWidget {
  final GoalSavingsFrequency? selected;
  final Function(GoalSavingsFrequency?) onChanged;
  const _FrequencySelector({required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Row(
        children: GoalSavingsFrequency.values.map((freq) {
      final isSelected = selected == freq;
      final label = switch (freq) {
        GoalSavingsFrequency.daily => 'Diario',
        GoalSavingsFrequency.weekly => 'Semanal',
        GoalSavingsFrequency.monthly => 'Mensual',
      };
      return Expanded(
          child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(isSelected ? null : freq);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? _kPurple.withOpacity(0.12)
                : (isDark ? Colors.white.withOpacity(0.05) : Colors.white),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? _kPurple.withOpacity(0.4)
                  : onSurf.withOpacity(0.1),
              width: isSelected ? 1.0 : 0.5,
            ),
          ),
          child: Center(
              child: Text(label,
                  style: _T.label(12,
                      w: isSelected ? FontWeight.w700 : FontWeight.w500,
                      c: isSelected ? _kPurple : onSurf.withOpacity(0.6)))),
        ),
      ));
    }).toList());
  }
}

class _DaySelector extends StatelessWidget {
  final GoalSavingsFrequency frequency;
  final int? selectedDay;
  final Function(int) onDayChanged;
  const _DaySelector(
      {required this.frequency,
      required this.selectedDay,
      required this.onDayChanged});
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    if (frequency == GoalSavingsFrequency.weekly) {
      const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final day = i + 1;
              final isSel = selectedDay == day;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onDayChanged(day);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        isSel ? _kPurple.withOpacity(0.12) : Colors.transparent,
                    shape: BoxShape.circle,
                    border: isSel
                        ? Border.all(color: _kPurple.withOpacity(0.4))
                        : null,
                  ),
                  child: Center(
                      child: Text(days[i],
                          style: _T.label(13,
                              w: isSel ? FontWeight.bold : FontWeight.normal,
                              c: isSel ? _kPurple : onSurf.withOpacity(0.6)))),
                ),
              );
            })),
      );
    }
    if (frequency == GoalSavingsFrequency.monthly) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            showModalBottomSheet(
              context: context,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              builder: (ctx) => SizedBox(
                height: 250,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7),
                  itemCount: 31,
                  itemBuilder: (_, i) {
                    final day = i + 1;
                    return InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onDayChanged(day);
                        Navigator.pop(ctx);
                      },
                      child: Center(
                          child: Text('$day', style: _T.label(14, c: onSurf))),
                    );
                  },
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: onSurf.withOpacity(0.1), width: 0.5),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedDay == null
                        ? 'Elige un día del mes'
                        : 'Recordarme el día $selectedDay',
                    style: _T.label(13,
                        w: FontWeight.w500,
                        c: selectedDay != null
                            ? onSurf
                            : onSurf.withOpacity(0.5)),
                  ),
                  Icon(Iconsax.calendar_edit,
                      size: 16, color: onSurf.withOpacity(0.5)),
                ]),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Modelos ─────────────────────────────────────────────────────────────────

enum ViabilityStatus {
  feasible('Realista', 'Va por buen camino'),
  challenging('Desafiante', 'Requiere ahorro intenso'),
  highRisk('Alto riesgo', 'Compromete el presupuesto');

  final String title, subtitle;
  const ViabilityStatus(this.title, this.subtitle);
}

enum RecommendationType { extendDeadline, increaseContribution, reduceTarget }

class FinancialProjection {
  final double remainingAmount;
  final int monthsRemaining;
  final int periodsRemaining; // ← nuevo
  final double periodicAmount; // ← nuevo (cuota real)
  final String periodLabel; // ← nuevo ("Diario" / "Semanal" / "Mensual")
  final double monthlyNeeded; // equivalente mensual (para % ingreso)
  final double percentageOfIncome;
  final ViabilityStatus status;
  final int suggestedMonths;

  FinancialProjection({
    required this.remainingAmount,
    required this.monthsRemaining,
    required this.periodsRemaining,
    required this.periodicAmount,
    required this.periodLabel,
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
    GoalSavingsFrequency? savingsFrequency, // ← nuevo parámetro
  }) {
    int days = _days(targetDate, timeframe);
    if (days <= 0) days = 1;

    // ── Cuota según la frecuencia elegida por el usuario ─────────────────
    // Si no eligió frecuencia, usamos mensual como referencia genérica.
    final double periodicAmount;
    final String periodLabel;
    final int periodsRemaining;

    switch (savingsFrequency) {
      case GoalSavingsFrequency.daily:
        periodsRemaining = days > 0 ? days : 1;
        periodicAmount = remainingAmount / periodsRemaining;
        periodLabel = 'Diario';
        break;
      case GoalSavingsFrequency.weekly:
        periodsRemaining = (days / 7).ceil().clamp(1, 9999);
        periodicAmount = remainingAmount / periodsRemaining;
        periodLabel = 'Semanal';
        break;
      case GoalSavingsFrequency.monthly:
      case null:
        periodsRemaining = (days / 30.437).ceil().clamp(1, 9999);
        periodicAmount = remainingAmount / periodsRemaining;
        periodLabel = 'Mensual';
        break;
    }

    // monthlyNeeded siempre en términos mensuales para el % de ingreso
    final double monthlyEquivalent = switch (savingsFrequency) {
      GoalSavingsFrequency.daily => periodicAmount * 30.437,
      GoalSavingsFrequency.weekly => periodicAmount * 4.345,
      GoalSavingsFrequency.monthly => periodicAmount,
      null => periodicAmount,
    };

    final int monthsRemaining = (days / 30.437).ceil().clamp(1, 9999);
    final double pct = (monthlyEquivalent / userMonthlyIncome) * 100;

    return FinancialProjection(
      remainingAmount: remainingAmount,
      monthsRemaining: monthsRemaining,
      periodsRemaining: periodsRemaining,
      periodicAmount: periodicAmount,
      periodLabel: periodLabel,
      monthlyNeeded: monthlyEquivalent, // para % de ingreso
      percentageOfIncome: pct,
      status: _viability(pct),
      suggestedMonths: (remainingAmount / (userMonthlyIncome * 0.20)).ceil(),
    );
  }

  static int _days(DateTime? date, GoalTimeframe tf) {
    if (date == null) {
      return switch (tf) {
        GoalTimeframe.short => 180,
        GoalTimeframe.medium => 365,
        GoalTimeframe.long => 1095,
        GoalTimeframe.custom => 365,
      };
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    return target.difference(today).inDays;
  }

  static int _months(DateTime? date, GoalTimeframe tf) {
    if (date == null) {
      return switch (tf) {
        GoalTimeframe.short => 6,
        GoalTimeframe.medium => 12,
        GoalTimeframe.long => 36,
        GoalTimeframe.custom => 12,
      };
    }
    final now = DateTime.now();
    if (date.isBefore(now)) return 0;
    return (date.year - now.year) * 12 + (date.month - now.month);
  }

  static ViabilityStatus _viability(double pct) {
    if (pct <= 25) return ViabilityStatus.feasible;
    if (pct <= 50) return ViabilityStatus.challenging;
    return ViabilityStatus.highRisk;
  }

  static int _suggested(double remaining, double income) =>
      (remaining / (income * 0.20)).ceil();
}
