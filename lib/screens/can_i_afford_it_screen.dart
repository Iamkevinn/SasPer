// lib/screens/can_i_afford_it_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA — Apple iOS / Health + Calculator                                │
// │                                                                             │
// │  Pregunta que responde en < 1 segundo:                                     │
// │  "¿Puedo permitirme esto?"                                                 │
// │                                                                             │
// │  Apple lo resuelve como Face ID: respuesta INSTANTÁNEA, veredicto visual,  │
// │  sin que el usuario tenga que procesar texto para entender el resultado.   │
// │                                                                             │
// │  JERARQUÍA DE INFORMACIÓN:                                                 │
// │  1. Hero card — Gauge + porcentaje + veredicto. Todo junto. Un bloque.    │
// │     El color del gauge ES la respuesta. El texto la confirma.             │
// │  2. Balance bar — contexto compacto en una línea.                         │
// │  3. Input del monto — grande, el borde refleja el riesgo en tiempo real.  │
// │  4. Quick amounts — 10% / 25% / 50% con montos reales al lado.           │
// │  5. Categoría — contextualiza el análisis de IA.                          │
// │  6. Métricas (aparecen al escribir) — 3 celdas: quedan, % presupuesto,   │
// │     % saldo. Cada una con color semántico.                                │
// │  7. Una recomendación — la más relevante. Sin carrusel.                   │
// │  8. Botón "Análisis completo con IA" — único CTA primario.               │
// │                                                                             │
// │  ELIMINADO vs original:                                                    │
// │  • "Simulación Inteligente" con ícono pulsante infinito → ruido           │
// │  • Carrusel horizontal de 3 recomendaciones → requiere trabajo del user   │
// │  • Gradientes decorativos en tarjetas → distracción visual                │
// │  • Gauge y métricas separados → unificados en hero card                   │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

// ─── TOKENS ──────────────────────────────────────────────────────────────────
class _C {
  final BuildContext ctx;
  _C(this.ctx);

  bool get isDark => Theme.of(ctx).brightness == Brightness.dark;

  // Superficies iOS systemGroupedBackground
  Color get bg      => isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface => isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get raised  => isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get sep     => isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  // Escala label iOS
  Color get label  => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get label2 => isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get label3 => isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get label4 => isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  // Semánticos iOS
  static const Color red    = Color(0xFFFF3B30);
  static const Color green  = Color(0xFF30D158);
  static const Color orange = Color(0xFFFF9F0A);
  static const Color blue   = Color(0xFF0A84FF);
  static const Color indigo = Color(0xFF5E5CE6);

  // Layout
  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double rMD  = 12.0;
  static const double rLG  = 16.0;
  static const double rXL  = 22.0;
  static const double r2XL = 28.0;

  static const Duration fast   = Duration(milliseconds: 130);
  static const Duration mid    = Duration(milliseconds: 270);
  static const Duration slow   = Duration(milliseconds: 480);
  static const Curve   easeOut = Curves.easeOutCubic;
  static const Curve   spring  = Curves.easeOutBack;
}

// ─── NIVEL DE RIESGO ─────────────────────────────────────────────────────────
// Enum rico: cada nivel lleva todo lo que necesita la UI.
// El color ES la respuesta — el texto la confirma.
enum RiskLevel {
  safe(
    verdict:    'Puedes permitírtelo',
    advice:     'Tu situación financiera lo soporta sin comprometer tus metas.',
    color:      _C.green,
    icon:       Iconsax.shield_tick,
  ),
  moderate(
    verdict:    'Con precaución',
    advice:     'Es posible, pero ajusta otros gastos esta semana.',
    color:      _C.orange,
    icon:       Iconsax.warning_2,
  ),
  high(
    verdict:    'Riesgo alto',
    advice:     'Comprometería tu estabilidad financiera este mes.',
    color:      _C.red,
    icon:       Iconsax.danger,
  );

  final String verdict;
  final String advice;
  final Color  color;
  final IconData icon;

