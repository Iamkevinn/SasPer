// lib/screens/add_goal_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA — Apple iOS / Health + Reminders                                │
// │                                                                             │
// │  Crear una meta es un acto de esperanza.                                   │
// │  La pantalla no debe emocionarte con gradientes — debe ayudarte a          │
// │  entender si tu meta es alcanzable y qué necesitas hacer para lograrlo.    │
// │                                                                             │
// │  PREGUNTA QUE ESTA PANTALLA RESPONDE:                                      │
// │  "Si quiero X en Y meses, ¿puedo hacerlo con mis ingresos actuales?"       │
// │                                                                             │
// │  JERARQUÍA:                                                                │
// │  1. Nombre — qué quieres lograr. Un campo. Sin decoración extra.          │
// │  2. Monto — cuánto cuesta. Grande, protagonista.                          │
// │  3. Fecha — para cuándo. Un tile de fecha compacto.                       │
// │  4. Prioridad — qué tan urgente es. Segmented control compacto.           │
// │  5. Plan card — aparece solo cuando hay monto + fecha válidos.            │
// │     Muestra: ahorro diario / semanal / mensual. Datos reales.             │
// │  6. Viabilidad — un semáforo. Verde/naranja/rojo + texto útil.           │
// │     Aparece junto al plan. No antes, no separado.                         │
// │  7. Botón — único CTA.                                                    │
// │                                                                             │
// │  ELIMINADO vs original:                                                    │
// │  • _DynamicGoalBackground — fondo que cambia de color con viabilidad.    │
// │    El fondo no es un semáforo. El semáforo es el semáforo.               │
// │  • SliverPersistentHeaderDelegate con BackdropFilter — la hero card       │
// │    pegada es un segundo "header" que duplica info ya visible.             │
// │  • _buildPremiumHeader con ícono gradiente + shadow → decoración vacía   │
// │  • Section labels de 18px primary bold en cada sección → compiten entre  │
// │    sí, destruyen la jerarquía visual                                      │
// │  • _AnimatedProgressSparkline con value: 0 siempre → dato falso          │
// │  • ScaleTransition desde 0 en viabilidad → pop agresivo, mareante        │
// │  • Gradientes en cada tarjeta compitiendo: primaryContainer, tertiary,   │
// │    statusColor×2 — toda la pantalla grita al mismo volumen               │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'dart:developer' as developer;

// ─── TOKENS ──────────────────────────────────────────────────────────────────
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
  static const Color teal   = Color(0xFF64D2FF);

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double rSM  = 8.0;
  static const double rMD  = 12.0;
  static const double rXL  = 22.0;
  static const double r2XL = 28.0;

  static const Duration fast   = Duration(milliseconds: 130);
  static const Duration mid    = Duration(milliseconds: 270);
  static const Duration slow   = Duration(milliseconds: 460);
  static const Curve   easeOut = Curves.easeOutCubic;
}

// ─── VIABILIDAD ───────────────────────────────────────────────────────────────
// Un enum rico. Cada estado lleva todo lo que la UI necesita para mostrarse.
// El color ES la respuesta — el texto la confirma.
enum _Viability {
  none(
    color: _C.blue,
    icon: Iconsax.flag,
    label: '',
    message: '',
  ),
  good(
    color: _C.green,
    icon: Iconsax.shield_tick,
    label: 'Alcanzable',
    message: 'Este ritmo de ahorro es sostenible. Estás por buen camino.',
  ),
  moderate(
    color: _C.orange,
    icon: Iconsax.info_circle,
    label: 'Desafiante',
    message: 'Posible, pero requerirá disciplina. Considera extender el plazo.',
  ),
  hard(
    color: _C.red,
    icon: Iconsax.warning_2,
    label: 'Muy exigente',
    message: 'Supera el 50% de tu ingreso. Ajusta el plazo o el monto.',
  );

  final Color  color;
  final IconData icon;
  final String label;
  final String message;

  const _Viability({
    required this.color, required this.icon,
    required this.label, required this.message,
  });
}

// ─── PANTALLA ─────────────────────────────────────────────────────────────────
class AddGoalScreen extends StatefulWidget {
  const AddGoalScreen({super.key});

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen>
    with TickerProviderStateMixin {
  final _goalRepo      = GoalRepository.instance;
  final _analysisRepo  = AnalysisRepository.instance;
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _amountCtrl    = TextEditingController();

  late ConfettiController _confettiCtrl;

  // Plan card aparece con fade cuando hay datos suficientes
  late AnimationController _planCtrl;
  late Animation<double>   _planAnim;

  // Datos reales del repo
  double _monthlyIncome = 0.0;
  bool   _isLoadingData = true;

  // Estado del formulario
  DateTime    _targetDate = DateTime.now().add(const Duration(days: 365));
  GoalPriority _priority  = GoalPriority.medium;
  double      _amount     = 0.0;
  bool        _isSaving   = false;
  bool        _isSuccess  = false;
  GoalSavingsFrequency? _savingsFrequency; // Frecuencia seleccionada
  int? _selectedDay; // Día de la semana (1-7) o del mes (1-31)
  double? _savingsAmount; // Monto sugerido para el ritual

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(
        duration: const Duration(milliseconds: 2500));

    _planCtrl = AnimationController(duration: _C.slow, vsync: this);
    _planAnim = CurvedAnimation(parent: _planCtrl, curve: _C.easeOut);

    _amountCtrl.addListener(_onInputChanged);
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _confettiCtrl.dispose();
    _planCtrl.dispose();
    super.dispose();
  }

