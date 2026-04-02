// lib/screens/can_i_afford_it_screen.dart
//
// FILOSOFÍA: La pregunta es "¿puedo permitirme esto?".
// La pantalla responde en menos de un segundo, visualmente, sin que
// el usuario tenga que procesar texto para entender el resultado.
//
// TODO LO QUE SE MUESTRA VIENE DE DATOS REALES:
// · Gauge + veredicto → simulate_expense RPC
// · Metas afectadas → tabla goals (savings_amount, target_date)
// · Gastos fijos pendientes → recurring_transactions del mes actual
// · Deudas activas → tabla debts
// · Saldo disponible / presupuesto → accounts + budgets
//
// NADA SE INVENTA. Si no hay datos, no se muestra la sección.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/simulation_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/models/simulation_models.dart';
import 'package:sasper/screens/simulation_result_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/goal_model.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Paleta iOS ──────────────────────────────────────────────────────────────
const _kBlue = Color(0xFF0A84FF);
const _kGreen = Color(0xFF30D158);
const _kOrange = Color(0xFFFF9F0A);
const _kRed = Color(0xFFFF453A);

// ─── Tipografía ──────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s) => GoogleFonts.dmSans(
        fontSize: s,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.1,
      );
  static TextStyle label(double s, {FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w);
  static TextStyle mono(double s) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: FontWeight.w600);
}

final _fmt =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _fmtCompact = NumberFormat.compactCurrency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 1);

// ─── Nivel de riesgo ─────────────────────────────────────────────────────────
enum _Risk {
  safe(color: _kGreen, label: 'Puedes permitírtelo'),
  caution(color: _kOrange, label: 'Con precaución'),
  high(color: _kRed, label: 'Riesgo alto');

  final Color color;
  final String label;
  const _Risk({required this.color, required this.label});
}

// =============================================================================
// SCREEN — ENTRADA
// =============================================================================

class CanIAffordItScreen extends StatefulWidget {
  const CanIAffordItScreen({super.key});

  @override
  State<CanIAffordItScreen> createState() => _CanIAffordItScreenState();
}

class _CanIAffordItScreenState extends State<CanIAffordItScreen>
    with TickerProviderStateMixin {
  final _amountCtrl = TextEditingController();
  final _amountFocus = FocusNode();

  final _simRepo = SimulationRepository.instance;
  final _catRepo = CategoryRepository.instance;
  final _accountRepo = AccountRepository.instance;
  final _budgetRepo = BudgetRepository.instance;

  Category? _selectedCategory;
  bool _isSimulating = false;
  bool _isDataLoading = true;
  String _dataError = '';
  // Añade esta variable debajo de _spent = 0;
  double _protectedGoalsAmount = 0;
  double _pendingFixedExpenses = 0;

  late Future<List<Category>> _categoriesFuture;

  // Datos financieros reales
  double _balance = 0;
  double _budget = 0;
  double _spent = 0;

  // Estado reactivo al monto
  double _amount = 0;
  bool _hasAmt = false;
  _Risk _risk = _Risk.safe;

  // Animaciones
  late final AnimationController _gaugeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final AnimationController _revealCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 270),
  );
  late final AnimationController _fadeCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  // Para interpolar el color del gauge al cambiar de nivel
  Color _gaugeColor = _kGreen;
  Color _prevColor = _kGreen;
  late final AnimationController _colorCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 270),
  );

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _catRepo.getExpenseCategories();
    _loadFinancialData();
    _amountCtrl.addListener(_onAmountChanged);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    _gaugeCtrl.dispose();
    _revealCtrl.dispose();
    _fadeCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  // ── Carga inicial ─────────────────────────────────────────────────────────