  const RiskLevel({
    required this.verdict,
    required this.advice,
    required this.color,
    required this.icon,
  });
}

// ─── PANTALLA ─────────────────────────────────────────────────────────────────
class CanIAffordItScreen extends StatefulWidget {
  const CanIAffordItScreen({super.key});

  @override
  State<CanIAffordItScreen> createState() => _CanIAffordItScreenState();
}

class _CanIAffordItScreenState extends State<CanIAffordItScreen>
    with TickerProviderStateMixin {
  final _formKey     = GlobalKey<FormState>();
  final _amountCtrl  = TextEditingController();
  final _amountFocus = FocusNode();

  final SimulationRepository _simRepo     = SimulationRepository.instance;
  final CategoryRepository   _catRepo     = CategoryRepository.instance;
  final AccountRepository    _accountRepo = AccountRepository.instance;
  final BudgetRepository     _budgetRepo  = BudgetRepository.instance;

  Category? _selectedCategory;
  bool _isLoading     = false;
  bool _isDataLoading = true;
  String _dataError   = '';

  late Future<List<Category>> _categoriesFuture;

  // Datos financieros reales
  double _balance  = 0.0;
  double _budget   = 0.0;
  double _spent    = 0.0;

  // Estado reactivo
  double    _amount  = 0.0;
  bool      _hasAmt  = false;
  RiskLevel _risk    = RiskLevel.safe;

  // Animaciones
  late AnimationController _gaugeCtrl;   // Progreso del arco
  late AnimationController _revealCtrl;  // Aparición de métricas
  late AnimationController _switchCtrl;  // Cambio de veredicto

  late Animation<double> _gaugeAnim;
  late Animation<double> _revealAnim;
  late Animation<double> _switchAnim;

  // Para animar el cambio de color del gauge
  Color _prevColor   = _C.green;
  Color _targetColor = _C.green;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _catRepo.getExpenseCategories();
    _loadData();

    _gaugeCtrl = AnimationController(duration: _C.slow, vsync: this);
    _gaugeAnim = CurvedAnimation(parent: _gaugeCtrl, curve: _C.easeOut);

    _revealCtrl = AnimationController(duration: _C.mid, vsync: this);
    _revealAnim = CurvedAnimation(parent: _revealCtrl, curve: _C.easeOut);

    _switchCtrl = AnimationController(duration: _C.mid, vsync: this);
    _switchAnim = CurvedAnimation(parent: _switchCtrl, curve: _C.spring);

    _amountCtrl.addListener(_onAmount);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _amountFocus.dispose();
    _gaugeCtrl.dispose();
    _revealCtrl.dispose();
    _switchCtrl.dispose();
    super.dispose();
  }

  // ── Carga de datos ────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    try {
      final res = await Future.wait([
        _accountRepo.getAccounts(),
        _budgetRepo.getOverallBudgetSummary(),
      ]);
      final accounts    = res[0] as List<dynamic>;
      final totalBal    = accounts.fold<double>(0, (s, a) => s + a.balance);
      final budgetTuple = res[1] as (double, double);
      if (mounted) {
        setState(() {
          _balance     = totalBal;
          _budget      = budgetTuple.$1;
          _spent       = budgetTuple.$2;
          _isDataLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _dataError = 'No se pudieron cargar los datos.'; _isDataLoading = false; });
      }
    }
  }

  // ── Reactivo al monto ─────────────────────────────────────────────────────
  void _onAmount() {
    final raw    = _amountCtrl.text.replaceAll(',', '.');
    final parsed = double.tryParse(raw) ?? 0.0;
    final newRisk = parsed > 0 ? _calcRisk(parsed) : RiskLevel.safe;

    final riskChanged = newRisk != _risk;

    if (riskChanged) {
      _prevColor   = _risk.color;
      _targetColor = newRisk.color;
      _switchCtrl.forward(from: 0);
    }

    setState(() {
      _amount = parsed;
      _hasAmt = parsed > 0;
      _risk   = newRisk;
    });

    if (parsed > 0) {
      final pct = _balance > 0 ? (parsed / _balance).clamp(0.0, 1.0) : 0.0;
      _gaugeCtrl.animateTo(pct, duration: _C.slow, curve: _C.easeOut);
      _revealCtrl.forward();
    } else {
      _gaugeCtrl.animateTo(0, duration: _C.mid);
      _revealCtrl.reverse();
    }
  }

  RiskLevel _calcRisk(double amount) {
    final remaining   = _balance - amount;
    final pctOfBudget = _budget > 0 ? (amount / _budget) * 100 : 0.0;
    if (remaining < 0 || pctOfBudget > 50) return RiskLevel.high;
    if (pctOfBudget > 25 || remaining < _budget * 0.2) return RiskLevel.moderate;
    return RiskLevel.safe;
  }

  // ── Simulación ────────────────────────────────────────────────────────────
  Future<void> _simulate() async {
    if (!_formKey.currentState!.validate() || _selectedCategory == null) {
      HapticFeedback.vibrate();
      NotificationHelper.show(
          message: 'Selecciona una categoría para continuar.',
          type: NotificationType.error);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    try {
      final amount       = double.parse(_amountCtrl.text.replaceAll(',', '.'));
      final categoryName = _selectedCategory!.name;
      final result       = await _simRepo.getExpenseSimulation(
          amount: amount, categoryName: categoryName);
      if (mounted) {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(PageRouteBuilder(
          pageBuilder:      (_, a, __) => SimulationResultScreen(result: result),
          transitionDuration: _C.slow,
          transitionsBuilder: (_, anim, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: _C.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.04), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: _C.easeOut)),
              child: child,
            ),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        NotificationHelper.show(
            message: e.toString().replaceFirst('Exception: ', ''),
            type: NotificationType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final c = _C(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor:         Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:     c.isDark ? Brightness.dark  : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        body: _isDataLoading
            ? _Loader(c: c)
            : _dataError.isNotEmpty
                ? _ErrState(msg: _dataError, c: c, onRetry: () {
                    setState(() { _isDataLoading = true; _dataError = ''; });
                    _loadData();
                  })
                : _body(c),
      ),
    );
  }

  Widget _body(_C c) {
    return Form(
      key: _formKey,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // AppBar
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            automaticallyImplyLeading: false,
            leading: _BackBtn(c: c),
            title: Text('¿Me lo puedo permitir?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                    color: c.label, letterSpacing: -0.3)),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_C.md, _C.sm, _C.md, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── 1. HERO CARD — gauge + veredicto ─────────────────
                _HeroCard(
                  gaugeAnim:   _gaugeAnim,
                  switchAnim:  _switchAnim,
                  prevColor:   _prevColor,
                  targetColor: _targetColor,
                  risk:        _risk,
                  hasAmt:      _hasAmt,
                  amount:      _amount,
                  balance:     _balance,
                  c:           c,
                ),
                const SizedBox(height: _C.md),

                // ── 2. BALANCE BAR — contexto compacto ───────────────
                _BalanceBar(
                  balance: _balance, budget: _budget,
                  spent: _spent, currentAmount: _amount, c: c,
                ),
                const SizedBox(height: _C.lg),

                // ── 3. MONTO ──────────────────────────────────────────
                _Label(text: 'Monto del gasto', c: c),
                const SizedBox(height: _C.sm),
                _AmountInput(
                  ctrl: _amountCtrl, focus: _amountFocus,
                  risk: _risk, hasAmt: _hasAmt, c: c,
                ),
                const SizedBox(height: _C.sm),

                // Quick amounts 10 / 25 / 50 %
                _QuickRow(balance: _balance, c: c, onTap: (v) {
                  HapticFeedback.selectionClick();
                  _amountCtrl.text = v.toStringAsFixed(0);
                  _amountCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: _amountCtrl.text.length));
                }),
                const SizedBox(height: _C.lg),

                // ── 4. CATEGORÍA ──────────────────────────────────────
                _Label(text: 'Categoría', c: c),
                const SizedBox(height: _C.sm),
                _CatPicker(
                  future: _categoriesFuture, selected: _selectedCategory,
                  c: c,
                  onChanged: (cat) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat);
                  },
                ),

                // ── 5. MÉTRICAS — aparecen al escribir ────────────────
                AnimatedSize(
                  duration: _C.mid, curve: _C.easeOut,
                  child: _hasAmt
                      ? Column(children: [
                          const SizedBox(height: _C.lg),
                          _Label(text: 'Impacto en tu bolsillo', c: c),
                          const SizedBox(height: _C.sm),
                          FadeTransition(
                            opacity: _revealAnim,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.06),
                                end: Offset.zero,
                              ).animate(_revealAnim),
                              child: _MetricsRow(
                                amount: _amount, balance: _balance,
                                budget: _budget, risk: _risk, c: c,
                              ),
                            ),
                          ),
                          const SizedBox(height: _C.md),
                          FadeTransition(
                            opacity: _revealAnim,
                            child: _RecCard(
                              risk: _risk, amount: _amount,
                              balance: _balance, c: c,
                            ),
                          ),
                        ])
                      : const SizedBox.shrink(),
                ),

                const SizedBox(height: _C.xl),

                // ── 6. CTA ────────────────────────────────────────────
                _SimBtn(isLoading: _isLoading, c: c, onTap: _simulate),

                SizedBox(height: _C.xl + MediaQuery.of(context).padding.bottom),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── HERO CARD ────────────────────────────────────────────────────────────────