  // ── Datos reales del repositorio ─────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final data = await _analysisRepo.fetchAllAnalysisData();
      if (!mounted) return;
      final summaries = data.incomeExpenseBarData;
      double avg = 0;
      if (summaries.isNotEmpty) {
        avg = summaries.fold<double>(0, (s, e) => s + e.totalIncome)
            / summaries.length;
      }
      setState(() {
        _monthlyIncome = avg > 0 ? avg : 1.0;
        _isLoadingData = false;
      });
    } catch (e) {
      developer.log('Error cargando datos financieros: $e');
      if (mounted) setState(() { _monthlyIncome = 1.0; _isLoadingData = false; });
    }
  }

  // 👈 --- NUEVA FUNCIÓN PARA CALCULAR FECHA DE RECORDATORIO ---
  DateTime? _calculateNextReminderDate({
    required GoalSavingsFrequency frequency,
    required int day,
  }) {
    final now = DateTime.now();

    if (frequency == GoalSavingsFrequency.daily) {
      return DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    }
    
    if (frequency == GoalSavingsFrequency.weekly) {
      // day: 1=Lunes, ..., 7=Domingo
      DateTime reminder = DateTime(now.year, now.month, now.day);
      // Avanza día a día hasta encontrar el próximo día de la semana correcto
      while (reminder.weekday != day) {
        reminder = reminder.add(const Duration(days: 1));
      }
      // Si el día calculado es hoy, lo movemos a la próxima semana
      if (reminder.day == now.day && reminder.month == now.month && reminder.year == now.year) {
        return reminder.add(const Duration(days: 7));
      }
      return reminder;
    }
    
    if (frequency == GoalSavingsFrequency.monthly) {
      // day: 1-31
      DateTime reminder = DateTime(now.year, now.month, day);
      // Si el día de este mes ya pasó, lo programamos para el mes siguiente
      if (reminder.isBefore(now)) {
        return DateTime(now.year, now.month + 1, day);
      }
      return reminder;
    }
    return null;
  }

  // ── Cálculos ─────────────────────────────────────────────────────────────
  int get _monthsRemaining {
    final now = DateTime.now();
    if (_targetDate.isBefore(now)) return 0;
    return (_targetDate.year - now.year) * 12
        + _targetDate.month - now.month;
  }

  double get _monthly {
    if (_monthsRemaining <= 0 || _amount <= 0) return 0;
    return _amount / _monthsRemaining;
  }

  double get _weekly  => _monthly / 4.345;
  double get _daily   => _monthly / 30.437;

  double get _pctIncome {
    if (_monthlyIncome <= 0 || _monthly <= 0) return 0;
    return (_monthly / _monthlyIncome) * 100;
  }

  _Viability get _viability {
    if (_monthly <= 0) return _Viability.none;
    final p = _pctIncome;
    if (p > 50) return _Viability.hard;
    if (p > 25) return _Viability.moderate;
    return _Viability.good;
  }

  bool get _hasPlan => _amount > 0 && _monthsRemaining > 0;

  void _onInputChanged() {
    setState(() {
      _amount = double.tryParse(
          _amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;
    });
    if (_hasPlan) {
      _planCtrl.forward();
    } else {
      _planCtrl.reverse();
    }
  }

  // ── Acciones ─────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2101),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      HapticFeedback.selectionClick();
      setState(() => _targetDate = picked);
      _onInputChanged(); // recalcular plan
    }
  }

  void _requestConfirm() {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }
    FocusScope.of(context).unfocus();
    final c = _C(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ConfirmSheet(
        name:     _nameCtrl.text.trim(),
        amount:   _amount,
        date:     _targetDate,
        monthly:  _monthly,
        priority: _priority,
        c:        c,
        onConfirm: _save,
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving || _isSuccess) return;
    setState(() => _isSaving = true);

    try {
      final months = _monthsRemaining;
      final timeframe = months <= 12
          ? GoalTimeframe.short
          : months <= 36
              ? GoalTimeframe.medium
              : GoalTimeframe.long;

      // Determinamos si el ritual está configurado
      final bool isRitualConfigured = _savingsFrequency != null && 
          (_savingsFrequency == GoalSavingsFrequency.daily || _selectedDay != null);

      // Necesitamos hacer un pequeño cambio para que addGoal devuelva la meta creada y así obtener su ID.
      final newGoal = await _goalRepo.addGoal(
        name:         _nameCtrl.text.trim(),
        targetAmount: _amount,
        targetDate:   _targetDate,
        priority:     _priority,
        timeframe:    timeframe,
        savingsFrequency: _savingsFrequency,
        savingsDayOfWeek: _savingsFrequency == GoalSavingsFrequency.weekly ? _selectedDay : null,
        savingsDayOfMonth: _savingsFrequency == GoalSavingsFrequency.monthly ? _selectedDay : null,
        savingsAmount: _savingsAmount,
        nextReminderDate: (_savingsFrequency != null && (_savingsFrequency == GoalSavingsFrequency.daily || _selectedDay != null))
            ? _calculateNextReminderDate(frequency: _savingsFrequency!, day: _selectedDay ?? 0)
            : null,
      );

      // 👈 SEGUNDO: Si se configuró un ritual, programa la notificación.
      if (newGoal.savingsFrequency != null && newGoal.savingsAmount != null) {
        await NotificationService.instance.scheduleGoalReminder(
          goalId: newGoal.id,
          goalName: newGoal.name,
          savingsAmount: newGoal.savingsAmount!,
          frequency: newGoal.savingsFrequency!,
          day: newGoal.savingsDayOfWeek ?? newGoal.savingsDayOfMonth,
        );
        developer.log('✅ Notificación programada para la meta: ${newGoal.name}', name: 'AddGoalScreen');
      }

      if (mounted) {
        setState(() { _isSuccess = true; _isSaving = false; });
        HapticFeedback.lightImpact();
        _confettiCtrl.play();
        EventService.instance.fire(AppEvent.goalCreated);

        await Future.delayed(const Duration(milliseconds: 1800));
        if (mounted) {
          Navigator.of(context).pop(true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            NotificationHelper.show(
              message: 'Meta creada correctamente.',
              type: NotificationType.success,
            );
          });
        }
      }
    } catch (e) {
      developer.log('Error al crear meta: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        HapticFeedback.heavyImpact();
        NotificationHelper.show(
          message: 'Error al crear la meta.',
          type: NotificationType.error,
        );
      }
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _C(context);

    // Estado de carga inicial — limpio, sin fondo decorativo
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.label3),
              ),
              const SizedBox(height: _C.md),
              Text('Cargando datos financieros…',
                  style: TextStyle(fontSize: 13, color: c.label3)),
            ],
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor:          Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:     c.isDark ? Brightness.dark  : Brightness.light,
      ),
      child: Stack(children: [
        Scaffold(
          backgroundColor: c.bg,
          body: Form(
            key: _formKey,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── AppBar limpio ─────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: c.bg,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  leading: _BackBtn(c: c),
                  title: Text('Nueva meta',
                      style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600,
                        color: c.label, letterSpacing: -0.3,
                      )),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      _C.md, _C.sm, _C.md, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([

                      // ── Hero — nombre + monto en tiempo real ────────
                      _HeroCard(
                          name:   _nameCtrl.text,
                          amount: _amount,
                          months: _monthsRemaining,
                          v:      _viability,
                          c:      c),
                      const SizedBox(height: _C.lg),

                      // ── Nombre ────────────────────────────────────
                      _SectionLabel(text: '¿Qué quieres lograr?', c: c),
                      const SizedBox(height: _C.sm),
                      _NameField(ctrl: _nameCtrl, c: c),
                      const SizedBox(height: _C.lg),

                      // ── Monto ─────────────────────────────────────
                      _SectionLabel(text: 'Monto objetivo', c: c),
                      const SizedBox(height: _C.sm),
                      _AmountInput(ctrl: _amountCtrl, c: c),
                      const SizedBox(height: _C.lg),

                      // ── Fecha + Prioridad ─────────────────────────
                      _SectionLabel(text: 'Plazo y prioridad', c: c),
                      const SizedBox(height: _C.sm),
                      _DateTile(
                        date:      _targetDate,
                        months:    _monthsRemaining,
                        c:         c,
                        onTap:     _pickDate,
                      ),
                      const SizedBox(height: _C.sm),
                      _PrioritySelector(
                        priority:  _priority,
                        c:         c,
                        onChanged: (p) {
                          HapticFeedback.selectionClick();
                          setState(() => _priority = p);
                        },
                      ),

                      // ── Plan card — solo cuando hay datos ─────────
                      // AnimatedSize para entrada/salida suave sin saltos
                      AnimatedSize(
                        duration: _C.mid,
                        curve:    _C.easeOut,
                        child: _hasPlan
                            ? Padding(
                                padding: const EdgeInsets.only(top: _C.lg),
                                child: FadeTransition(
                                  opacity: _planAnim,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0, 0.04),
                                      end:   Offset.zero,
                                    ).animate(_planAnim),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _SectionLabel(
                                            text: 'Tu plan de ahorro', c: c),
                                        const SizedBox(height: _C.sm),
                                        _PlanCard(
                                          daily:   _daily,
                                          weekly:  _weekly,
                                          monthly: _monthly,
                                          c:       c,
                                          savingsFrequency: _savingsFrequency,
                                          selectedDay: _selectedDay,
                                          onFrequencyChanged: (freq) {
                                            setState(() {
                                              _savingsFrequency = freq;
                                              _selectedDay = null; // Resetea el día al cambiar de frecuencia
                                              _savingsAmount = freq == null ? null : (freq == GoalSavingsFrequency.weekly ? _weekly : _monthly);
                                            });
                                          },
                                          onDayChanged: (day) {
                                            setState(() {
                                              _selectedDay = day;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: _C.sm),
                                        // Viabilidad — parte del plan, no sección aparte
                                        _ViabilityRow(
                                          v:          _viability,
                                          pctIncome:  _pctIncome,
                                          c:          c,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Botón flotante ────────────────────────────────────────────
        _FloatBtn(
          isSaving:  _isSaving,
          isSuccess: _isSuccess,
          c:         _C(context),
          onTap:     _requestConfirm,
        ),

        // ── Confetti ──────────────────────────────────────────────────
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiCtrl,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 44,
            gravity: 0.26,
            colors: const [
              _C.blue, _C.green, _C.orange, _C.purple, _C.red, _C.teal,
            ],
            createParticlePath: _starPath,
          ),
        ),
      ]),
    );
  }
}

// ─── HERO CARD ────────────────────────────────────────────────────────────────
// Nombre + monto + meses en una tarjeta compacta.
// El badge de viabilidad aparece solo cuando hay datos.
// Sin BackdropFilter, sin gradiente, sin border doble.
class _HeroCard extends StatelessWidget {
  final String    name;
  final double    amount;
  final int       months;
  final _Viability v;
  final _C        c;

  const _HeroCard({
    required this.name, required this.amount, required this.months,
    required this.v, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final hasData = amount > 0 || name.isNotEmpty;

    return AnimatedContainer(
      duration: _C.mid,
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.r2XL),
        border: Border.all(
          color: hasData
              ? _C.blue.withOpacity(0.18) : c.sep.withOpacity(0.40),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.18 : 0.04),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Ícono de meta
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _C.blue.withOpacity(c.isDark ? 0.20 : 0.10),
            borderRadius: BorderRadius.circular(_C.rMD),
          ),
          child: const Icon(Iconsax.flag, size: 20, color: _C.blue),
        ),
        const SizedBox(width: _C.md),

        // Nombre y monto
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: _C.fast,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  name.isEmpty ? 'Define tu meta' : name,
                  key: ValueKey(name.isEmpty),
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: name.isEmpty ? c.label4 : c.label,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 3),
              Row(children: [
                AnimatedSwitcher(
                  duration: _C.fast,
                  child: Text(
                    amount > 0 ? compact.format(amount) : '—',
                    key: ValueKey(amount > 0),
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: amount > 0 ? _C.blue : c.label4,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                if (months > 0) ...[
                  const SizedBox(width: _C.sm),
                  Text(
                    'en $months meses',
                    style: TextStyle(fontSize: 12, color: c.label3),
                  ),
                ],
              ]),
            ],
          ),
        ),

        // Badge viabilidad — solo cuando hay plan
        if (v != _Viability.none)
          AnimatedSwitcher(
            duration: _C.mid,
            child: Container(
              key: ValueKey(v),
              padding: const EdgeInsets.symmetric(
                  horizontal: _C.sm + 2, vertical: _C.xs + 2),
              decoration: BoxDecoration(
                color: v.color.withOpacity(c.isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(_C.rMD),
                border: Border.all(
                    color: v.color.withOpacity(0.25), width: 0.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(v.icon, size: 12, color: v.color),
                const SizedBox(width: 4),
                Text(v.label,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: v.color,
                    )),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ─── NAME FIELD ───────────────────────────────────────────────────────────────
class _NameField extends StatefulWidget {
  final TextEditingController ctrl;
  final _C c;
  const _NameField({required this.ctrl, required this.c});

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  final _focus  = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(
          color: _focused
              ? _C.blue.withOpacity(0.55) : c.sep.withOpacity(0.40),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? _C.blue.withOpacity(c.isDark ? 0.10 : 0.06)
                : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: _focused ? 12 : 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller:          widget.ctrl,
        focusNode:           _focus,
        textCapitalization:  TextCapitalization.sentences,
        onChanged:           (_) => HapticFeedback.selectionClick(),
        style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: c.label),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? '' : null,
        decoration: InputDecoration(
          hintText: 'Ej: Viaje a Japón, Auto nuevo…',
          hintStyle: TextStyle(
              fontSize: 15, color: c.label4, fontWeight: FontWeight.w400),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Iconsax.flag, size: 18,
                color: _focused ? _C.blue : c.label4),
          ),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: _C.md, vertical: 16),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

// ─── AMOUNT INPUT ─────────────────────────────────────────────────────────────
// El número es el protagonista — 42px w800.
// El controller viene del padre para sobrevivir rebuilds.
class _AmountInput extends StatefulWidget {
  final TextEditingController ctrl;
  final _C c;
  const _AmountInput({required this.ctrl, required this.c});

  @override
  State<_AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<_AmountInput> {
  final _focus  = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() => _focused = _focus.hasFocus);
    });
  }

  @override
  void dispose() { _focus.dispose(); super.dispose(); }

  bool get _hasValue =>
      (double.tryParse(
              widget.ctrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0) > 0;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedContainer(
      duration: _C.fast,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.r2XL),
        border: Border.all(
          color: _focused
              ? _C.blue.withOpacity(0.50) : c.sep.withOpacity(0.40),
          width: _focused ? 1.5 : 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _focused
                ? _C.blue.withOpacity(c.isDark ? 0.10 : 0.06)
                : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
            blurRadius: _focused ? 16 : 6, offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: _C.lg),
      child: TextFormField(
        controller:   widget.ctrl,
        focusNode:    _focus,
        textAlign:    TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          _MoneyFmt(),
        ],
        onChanged: (_) {
          HapticFeedback.selectionClick();
          setState(() {});
        },
        validator: (v) {
          if (v == null || v.isEmpty) return '';
          final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
          if (n == null || n <= 0) return '';
          return null;
        },
        style: TextStyle(
          fontSize: 42, fontWeight: FontWeight.w800,
          color: _hasValue ? _C.blue : c.label4,
          letterSpacing: -1.5, height: 1.0,
        ),
        decoration: InputDecoration(
          border:         InputBorder.none,
          hintText:       '\$ 0',
          hintStyle: TextStyle(
            fontSize: 42, fontWeight: FontWeight.w800,
            color: c.label4, letterSpacing: -1.5,
          ),
          contentPadding: EdgeInsets.zero,
          errorStyle:     const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

class _MoneyFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue next) {
    if (next.text.isEmpty) return next.copyWith(text: '');
    final n = int.tryParse(next.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final s = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(n);
    return next.copyWith(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

// ─── DATE TILE ────────────────────────────────────────────────────────────────
// Un tile que muestra fecha formateada + "X meses" como subtítulo.
// El subtítulo es el dato más útil — cambia en tiempo real al elegir fecha.
class _DateTile extends StatelessWidget {
  final DateTime date;
  final int      months;
  final _C       c;
  final VoidCallback onTap;

  const _DateTile({
    required this.date, required this.months,
    required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Etiqueta contextual del plazo
    final String timeframeHint = months <= 0
        ? 'Fecha inválida'
        : months <= 12  ? 'Meta corto plazo (<1 año)'
        : months <= 36  ? 'Meta medio plazo (1-3 años)'
                        : 'Meta largo plazo (>3 años)';

    return _ScaleBtn(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(color: c.sep.withOpacity(0.40), width: 0.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                blurRadius: 5, offset: const Offset(0, 1)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: _C.blue.withOpacity(c.isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(_C.rSM)),
            child: const Icon(Iconsax.calendar_1, size: 16, color: _C.blue),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('d MMMM yyyy', 'es_CO').format(date),
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: c.label, letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  months > 0 ? '$months meses · $timeframeHint' : timeframeHint,
                  style: TextStyle(fontSize: 11, color: c.label3),
                ),
              ],
            ),
          ),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 20, color: c.label3),
        ]),
      ),
    );
  }
}

// ─── PRIORITY SELECTOR ───────────────────────────────────────────────────────
// Segmented control iOS. Los tres niveles con su color semántico.
// El color del seleccionado comunica la urgencia sin texto adicional.
class _PrioritySelector extends StatelessWidget {
  final GoalPriority priority;
  final _C c;
  final ValueChanged<GoalPriority> onChanged;

  const _PrioritySelector({
    required this.priority, required this.c, required this.onChanged,
  });

  static const _opts = [
    (p: GoalPriority.low,    label: 'Baja',   color: _C.green),
    (p: GoalPriority.medium, label: 'Media',  color: _C.orange),
    (p: GoalPriority.high,   label: 'Alta',   color: _C.red),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: c.sep.withOpacity(0.40), width: 0.5),
      ),
      child: Row(
        children: _opts.asMap().entries.map((e) {
          final i   = e.key;
          final opt = e.value;
          final sel = priority == opt.p;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < _opts.length - 1 ? 3 : 0),
              child: GestureDetector(
                onTap: () => onChanged(opt.p),
                child: AnimatedContainer(
                  duration: _C.fast,
                  decoration: BoxDecoration(
                    color: sel
                        ? opt.color.withOpacity(c.isDark ? 0.22 : 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(_C.rMD),
                    border: Border.all(
                      color: sel
                          ? opt.color.withOpacity(c.isDark ? 0.50 : 0.35)
                          : Colors.transparent,
                      width: sel ? 1.0 : 0,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    opt.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? opt.color : c.label3,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── PLAN CARD ────────────────────────────────────────────────────────────────
// La información más valiosa de la pantalla:
// ¿Cuánto tengo que ahorrar al día, semana y mes?
//
// Tres métricas en una fila. La mensual es la principal (más grande).
// Sin gradientes, sin bordes dobles. El dato habla solo.

class _PlanCard extends StatelessWidget {
  final double daily;
  final double weekly;
  final double monthly;
  final _C c;

  // --- Callbacks y estado del Ritual ---
  final GoalSavingsFrequency? savingsFrequency;
  final int? selectedDay;
  final Function(GoalSavingsFrequency?) onFrequencyChanged;
  final Function(int) onDayChanged;

  const _PlanCard({
    required this.daily,
    required this.weekly,
    required this.monthly,
    required this.c,
    required this.savingsFrequency,
    required this.selectedDay,
    required this.onFrequencyChanged,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: c.sep.withOpacity(0.40), width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        // Header "Necesitas ahorrar"
        Padding(
          padding: const EdgeInsets.fromLTRB(_C.md, _C.md, _C.md, 0),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: _C.blue.withOpacity(c.isDark ? 0.18 : 0.09),
                borderRadius: BorderRadius.circular(_C.rSM),
              ),
              child: const Icon(Iconsax.wallet_money, size: 14, color: _C.blue),
            ),
            const SizedBox(width: _C.sm + 2),
            Text('Necesitas ahorrar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.label,
                  letterSpacing: -0.1,
                )),
          ]),
        ),
        const SizedBox(height: _C.md),
        Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: _C.md), color: c.sep.withOpacity(0.5)),

        // Tres métricas de ahorro
        Padding(
          padding: const EdgeInsets.all(_C.md),
          child: Row(children: [
            Expanded(child: _PlanMetric(label: 'Diario', value: compact.format(daily), isMain: false, c: c)),
            Container(width: 0.5, height: 44, color: c.sep),
            Expanded(child: _PlanMetric(label: 'Semanal', value: compact.format(weekly), isMain: false, c: c)),
            Container(width: 0.5, height: 44, color: c.sep),
            Expanded(child: _PlanMetric(label: 'Mensual', value: compact.format(monthly), isMain: true, c: c)),
          ]),
        ),
        
        // --- SECCIÓN DEL RITUAL DE AHORRO (APARECE CON ANIMACIÓN) ---
        AnimatedSize(
          duration: _C.mid,
          curve: _C.easeOut,
          child: Column(
            children: [
               Container(height: 0.5, margin: const EdgeInsets.symmetric(horizontal: _C.md), color: c.sep.withOpacity(0.5)),
               const SizedBox(height: _C.md),
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: _C.md),
                 child: Row(children: [
                   Container(
                     width: 30, height: 30,
                     decoration: BoxDecoration(
                       color: _C.purple.withOpacity(c.isDark ? 0.18 : 0.09),
                       borderRadius: BorderRadius.circular(_C.rSM),
                     ),
                     child: const Icon(Iconsax.notification_bing, size: 14, color: _C.purple),
                   ),
                   const SizedBox(width: _C.sm + 2),
                   Text('Crear un recordatorio',
                       style: TextStyle(
                         fontSize: 13,
                         fontWeight: FontWeight.w700,
                         color: c.label,
                         letterSpacing: -0.1,
                       )),
                 ]),
               ),
               const SizedBox(height: _C.sm),
               _FrequencySelector(
                 c: c,
                 selected: savingsFrequency,
                 onChanged: onFrequencyChanged,
               ),
              if (savingsFrequency != null && savingsFrequency != GoalSavingsFrequency.daily)
                _DaySelector(
                  c: c,
                  frequency: savingsFrequency!,
                  selectedDay: selectedDay,
                  onDayChanged: onDayChanged,
                )
            ],
          ),
        ),
        const SizedBox(height: _C.md),
      ]),
    );
  }
}