Future<void> _loadFinancialData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Fechas para saber qué gastos fijos tocan este mes
      final now = DateTime.now();
      final firstOfMonth = DateTime(now.year, now.month, 1).toIso8601String();
      final lastOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toIso8601String();

      final res = await Future.wait([
        _accountRepo.getAccounts(),
        _budgetRepo.getOverallBudgetSummary(),
        GoalRepository.instance.getActiveGoals(),
        // <--- NUEVO: Traemos los gastos fijos pendientes del mes
        Supabase.instance.client
            .from('recurring_transactions')
            .select('amount')
            .eq('user_id', userId)
            .eq('type', 'Gasto')
            .eq('status', 'active')
            .gte('next_due_date', firstOfMonth)
            .lte('next_due_date', lastOfMonth),
      ]);

      final accounts = res[0] as List<dynamic>;
      final totalBal = accounts.fold<double>(0, (s, a) => s + (a.balance as double));

      final budgetTuple = res[1] as (double, double);

      final goals = res[2] as List<Goal>;
      final totalSavedInGoals = goals.fold<double>(0, (s, g) => s + g.currentAmount);

      // <--- NUEVO: Sumamos cuánto debemos en facturas este mes
      final recurringRaw = res[3] as List<dynamic>;
      final totalPendingFixed = recurringRaw.fold<double>(
          0, (s, r) => s + ((r['amount'] as num).toDouble()).abs());

      if (mounted) {
        setState(() {
          // La liquidez REAL ahora resta las metas Y las facturas pendientes
          _balance = (totalBal - totalSavedInGoals - totalPendingFixed).clamp(0.0, double.infinity);
          _protectedGoalsAmount = totalSavedInGoals;
          _pendingFixedExpenses = totalPendingFixed; // Guardamos el dato
          _budget = budgetTuple.$1;
          _spent = budgetTuple.$2;
          _isDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataError = 'No se pudieron cargar tus datos financieros.';
          _isDataLoading = false;
        });
      }
    }
  }

  // ── Reactivo al monto ─────────────────────────────────────────────────────

  void _onAmountChanged() {
    final parsed =
        double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9.]'), '')) ??
            0;
    final newRisk = _calcRisk(parsed);

    if (newRisk != _risk) {
      _prevColor = _gaugeColor;
      _gaugeColor = newRisk.color;
      _colorCtrl.forward(from: 0);
    }

    setState(() {
      _amount = parsed;
      _hasAmt = parsed > 0;
      _risk = newRisk;
    });

    if (parsed > 0) {
      final pct = _balance > 0 ? (parsed / _balance).clamp(0.0, 1.0) : 0.0;
      _gaugeCtrl.animateTo(pct,
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic);
      _revealCtrl.forward();
    } else {
      _gaugeCtrl.animateTo(0, duration: const Duration(milliseconds: 270));
      _revealCtrl.reverse();
    }
  }

  // Actualizamos el cálculo de riesgo
  _Risk _calcRisk(double amount) {
    if (amount <= 0) return _Risk.safe;
    
    // remaining ahora es el saldo LIBRE DE VERDAD (sin metas y sin facturas)
    final remaining = _balance - amount; 
    final pctOfBudget = _budget > 0 ? (amount / _budget) * 100 : 0.0;
    
    // Si te quedas en rojo de tu plata verdaderamente libre -> RIESGO ALTO
    if (remaining < 0 || pctOfBudget > 50) return _Risk.high;
    
    // Si te gastas más del 25% de tu presupuesto, o te queda muy poco margen -> PRECAUCIÓN
    if (pctOfBudget > 25 || remaining < (_budget > 0 ? _budget * 0.2 : 50000)) return _Risk.caution;
    
    return _Risk.safe;
  }

  // ── Simulación completa ───────────────────────────────────────────────────

  Future<void> _simulate() async {
    if (_selectedCategory == null) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
        message: 'Selecciona una categoría para continuar.',
        type: NotificationType.error,
      );
      return;
    }
    if (_amount <= 0) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
        message: 'Escribe un monto para analizar.',
        type: NotificationType.error,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isSimulating = true);

    try {
      final result = await _simRepo.getExpenseSimulation(
        amount: _amount,
        categoryName: _selectedCategory!.name,
      );

      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).push(PageRouteBuilder(
        pageBuilder: (_, a, __) => SimulationResultScreen(result: result),
        transitionDuration: const Duration(milliseconds: 480),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          child: SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 0.04), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ));
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        NotificationHelper.show(
          message: e.toString().replaceFirst('Exception: ', ''),
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSimulating = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isDataLoading) return const _LoadingScaffold();
    if (_dataError.isNotEmpty) {
      return _ErrorScaffold(
        message: _dataError,
        onRetry: () {
          setState(() {
            _isDataLoading = true;
            _dataError = '';
          });
          _loadFinancialData();
        },
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);
    final surfBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Scaffold(
      backgroundColor: bg,
      body: FadeTransition(
        opacity: _fadeCtrl,
        child: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── Header blur ──────────────────────────────────────────
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _BlurHeader(
                    title: '¿Me lo puedo permitir?',
                    scaffoldBg: bg,
                    onBack: () => Navigator.pop(context),
                  ),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // ── Hero: gauge + veredicto ──────────────────────
                      _HeroCard(
                        gaugeCtrl: _gaugeCtrl,
                        colorCtrl: _colorCtrl,
                        prevColor: _prevColor,
                        riskColor: _gaugeColor,
                        risk: _risk,
                        hasAmt: _hasAmt,
                        amount: _amount,
                        balance: _balance,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),

                      // ── Balance bar ───────────────────────────────────
                      _BalanceBar(
                        balance: _balance,
                        budget: _budget,
                        spent: _spent,
                        amount: _amount,
                        protectedAmount: _protectedGoalsAmount,
                        isDark: isDark,
                        surfBg: surfBg,
                      ),
                      const SizedBox(height: 28),

                      // ── Monto ─────────────────────────────────────────
                      _SectionLabel('Monto del gasto', isDark: isDark),
                      const SizedBox(height: 8),
                      _AmountField(
                        ctrl: _amountCtrl,
                        focus: _amountFocus,
                        risk: _risk,
                        hasAmt: _hasAmt,
                        surfBg: surfBg,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 8),

                      // Sugerencias % — solo si hay saldo
                      if (_balance > 0)
                        _QuickAmounts(
                          balance: _balance,
                          isDark: isDark,
                          onTap: (v) {
                            HapticFeedback.selectionClick();
                            _amountCtrl.text = v.toStringAsFixed(0);
                            _amountCtrl.selection = TextSelection.fromPosition(
                                TextPosition(offset: _amountCtrl.text.length));
                          },
                        ),
                      const SizedBox(height: 28),

                      // ── Categoría ─────────────────────────────────────
                      _SectionLabel('Categoría del gasto', isDark: isDark),
                      const SizedBox(height: 8),
                      _CategoryPicker(
                        future: _categoriesFuture,
                        selected: _selectedCategory,
                        isDark: isDark,
                        surfBg: surfBg,
                        onChanged: (cat) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategory = cat);
                        },
                      ),

                      // ── Métricas — aparecen al escribir ───────────────
                      AnimatedSize(
                        duration: const Duration(milliseconds: 270),
                        curve: Curves.easeOutCubic,
                        child: _hasAmt
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 28),
                                  _SectionLabel('Impacto en tu bolsillo',
                                      isDark: isDark),
                                  const SizedBox(height: 8),
                                  FadeTransition(
                                    opacity: _revealCtrl,
                                    child: _MetricsRow(
                                      amount: _amount,
                                      balance: _balance,
                                      budget: _budget,
                                      risk: _risk,
                                      isDark: isDark,
                                      surfBg: surfBg,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 120),
                    ]),
                  ),
                ),
              ],
            ),

            // ── Botón fijo ─────────────────────────────────────────────
            Align(
              alignment: Alignment.bottomCenter,
              child: _SimulateButton(
                isLoading: _isSimulating,
                canTap: _hasAmt && _selectedCategory != null,
                onTap: _simulate,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// HERO CARD
// =============================================================================

class _HeroCard extends StatelessWidget {
  final AnimationController gaugeCtrl;
  final AnimationController colorCtrl;
  final Color prevColor;
  final Color riskColor;
  final _Risk risk;
  final bool hasAmt;
  final double amount;
  final double balance;
  final bool isDark;

  const _HeroCard({
    required this.gaugeCtrl,
    required this.colorCtrl,
    required this.prevColor,
    required this.riskColor,
    required this.risk,
    required this.hasAmt,
    required this.amount,
    required this.balance,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surfBg = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Gauge ────────────────────────────────────────────────────
          SizedBox(
            height: 130,
            child: AnimatedBuilder(
              animation: Listenable.merge([gaugeCtrl, colorCtrl]),
              builder: (_, __) {
                final color =
                    Color.lerp(prevColor, riskColor, colorCtrl.value) ??
                        riskColor;
                return CustomPaint(
                  painter: _GaugePainter(
                    progress: gaugeCtrl.value,
                    fillColor: color,
                    trackColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: _T.display(40).copyWith(
                                color: hasAmt
                                    ? color
                                    : Colors.black.withOpacity(0.15),
                                letterSpacing: -1.5,
                              ),
                          child: Text(
                            hasAmt && balance > 0
                                ? '${((amount / balance) * 100).clamp(0, 999).toStringAsFixed(0)}%'
                                : '—',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'de tu saldo',
                          style: _T.label(11).copyWith(
                                color: isDark
                                    ? Colors.white.withOpacity(0.35)
                                    : Colors.black.withOpacity(0.35),
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ── Veredicto ────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 270),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position:
                    Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                        .animate(anim),
                child: child,
              ),
            ),
            child: hasAmt
                ? _VerdictRow(risk: risk, isDark: isDark, key: ValueKey(risk))
                : Padding(
                    key: const ValueKey('empty'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Escribe un monto para ver el resultado',
                      style: _T.label(14).copyWith(
                            color: isDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black.withOpacity(0.3),
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _VerdictRow extends StatelessWidget {
  final _Risk risk;
  final bool isDark;

  const _VerdictRow({required this.risk, required this.isDark, super.key});

  String _advice(_Risk risk) => switch (risk) {
        _Risk.safe =>
          'Tu situación financiera lo soporta sin comprometer tus metas.',
        _Risk.caution =>
          'Es posible, pero ajusta otros gastos para mantener tu fondo.',
        _Risk.high => 'Comprometería tu estabilidad financiera este mes.',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: risk.color.withOpacity(isDark ? 0.2 : 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                switch (risk) {
                  _Risk.safe => Iconsax.shield_tick,
                  _Risk.caution => Iconsax.warning_2,
                  _Risk.high => Iconsax.danger,
                },
                size: 14,
                color: risk.color,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              risk.label,
              style: _T.display(16).copyWith(color: risk.color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          _advice(risk),
          textAlign: TextAlign.center,
          style: _T.label(13).copyWith(
                color: isDark
                    ? Colors.white.withOpacity(0.45)
                    : Colors.black.withOpacity(0.45),
                height: 1.4,
              ),
        ),
      ],
    );
  }
}

// =============================================================================
// GAUGE PAINTER
// =============================================================================

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color trackColor;

  const _GaugePainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.80;
    final r = math.min(size.width / 2, size.height) - 14.0;

    const start = math.pi;
    const sweep = math.pi;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start,
      sweep,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0.008) {
      final fill = progress.clamp(0.0, 1.0);

      // Glow
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep * fill,
        false,
        Paint()
          ..color = fillColor.withOpacity(0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // Fill
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start,
        sweep * fill,
        false,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter o) =>
      o.progress != progress || o.fillColor != fillColor;
}

// =============================================================================
// BALANCE BAR
// =============================================================================

class _BalanceBar extends StatelessWidget {
  final double balance;
  final double budget;
  final double spent;
  final double amount;
  final double protectedAmount; // Nuevo campo para el dinero protegido en metas
  final bool isDark;
  final Color surfBg;

  const _BalanceBar({
    required this.balance,
    required this.budget,
    required this.spent,
    required this.amount,
    required this.isDark,
    required this.surfBg,
    required this.protectedAmount,
  });

  void _showProtectedMoneyInfo(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _kGreen.withOpacity(isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Iconsax.shield_tick, size: 28, color: _kGreen),
              ),
              const SizedBox(height: 16),
              Text(
                'Dinero protegido',
                style: _T.display(20),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: _T.label(14).copyWith(
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.5,
                      ),
                  children: [
                    const TextSpan(text: 'En Sasper creemos que '),
                    TextSpan(
                      text: '"cada moneda debe tener un propósito".\n\n',
                      style: _T.label(14, w: FontWeight.bold),
                    ),
                    const TextSpan(text: 'Tu saldo disponible aquí es tu '),
                    TextSpan(
                      text: 'Liquidez Real',
                      style: _T
                          .label(14, w: FontWeight.bold)
                          .copyWith(color: _kGreen),
                    ),
                    const TextSpan(text: '. Hemos ocultado automáticamente '),
                    TextSpan(
                      text: _fmtCompact.format(protectedAmount),
                      style: _T.label(14, w: FontWeight.bold),
                    ),
                    const TextSpan(
                        text:
                            ' que ya tienes ahorrados en tus metas.\n\nEse dinero ya tiene un trabajo, ¡así evitamos que lo gastes por accidente!'),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Entendido',
                    style: _T
                        .label(16, w: FontWeight.w600)
                        .copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = balance - amount;
    final hasAmt = amount > 0;
    final spentPct = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Saldo disponible
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SALDO DISPONIBLE',
                  style: _T.label(9, w: FontWeight.w700).copyWith(
                        letterSpacing: 0.8,
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black.withOpacity(0.35),
                      ),
                ),
                // Si hay dinero protegido, mostramos el icono de info
                if (protectedAmount > 0) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => _showProtectedMoneyInfo(context),
                    child: Icon(
                      Iconsax.info_circle,
                      size: 14,
                      color: _kBlue.withOpacity(0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 150),
                  style: _T.mono(20).copyWith(
                        color: hasAmt
                            ? (remaining < 0 ? _kRed : _kGreen)
                            : (isDark ? Colors.white : Colors.black),
                      ),
                  child: Text(_fmtCompact.format(hasAmt ? remaining : balance)),
                ),
                if (hasAmt && remaining >= 0)
                  Text(
                    'después del gasto',
                    style: _T.label(10).copyWith(
                          color: isDark
                              ? Colors.white.withOpacity(0.35)
                              : Colors.black.withOpacity(0.35),
                        ),
                  ),
              ],
            ),
          ),

          // Separador
          Container(
            width: 0.5,
            height: 46,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.08),
          ),

          // Presupuesto
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PRESUPUESTO MES',
                  style: _T.label(9, w: FontWeight.w700).copyWith(
                        letterSpacing: 0.8,
                        color: isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black.withOpacity(0.35),
                      ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: spentPct,
                    minHeight: 5,
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.06),
                    valueColor: AlwaysStoppedAnimation(
                      spentPct > 0.8
                          ? _kRed
                          : spentPct > 0.5
                              ? _kOrange
                              : _kGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  budget > 0
                      ? '${_fmtCompact.format(spent)} / ${_fmtCompact.format(budget)}'
                      : 'Sin presupuesto activo',
                  style: _T.label(11, w: FontWeight.w600).copyWith(
                        color: isDark
                            ? Colors.white.withOpacity(0.6)
                            : Colors.black.withOpacity(0.6),
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
// AMOUNT FIELD
// =============================================================================

class _AmountField extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final _Risk risk;
  final bool hasAmt;
  final Color surfBg;
  final bool isDark;

  const _AmountField({
    required this.ctrl,
    required this.focus,
    required this.risk,
    required this.hasAmt,
    required this.surfBg,
    required this.isDark,
  });

  @override
  State<_AmountField> createState() => _AmountFieldState();
}

class _AmountFieldState extends State<_AmountField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(() {
      if (mounted) setState(() => _focused = widget.focus.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasAmt
        ? widget.risk.color.withOpacity(_focused ? 0.65 : 0.38)
        : (_focused ? _kBlue.withOpacity(0.55) : Colors.transparent);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.surfBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: _focused || widget.hasAmt ? 1.4 : 0.5,
        ),
      ),
      child: TextField(
        controller: widget.ctrl,
        focusNode: widget.focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
        ],
        style: _T.display(34).copyWith(
              color: widget.hasAmt
                  ? widget.risk.color
                  : (widget.isDark ? Colors.white : Colors.black),
              letterSpacing: -0.8,
            ),
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: _T.display(34).copyWith(
                color: widget.isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.15),
                letterSpacing: -0.8,
              ),
          prefixText: '  \$  ',
          prefixStyle: _T.display(20).copyWith(
                color: widget.hasAmt
                    ? widget.risk.color
                    : (widget.isDark
                        ? Colors.white.withOpacity(0.25)
                        : Colors.black.withOpacity(0.25)),
              ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

// =============================================================================
// QUICK AMOUNTS
// =============================================================================

class _QuickAmounts extends StatelessWidget {
  final double balance;
  final bool isDark;
  final void Function(double) onTap;

  const _QuickAmounts({
    required this.balance,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      ('10 %', balance * 0.10),
      ('25 %', balance * 0.25),
      ('50 %', balance * 0.50),
    ];

    return Row(
      children: options.asMap().entries.map((e) {
        final i = e.key;
        final o = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
            child: _PressChip(
              label: o.$1,
              sublabel: _fmtCompact.format(o.$2),
              onTap: () => onTap(o.$2),
              isDark: isDark,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PressChip extends StatefulWidget {
  final String label;
  final String sublabel;
  final VoidCallback onTap;
  final bool isDark;

  const _PressChip({
    required this.label,
    required this.sublabel,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_PressChip> createState() => _PressChipState();
}

class _PressChipState extends State<_PressChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onTap();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.93, _c.value)!,
          child: Container(
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.label,
                  style: _T.label(13).copyWith(color: _kBlue),
                ),
                const SizedBox(height: 1),
                Text(
                  widget.sublabel,
                  style: _T.label(10).copyWith(
                        color: widget.isDark
                            ? Colors.white.withOpacity(0.35)
                            : Colors.black.withOpacity(0.35),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CATEGORY PICKER
// =============================================================================

class _CategoryPicker extends StatelessWidget {
  final Future<List<Category>> future;
  final Category? selected;
  final bool isDark;
  final Color surfBg;
  final void Function(Category?) onChanged;

  const _CategoryPicker({
    required this.future,
    required this.selected,
    required this.isDark,
    required this.surfBg,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 56,
            decoration: BoxDecoration(
                color: surfBg, borderRadius: BorderRadius.circular(16)),
          );
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return Text(
            'No se encontraron categorías.',
            style: _T.label(13).copyWith(
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.4),
                ),
          );
        }

        final cats = snap.data!;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: surfBg,
            borderRadius: BorderRadius.circular(16),
            border: selected != null
                ? Border.all(
                    color: selected!.colorAsObject.withOpacity(0.4),
                    width: 1.2,
                  )
                : null,
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<Category>(
                value: selected,
                isExpanded: true,
                borderRadius: BorderRadius.circular(16),
                dropdownColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark
                      ? Colors.white.withOpacity(0.3)
                      : Colors.black.withOpacity(0.3),
                  size: 20,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                hint: Row(
                  children: [
                    Icon(
                      Iconsax.category,
                      size: 18,
                      color: isDark
                          ? Colors.white.withOpacity(0.3)
                          : Colors.black.withOpacity(0.3),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Selecciona una categoría',
                      style: _T.label(15).copyWith(
                            color: isDark
                                ? Colors.white.withOpacity(0.3)
                                : Colors.black.withOpacity(0.3),
                          ),
                    ),
                  ],
                ),
                items: cats.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cat.colorAsObject
                                .withOpacity(isDark ? 0.18 : 0.09),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            cat.icon,
                            color: cat.colorAsObject,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          cat.name,
                          style: _T.label(15).copyWith(
                                color: isDark ? Colors.white : Colors.black,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// METRICS ROW
// =============================================================================

class _MetricsRow extends StatelessWidget {
  final double amount;
  final double balance;
  final double budget;
  final _Risk risk;
  final bool isDark;
  final Color surfBg;

  const _MetricsRow({
    required this.amount,
    required this.balance,
    required this.budget,
    required this.risk,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = balance - amount;
    final pctBudget = budget > 0 ? (amount / budget * 100) : 0.0;
    final pctBalance = balance > 0 ? (amount / balance * 100) : 0.0;

    return Row(
      children: [
        Expanded(
          child: _MetricCell(
            label: 'Te quedarán',
            value: _fmtCompact.format(remaining),
            color: remaining < 0 ? _kRed : _kGreen,
            isDark: isDark,
            surfBg: surfBg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCell(
            label: 'Del presupuesto',
            value: budget > 0
                ? '${pctBudget.toStringAsFixed(1)} %'
                : 'Sin presupuesto',
            color: pctBudget > 50
                ? _kRed
                : pctBudget > 25
                    ? _kOrange
                    : _kGreen,
            isDark: isDark,
            surfBg: surfBg,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCell(
            label: 'Del saldo',
            value: '${pctBalance.toStringAsFixed(1)} %',
            color: risk.color,
            isDark: isDark,
            surfBg: surfBg,
          ),
        ),
      ],
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final Color surfBg;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    required this.surfBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Iconsax.wallet_3,
              size: 13,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: _T.label(10).copyWith(
                  color: isDark
                      ? Colors.white.withOpacity(0.4)
                      : Colors.black.withOpacity(0.4),
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: _T.mono(13).copyWith(color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SIMULATE BUTTON
// =============================================================================

class _SimulateButton extends StatefulWidget {
  final bool isLoading;
  final bool canTap;
  final VoidCallback onTap;

  const _SimulateButton({
    required this.isLoading,
    required this.canTap,
    required this.onTap,
  });

  @override
  State<_SimulateButton> createState() => _SimulateButtonState();
}

class _SimulateButtonState extends State<_SimulateButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => GestureDetector(
              onTapDown: (widget.canTap && !widget.isLoading)
                  ? (_) => _c.forward()
                  : null,
              onTapUp: (widget.canTap && !widget.isLoading)
                  ? (_) async {
                      await _c.reverse();
                      widget.onTap();
                    }
                  : null,
              onTapCancel: () => _c.reverse(),
              child: Transform.scale(
                scale: ui.lerpDouble(1.0, 0.97, _c.value)!,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  decoration: BoxDecoration(
                    color: widget.canTap ? _kBlue : _kBlue.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Iconsax.cpu,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              'Ver análisis completo',
                              style: _T
                                  .label(17, w: FontWeight.w600)
                                  .copyWith(color: Colors.white),
                            ),
                          ],
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

// =============================================================================
// BLUR HEADER
// =============================================================================

class _BlurHeader extends SliverPersistentHeaderDelegate {
  final String title;
  final Color scaffoldBg;
  final VoidCallback onBack;

  const _BlurHeader({
    required this.title,
    required this.scaffoldBg,
    required this.onBack,
  });

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: 56,
          color: scaffoldBg.withOpacity(0.93),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _BackBtn(onBack: onBack),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: _T.display(17)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_BlurHeader o) => o.title != title;
}

class _BackBtn extends StatefulWidget {
  final VoidCallback onBack;
  const _BackBtn({required this.onBack});

  @override
  State<_BackBtn> createState() => _BackBtnState();
}

class _BackBtnState extends State<_BackBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp: (_) async {
        await _c.reverse();
        widget.onBack();
      },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: ui.lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _kBlue,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION LABEL
// =============================================================================

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: _T.label(11, w: FontWeight.w500).copyWith(
            color: isDark
                ? Colors.white.withOpacity(0.35)
                : Colors.black.withOpacity(0.35),
            letterSpacing: 0.6,
          ),
    );
  }
}

// =============================================================================
// LOADING / ERROR
// =============================================================================

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: _kBlue, strokeWidth: 2),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScaffold({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_rounded, color: _kRed, size: 40),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: _T.label(15).copyWith(height: 1.4)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Reintentar',
                      style: _T.label(15).copyWith(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