// El único elemento visual grande de toda la pantalla.
// Gauge + porcentaje + veredicto — todo en un solo bloque cohesionado.
// El color del arco ES la respuesta. No necesitas leer el texto para entender.
class _HeroCard extends StatelessWidget {
  final Animation<double> gaugeAnim;
  final Animation<double> switchAnim;
  final Color prevColor;
  final Color targetColor;
  final RiskLevel risk;
  final bool hasAmt;
  final double amount;
  final double balance;
  final _C c;

  const _HeroCard({
    required this.gaugeAnim, required this.switchAnim,
    required this.prevColor, required this.targetColor,
    required this.risk, required this.hasAmt,
    required this.amount, required this.balance, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          _C.lg, _C.lg, _C.lg, _C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.r2XL),
        border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.18 : 0.04),
              blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(children: [
        // ── Gauge animado ──────────────────────────────────────────────
        SizedBox(
          height: 140,
          child: AnimatedBuilder(
            animation: Listenable.merge([gaugeAnim, switchAnim]),
            builder: (_, __) {
              // Interpolar color entre estado anterior y nuevo
              final animColor = Color.lerp(
                prevColor, targetColor, switchAnim.value) ?? targetColor;

              return CustomPaint(
                painter: _GaugePainter(
                  progress:   gaugeAnim.value,
                  fillColor:  animColor,
                  trackColor: c.sep,
                  isDark:     c.isDark,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 24), // compensa arco superior
                      AnimatedDefaultTextStyle(
                        duration: _C.mid,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: hasAmt ? animColor : c.label4,
                          letterSpacing: -1.2,
                          height: 1.0,
                        ),
                        child: Text(
                          hasAmt && balance > 0
                              ? '${((amount / balance) * 100).clamp(0, 999).toStringAsFixed(0)}%'
                              : '—',
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text('de tu saldo',
                          style: TextStyle(
                              fontSize: 11, color: c.label3)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: _C.sm),

        // ── Veredicto — cambia con AnimatedSwitcher ────────────────────
        AnimatedSwitcher(
          duration: _C.mid,
          switchInCurve: _C.easeOut,
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.12), end: Offset.zero)
                  .animate(anim),
              child: child,
            ),
          ),
          child: hasAmt
              ? _VerdictRow(risk: risk, c: c, key: ValueKey(risk))
              : Padding(
                  key: const ValueKey('empty'),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Escribe un monto para ver el veredicto',
                    style: TextStyle(fontSize: 14, color: c.label4),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ]),
    );
  }
}

class _VerdictRow extends StatelessWidget {
  final RiskLevel risk;
  final _C c;
  const _VerdictRow({required this.risk, required this.c, super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: risk.color.withOpacity(c.isDark ? 0.22 : 0.10),
              shape: BoxShape.circle),
          child: Icon(risk.icon, size: 14, color: risk.color),
        ),
        const SizedBox(width: _C.sm),
        Text(
          risk.verdict,
          style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: risk.color, letterSpacing: -0.3,
          ),
        ),
      ]),
      const SizedBox(height: 5),
      Text(
        risk.advice,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: c.label3, height: 1.4),
      ),
    ]);
  }
}