// 👈 --- NUEVO WIDGET: SELECTOR DE FRECUENCIA DEL RITUAL ---
class _FrequencySelector extends StatelessWidget {
  final _C c;
  final GoalSavingsFrequency? selected;
  final Function(GoalSavingsFrequency?) onChanged;
  
  const _FrequencySelector({required this.c, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_C.md, _C.sm, _C.md, 0),
      child: Row(
        children: GoalSavingsFrequency.values.map((freq) {
          final isSelected = selected == freq;
          final label = freq == GoalSavingsFrequency.daily ? 'Diario' : freq == GoalSavingsFrequency.weekly ? 'Semanal' : 'Mensual';

          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(isSelected ? null : freq);
              },
              child: AnimatedContainer(
                duration: _C.fast,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? _C.purple.withOpacity(c.isDark ? 0.22 : 0.12) : c.raised,
                  borderRadius: BorderRadius.circular(_C.rMD),
                  border: Border.all(
                    color: isSelected ? _C.purple.withOpacity(0.4) : c.sep.withOpacity(0.3),
                    width: isSelected ? 1.0 : 0.5,
                  )
                ),
                child: Center(
                  child: Text(label, style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? _C.purple : c.label3,
                  )),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 👈 --- NUEVO WIDGET: SELECTOR DE DÍA (SEMANA O MES) ---
class _DaySelector extends StatelessWidget {
  final _C c;
  final GoalSavingsFrequency frequency;
  final int? selectedDay;
  final Function(int) onDayChanged;

  const _DaySelector({required this.c, required this.frequency, required this.selectedDay, required this.onDayChanged});

  @override
  Widget build(BuildContext context) {
    if (frequency == GoalSavingsFrequency.weekly) {
      const weekDays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      return Padding(
        padding: const EdgeInsets.fromLTRB(_C.md, _C.sm, _C.md, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (index) {
            final day = index + 1; // 1=Lunes, 7=Domingo
            final isSelected = selectedDay == day;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onDayChanged(day);
              },
              child: AnimatedContainer(
                duration: _C.fast,
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? _C.purple.withOpacity(c.isDark ? 0.22 : 0.12) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: _C.purple.withOpacity(0.4), width: 1.0) : null,
                ),
                child: Center(
                  child: Text(weekDays[index], style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? _C.purple : c.label3,
                  )),
                ),
              ),
            );
          }),
        ),
      );
    }

    if (frequency == GoalSavingsFrequency.monthly) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(_C.md, _C.sm, _C.md, 0),
        child: _ScaleBtn(
          onTap: () => _showDayPicker(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.raised,
              borderRadius: BorderRadius.circular(_C.rMD),
              border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  selectedDay == null ? 'Elige un día del mes' : 'Recordarme el día $selectedDay de cada mes',
                  style: TextStyle(color: selectedDay != null ? c.label2 : c.label4, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                Icon(Iconsax.calendar_edit, size: 16, color: c.label4),
              ],
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showDayPicker(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: c.surface,
      builder: (ctx) => SizedBox(
        height: 250,
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
          itemCount: 31,
          itemBuilder: (context, index) {
            final day = index + 1;
            return InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onDayChanged(day);
                Navigator.pop(ctx);
              },
              child: Center(child: Text('$day', style: TextStyle(color: c.label2))),
            );
          },
        ),
      ),
    );
  }
}