// ─── GAUGE PAINTER ────────────────────────────────────────────────────────────
class _GaugePainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Color trackColor;
  final bool isDark;

  const _GaugePainter({
    required this.progress, required this.fillColor,
    required this.trackColor, required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.78;
    final r  = math.min(size.width / 2, size.height) - 16.0;

    const start = math.pi;
    const sweep = math.pi;

    // Track
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      start, sweep, false,
      Paint()
        ..color      = trackColor.withOpacity(isDark ? 0.30 : 0.18)
        ..style      = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap   = StrokeCap.round,
    );

    if (progress > 0.008) {
      final fill = progress.clamp(0.0, 1.0);

      // Glow — aparece solo con progreso
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep * fill, false,
        Paint()
          ..color      = fillColor.withOpacity(isDark ? 0.28 : 0.18)
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 20
          ..strokeCap   = StrokeCap.round
          ..maskFilter  = const MaskFilter.blur(BlurStyle.normal, 7),
      );

      // Fill
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        start, sweep * fill, false,
        Paint()
          ..color      = fillColor
          ..style      = PaintingStyle.stroke
          ..strokeWidth = 10
          ..strokeCap   = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter o) =>
      o.progress != progress || o.fillColor != fillColor;
}

// ─── BALANCE BAR ─────────────────────────────────────────────────────────────
// Dos columnas en una tarjeta compacta.
// Izquierda: saldo disponible (dinámico si hay monto).
// Derecha: progreso del presupuesto mensual.
class _BalanceBar extends StatelessWidget {
  final double balance;
  final double budget;
  final double spent;
  final double currentAmount;
  final _C c;

  const _BalanceBar({
    required this.balance, required this.budget,
    required this.spent, required this.currentAmount, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final compact   = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final remaining  = balance - currentAmount;
    final spentPct   = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;
    final hasAmt     = currentAmount > 0;

    return Container(
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: c.sep.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Saldo disponible
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SALDO DISPONIBLE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: c.label3)),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: _C.fast,
              style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                letterSpacing: -0.6, height: 1.0,
                color: hasAmt
                    ? (remaining < 0 ? _C.red : _C.green)
                    : c.label,
              ),
              child: Text(compact.format(hasAmt ? remaining : balance)),
            ),
            if (hasAmt && remaining >= 0) ...[
              const SizedBox(height: 2),
              Text('después del gasto',
                  style: TextStyle(fontSize: 10, color: c.label3)),
            ],
          ]),
        ),

        // Separador
        Container(width: 0.5, height: 46,
            margin: const EdgeInsets.symmetric(horizontal: _C.md),
            color: c.sep),

        // Presupuesto del mes
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('PRESUPUESTO MES',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    letterSpacing: 0.8, color: c.label3)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: spentPct,
                minHeight: 5,
                backgroundColor: c.sep.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation(
                  spentPct > 0.8 ? _C.red
                      : spentPct > 0.5 ? _C.orange : _C.green,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${compact.format(spent)} / ${compact.format(budget)}',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: c.label2),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── AMOUNT INPUT ─────────────────────────────────────────────────────────────
// El monto es el protagonista — fontSize 34, bold.
// El borde cambia de color según el riesgo en tiempo real.
// Sin leer el texto del veredicto, el usuario ya sabe la respuesta.
class _AmountInput extends StatefulWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final RiskLevel risk;
  final bool hasAmt;
  final _C c;

  const _AmountInput({
    required this.ctrl, required this.focus,
    required this.risk, required this.hasAmt, required this.c,
  });

  @override
  State<_AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<_AmountInput> {
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
    final c = widget.c;
    final borderColor = widget.hasAmt
        ? widget.risk.color.withOpacity(_focused ? 0.65 : 0.38)
        : (_focused ? _C.blue.withOpacity(0.55) : c.sep.withOpacity(0.45));
    final shadowColor = widget.hasAmt
        ? widget.risk.color.withOpacity(c.isDark ? 0.12 : 0.07)
        : Colors.black.withOpacity(c.isDark ? 0.14 : 0.03);

    return AnimatedContainer(
      duration: _C.mid,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(
            color: borderColor, width: _focused || widget.hasAmt ? 1.4 : 0.5),
        boxShadow: [
          BoxShadow(color: shadowColor,
              blurRadius: _focused ? 14 : 6, offset: const Offset(0, 2)),
        ],
      ),
      child: TextFormField(
        controller: widget.ctrl,
        focusNode: widget.focus,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(
          fontSize: 34, fontWeight: FontWeight.w800,
          color: widget.hasAmt ? widget.risk.color : c.label,
          letterSpacing: -0.8,
        ),
        validator: (v) {
          if (v == null || v.isEmpty) return '';
          final n = double.tryParse(v.replaceAll(',', '.'));
          if (n == null || n <= 0) return '';
          return null;
        },
        decoration: InputDecoration(
          hintText: '0',
          hintStyle: TextStyle(fontSize: 34, fontWeight: FontWeight.w800,
              color: c.label4, letterSpacing: -0.8),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: AnimatedDefaultTextStyle(
              duration: _C.fast,
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: widget.hasAmt ? widget.risk.color
                    : (_focused ? _C.blue : c.label4),
              ),
              child: const Text(' \$ '),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0),
          border:         InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: _C.md, vertical: 18),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
      ),
    );
  }
}