class _PlanMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool   isMain;
  final _C     c;

  const _PlanMetric({
    required this.label, required this.value,
    required this.isMain, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label,
          style: TextStyle(
            fontSize: 10, color: c.label3,
            fontWeight: FontWeight.w600, letterSpacing: 0.1,
          )),
      const SizedBox(height: 4),
      Text(value,
          style: TextStyle(
            fontSize: isMain ? 17 : 14,
            fontWeight: isMain ? FontWeight.w800 : FontWeight.w600,
            color: isMain ? _C.blue : c.label2,
            letterSpacing: -0.3,
          )),
    ]);
  }
}

// ─── VIABILITY ROW ────────────────────────────────────────────────────────────
// El semáforo de viabilidad. Vive DEBAJO del plan card — son la misma unidad.
// No es una tarjeta grande con gradiente. Es una línea de contexto.
// Si es verde: reafirma. Si es naranja/rojo: sugiere acción concreta.
class _ViabilityRow extends StatelessWidget {
  final _Viability v;
  final double     pctIncome;
  final _C         c;

  const _ViabilityRow({
    required this.v, required this.pctIncome, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    if (v == _Viability.none) return const SizedBox.shrink();

    final pctText = pctIncome > 0
        ? '${pctIncome.toStringAsFixed(1)}% de tu ingreso mensual'
        : '';

    return AnimatedSwitcher(
      duration: _C.mid,
      child: Container(
        key: ValueKey(v),
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: v.color.withOpacity(c.isDark ? 0.10 : 0.05),
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(
              color: v.color.withOpacity(0.20), width: 0.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Ícono semáforo
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: v.color.withOpacity(c.isDark ? 0.20 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(v.icon, size: 15, color: v.color),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título + porcentaje en la misma línea
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(v.label,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: v.color, letterSpacing: -0.1,
                        )),
                    if (pctText.isNotEmpty)
                      Text(pctText,
                          style: TextStyle(
                            fontSize: 11, color: v.color,
                            fontWeight: FontWeight.w600,
                          )),
                  ],
                ),
                const SizedBox(height: 3),
                Text(v.message,
                    style: TextStyle(
                      fontSize: 12, color: c.label3, height: 1.4,
                    )),
                // Barra de porcentaje — solo si hay dato real
                if (pctIncome > 0) ...[
                  const SizedBox(height: _C.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (pctIncome / 100).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor:
                          v.color.withOpacity(c.isDark ? 0.15 : 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(v.color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── CONFIRMATION SHEET ───────────────────────────────────────────────────────
// Resumen limpio antes de guardar.
// Sin ícono con gradiente circular en el header.
// Sin FilledButton.icon (usa _ScaleBtn propio para consistencia).
class _ConfirmSheet extends StatelessWidget {
  final String      name;
  final double      amount;
  final DateTime    date;
  final double      monthly;
  final GoalPriority priority;
  final _C          c;
  final VoidCallback onConfirm;

  const _ConfirmSheet({
    required this.name, required this.amount, required this.date,
    required this.monthly, required this.priority,
    required this.c, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final priorityLabel = switch (priority) {
      GoalPriority.low    => 'Baja',
      GoalPriority.medium => 'Media',
      GoalPriority.high   => 'Alta',
      _                   => '—',
    };

    return Container(
      padding: EdgeInsets.fromLTRB(
          _C.md, _C.md, _C.md,
          _C.lg + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(_C.r2XL)),
        border: Border(
            top: BorderSide(color: c.sep.withOpacity(0.3), width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: _C.lg),
          decoration: BoxDecoration(
              color: c.sep, borderRadius: BorderRadius.circular(2)),
        ),

        // Ícono simple — sin gradiente
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: _C.blue.withOpacity(c.isDark ? 0.18 : 0.10),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.flag, size: 24, color: _C.blue),
        ),
        const SizedBox(height: _C.md),
        Text('¿Crear esta meta?',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: c.label, letterSpacing: -0.3,
            )),
        const SizedBox(height: _C.lg),

        // Resumen
        Container(
          padding: const EdgeInsets.all(_C.md),
          decoration: BoxDecoration(
            color: c.raised,
            borderRadius: BorderRadius.circular(_C.rXL),
            border: Border.all(color: c.sep.withOpacity(0.3), width: 0.5),
          ),
          child: Column(children: [
            _Row('Meta',            name,                          c),
            _Div(c: c),
            _Row('Monto',           compact.format(amount),        c),
            _Div(c: c),
            _Row('Fecha límite',
                DateFormat('d MMM yyyy', 'es_CO').format(date),    c),
            _Div(c: c),
            _Row('Ahorro mensual',  compact.format(monthly),       c),
            _Div(c: c),
            _Row('Prioridad',       priorityLabel,                 c),
          ]),
        ),

        const SizedBox(height: _C.lg),

        // Botones
        Row(children: [
          Expanded(
            child: _ScaleBtn(
              onTap: () => Navigator.pop(context),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    color: c.raised,
                    borderRadius: BorderRadius.circular(_C.rXL),
                    border: Border.all(
                        color: c.sep.withOpacity(0.4), width: 0.5)),
                alignment: Alignment.center,
                child: Text('Cancelar',
                    style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: c.label2)),
              ),
            ),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            flex: 2,
            child: _ScaleBtn(
              onTap: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  onConfirm();
                });
              },
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    color: _C.blue,
                    borderRadius: BorderRadius.circular(_C.rXL),
                    boxShadow: [
                      BoxShadow(
                          color: _C.blue.withOpacity(0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5)),
                    ]),
                alignment: Alignment.center,
                child: const Text('Crear meta',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.1,
                    )),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ─── FLOAT BUTTON ─────────────────────────────────────────────────────────────
class _FloatBtn extends StatefulWidget {
  final bool       isSaving;
  final bool       isSuccess;
  final _C         c;
  final VoidCallback onTap;

  const _FloatBtn({
    required this.isSaving, required this.isSuccess,
    required this.c, required this.onTap,
  });

  @override
  State<_FloatBtn> createState() => _FloatBtnState();
}

class _FloatBtnState extends State<_FloatBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    final c     = widget.c;
    final color = widget.isSuccess ? _C.green : _C.blue;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            _C.md, _C.md, _C.md,
            _C.lg + MediaQuery.of(context).padding.bottom),
        child: GestureDetector(
          onTapDown:   (widget.isSaving || widget.isSuccess)
              ? null : (_) => setState(() => _p = true),
          onTapUp:     (widget.isSaving || widget.isSuccess)
              ? null : (_) { setState(() => _p = false); widget.onTap(); },
          onTapCancel: () => setState(() => _p = false),
          child: AnimatedScale(
            scale: _p ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: AnimatedContainer(
              duration: _C.mid, curve: _C.easeOut,
              width:  widget.isSaving ? 60 : double.infinity,
              height: 60,
              decoration: BoxDecoration(
                color: widget.isSaving ? c.label4 : color,
                borderRadius: BorderRadius.circular(
                    widget.isSaving ? 30 : _C.rXL),
                boxShadow: widget.isSaving ? null : [
                  BoxShadow(
                    color: color.withOpacity(_p ? 0.18 : 0.38),
                    blurRadius: _p ? 8 : 20,
                    offset: Offset(0, _p ? 2 : 7),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: _C.fast,
                child: widget.isSaving
                    ? const SizedBox(
                        key: ValueKey('load'),
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : widget.isSuccess
                        ? const Icon(Iconsax.tick_circle,
                            key: ValueKey('ok'),
                            color: Colors.white, size: 26)
                        : Row(
                            key: const ValueKey('idle'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Iconsax.flag, color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text('Crear meta',
                                  style: TextStyle(
                                    color: Colors.white, fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  )),
                            ],
                          ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── UTILS ────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final _C c;
  const _SectionLabel({required this.text, required this.c});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: c.label3, letterSpacing: 0.1,
      ));
}

class _BackBtn extends StatelessWidget {
  final _C c;
  const _BackBtn({required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); Navigator.of(context).pop(); },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: c.raised, shape: BoxShape.circle),
        child: Icon(Icons.arrow_back_ios_new_rounded,
            size: 15, color: c.label),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final _C c;
  const _Row(this.label, this.value, this.c);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _C.sm + 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: c.label3)),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: c.label, letterSpacing: -0.1,
                )),
          ),
        ],
      ),
    );
  }
}

class _Div extends StatelessWidget {
  final _C c;
  const _Div({required this.c});

  @override
  Widget build(BuildContext context) =>
      Container(height: 0.5, color: c.sep.withOpacity(0.5));
}

class _ScaleBtn extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _ScaleBtn({required this.child, required this.onTap});

  @override
  State<_ScaleBtn> createState() => _ScaleBtnState();
}

class _ScaleBtnState extends State<_ScaleBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _p = true),
      onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
          scale: _p ? 0.95 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: widget.child),
    );
  }
}

Path _starPath(Size size) {
  double r(double deg) => deg * (math.pi / 180);
  final hw = size.width / 2;
  final path = Path();
  path.moveTo(size.width, hw);
  for (double s = 0; s < r(360); s += r(72)) {
    path.lineTo(hw + hw * math.cos(s), hw + hw * math.sin(s));
    path.lineTo(hw + (hw / 2.5) * math.cos(s + r(36)),
        hw + (hw / 2.5) * math.sin(s + r(36)));
  }
  path.close();
  return path;
}