// ─── QUICK AMOUNTS ROW ────────────────────────────────────────────────────────
// 10% / 25% / 50% del saldo — con la cantidad real debajo.
// El usuario entiende el compromiso antes de tocar.
class _QuickRow extends StatelessWidget {
  final double balance;
  final _C c;
  final ValueChanged<double> onTap;

  const _QuickRow({
    required this.balance, required this.c, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final items = [(0.10, '10%'), (0.25, '25%'), (0.50, '50%')];

    return Row(children: [
      for (int i = 0; i < items.length; i++) ...[
        if (i > 0) const SizedBox(width: _C.sm),
        Expanded(
          child: _ScaleBtn(
            onTap: () => onTap(balance * items[i].$1),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: c.raised,
                borderRadius: BorderRadius.circular(_C.rMD),
                border: Border.all(color: c.sep.withOpacity(0.3), width: 0.5),
              ),
              child: Column(children: [
                Text(items[i].$2,
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w700, color: _C.blue)),
                const SizedBox(height: 2),
                Text(compact.format(balance * items[i].$1),
                    style: TextStyle(fontSize: 10, color: c.label3)),
              ]),
            ),
          ),
        ),
      ]
    ]);
  }
}

// ─── CATEGORY PICKER ─────────────────────────────────────────────────────────
class _CatPicker extends StatelessWidget {
  final Future<List<Category>> future;
  final Category? selected;
  final _C c;
  final ValueChanged<Category?> onChanged;

  const _CatPicker({
    required this.future, required this.selected,
    required this.c, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: future,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _Skel(c: c);
        }
        if (!snap.hasData || snap.data!.isEmpty) {
          return Text('No se encontraron categorías.',
              style: TextStyle(fontSize: 13, color: c.label3));
        }
        final cats = snap.data!;
        return AnimatedContainer(
          duration: _C.fast,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(_C.rXL),
            border: Border.all(
              color: selected != null
                  ? selected!.colorAsObject.withOpacity(0.38)
                  : c.sep.withOpacity(0.40),
              width: selected != null ? 1.2 : 0.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
                  blurRadius: 6, offset: const Offset(0, 1)),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: ButtonTheme(
              alignedDropdown: true,
              child: DropdownButton<Category>(
                value: selected,
                isExpanded: true,
                borderRadius: BorderRadius.circular(_C.rXL),
                dropdownColor: c.surface,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: c.label3, size: 20),
                padding: const EdgeInsets.symmetric(
                    horizontal: _C.md, vertical: 6),
                hint: Row(children: [
                  Icon(Iconsax.category, size: 18, color: c.label4),
                  const SizedBox(width: _C.md),
                  Text('Selecciona una categoría',
                      style: TextStyle(fontSize: 15, color: c.label4)),
                ]),
                items: cats.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Row(children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                          color: cat.colorAsObject.withOpacity(
                              c.isDark ? 0.18 : 0.09),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(cat.icon, color: cat.colorAsObject, size: 16),
                    ),
                    const SizedBox(width: _C.md),
                    Text(cat.name, style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600, color: c.label)),
                  ]),
                )).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── METRICS ROW ─────────────────────────────────────────────────────────────
// Tres celdas cuadradas — escaneables en un vistazo.
// Cada color refleja el nivel de riesgo de esa métrica individualmente.
class _MetricsRow extends StatelessWidget {
  final double amount;
  final double balance;
  final double budget;
  final RiskLevel risk;
  final _C c;

  const _MetricsRow({
    required this.amount, required this.balance,
    required this.budget, required this.risk, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final compact     = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final remaining   = balance - amount;
    final pctBudget   = budget > 0 ? (amount / budget * 100) : 0.0;
    final pctBalance  = balance > 0 ? (amount / balance * 100) : 0.0;

    return Row(children: [
      Expanded(child: _Cell(
        label: 'Te quedarán',
        value: compact.format(remaining),
        color: remaining < 0 ? _C.red : _C.green,
        icon: Iconsax.wallet_3, c: c,
      )),
      const SizedBox(width: _C.sm),
      Expanded(child: _Cell(
        label: 'Del presupuesto',
        value: '${pctBudget.toStringAsFixed(1)}%',
        color: pctBudget > 50 ? _C.red : pctBudget > 25 ? _C.orange : _C.green,
        icon: Iconsax.chart_1, c: c,
      )),
      const SizedBox(width: _C.sm),
      Expanded(child: _Cell(
        label: 'Del saldo total',
        value: '${pctBalance.toStringAsFixed(1)}%',
        color: risk.color,
        icon: Iconsax.percentage_circle, c: c,
      )),
    ]);
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  final _C c;

  const _Cell({
    required this.label, required this.value,
    required this.color, required this.icon, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(_C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rLG),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(c.isDark ? 0.14 : 0.03),
              blurRadius: 6, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: color.withOpacity(c.isDark ? 0.18 : 0.09),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(height: _C.sm),
        Text(label,
            style: TextStyle(fontSize: 10, color: c.label3,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                color: color, letterSpacing: -0.3),
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}

// ─── RECOMMENDATION CARD ─────────────────────────────────────────────────────
// UNA recomendación. La más relevante.
// Un carrusel requiere que el usuario trabaje. Una tarjeta comunica.
class _RecCard extends StatelessWidget {
  final RiskLevel risk;
  final double amount;
  final double balance;
  final _C c;

  const _RecCard({
    required this.risk, required this.amount,
    required this.balance, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final compact = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    final (title, body, icon) = switch (risk) {
      RiskLevel.safe => (
        'Hábito financiero saludable',
        'Este gasto encaja con tu situación. Te quedarán ${compact.format(balance - amount)} disponibles para imprevistos.',
        Iconsax.verify,
      ),
      RiskLevel.moderate => (
        'Considera ajustar otros gastos',
        'Es posible, pero reduce gastos variables esta semana para mantener tu fondo de emergencia intacto.',
        Iconsax.warning_2,
      ),
      RiskLevel.high => (
        'Busca una alternativa',
        'Este gasto comprometería tu estabilidad. Considera reducir a ${compact.format(balance * 0.20)} o posponerlo.',
        Iconsax.danger,
      ),
    };

    return AnimatedSwitcher(
      duration: _C.mid,
      switchInCurve: _C.easeOut,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(0, 0.05), end: Offset.zero)
              .animate(anim),
          child: child,
        ),
      ),
      child: Container(
        key: ValueKey(risk),
        padding: const EdgeInsets.all(_C.md),
        decoration: BoxDecoration(
          color: risk.color.withOpacity(c.isDark ? 0.08 : 0.04),
          borderRadius: BorderRadius.circular(_C.rXL),
          border: Border.all(
              color: risk.color.withOpacity(0.20), width: 0.5),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
                color: risk.color.withOpacity(c.isDark ? 0.20 : 0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: risk.color),
          ),
          const SizedBox(width: _C.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: c.label, letterSpacing: -0.1)),
              const SizedBox(height: 3),
              Text(body,
                  style: TextStyle(fontSize: 13, color: c.label3, height: 1.45)),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── SIMULATE BUTTON ─────────────────────────────────────────────────────────
class _SimBtn extends StatefulWidget {
  final bool isLoading;
  final _C c;
  final VoidCallback onTap;
  const _SimBtn({required this.isLoading, required this.c, required this.onTap});

  @override
  State<_SimBtn> createState() => _SimBtnState();
}

class _SimBtnState extends State<_SimBtn> {
  bool _p = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   widget.isLoading ? null : (_) => setState(() => _p = true),
      onTapUp:     widget.isLoading ? null : (_) { setState(() => _p = false); widget.onTap(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        scale: _p ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: AnimatedContainer(
          duration: _C.fast,
          height: 56,
          decoration: BoxDecoration(
            color: widget.isLoading ? widget.c.label4 : _C.blue,
            borderRadius: BorderRadius.circular(_C.rXL),
            boxShadow: widget.isLoading ? null : [
              BoxShadow(
                color: _C.blue.withOpacity(_p ? 0.18 : 0.35),
                blurRadius: _p ? 8 : 18,
                offset: Offset(0, _p ? 2 : 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.cpu, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Análisis completo con IA',
                        style: TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── UTILS ────────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final _C c;
  const _Label({required this.text, required this.c});

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
          color: c.label3, letterSpacing: 0.1));
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
        child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: c.label),
      ),
    );
  }
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
          scale: _p ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 80),
          child: widget.child),
    );
  }
}

class _Skel extends StatelessWidget {
  final _C c;
  const _Skel({required this.c});

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    decoration: BoxDecoration(
        color: c.surface, borderRadius: BorderRadius.circular(_C.rXL)),
    alignment: Alignment.center,
    child: SizedBox(width: 20, height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: c.label4)),
  );
}

class _Loader extends StatelessWidget {
  final _C c;
  const _Loader({required this.c});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const SizedBox(width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: _C.blue)),
      const SizedBox(height: _C.md),
      Text('Cargando datos…',
          style: TextStyle(fontSize: 15, color: c.label3)),
    ],
  ));
}

class _ErrState extends StatelessWidget {
  final String msg;
  final _C c;
  final VoidCallback onRetry;
  const _ErrState({required this.msg, required this.c, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_C.xl),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: _C.red.withOpacity(c.isDark ? 0.18 : 0.09),
                shape: BoxShape.circle),
            child: const Icon(Iconsax.danger, size: 28, color: _C.red),
          ),
          const SizedBox(height: _C.md),
          Text(msg, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: c.label3, height: 1.4)),
          const SizedBox(height: _C.lg),
          _ScaleBtn(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: _C.lg, vertical: 12),
              decoration: BoxDecoration(
                  color: _C.blue, borderRadius: BorderRadius.circular(_C.rMD)),
              child: const Text('Reintentar',
                  style: TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}