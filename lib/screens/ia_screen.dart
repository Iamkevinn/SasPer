// lib/screens/ai_financial_analysis_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Análisis IA — Apple-first redesign
//
// Eliminado:
// · SliverAppBar.large + FlexibleSpaceBar → header blur sticky
// · RadialGradient pulsante en ícono → ícono simple con opacity
// · _FeaturesGrid con GridView + Border.all → lista de features limpia
// · FilledButton.icon Material → _PillBtn con press state
// · _NeuralNetworkPainter (red neuronal giratoria) → texto que rota
// · _LoadingSteps con 3 CircularProgressIndicator → paso único animado
// · LinearGradient + Border.all(width:2) + BoxShadow en HeroCard
// · Border.all colorido en métricas y tarjetas
// · InkWell + ripple Material → GestureDetector con press state
// · GoogleFonts.poppins + .inter mezclados → _T tokens DM Sans / DM Mono
// · flutter_animate .scale() .slideY() agresivos → fade sutil staggered
// · AlertDialog para troubleshooting → _TroubleshootSheet blur
// · _SettingsTile Material → _SheetRow pattern
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/services/ai_analysis_service.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────────
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

  static const double h = 20.0;
  static const double r = 18.0;
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);
const _kPurple = Color(0xFFBF5AF2);

final _fmt = NumberFormat.currency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);

// ── Modelos ─────────────────────────────────────────────────────────────────────
enum _AiState { initial, loading, success, error }
enum _Health  { critical, poor, fair, good, excellent }

class _Insight {
  final String title, description, impact;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final VoidCallback? onAction;
  const _Insight({
    required this.title, required this.description,
    required this.impact, required this.icon,
    required this.color, required this.actionLabel,
    this.onAction,
  });
}

class _Rec {
  final String title, description, impactUnit;
  final double projectedImpact;
  final IconData icon;
  final Color color;
  const _Rec({
    required this.title, required this.description,
    required this.projectedImpact, required this.impactUnit,
    required this.icon, required this.color,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class AiFinancialAnalysisScreen extends StatefulWidget {
  const AiFinancialAnalysisScreen({super.key});
  @override
  State<AiFinancialAnalysisScreen> createState() =>
      _AiFinancialAnalysisScreenState();
}

class _AiFinancialAnalysisScreenState extends State<AiFinancialAnalysisScreen>
    with TickerProviderStateMixin {
  final _aiService = AiAnalysisService();

  _AiState _state  = _AiState.initial;
  String? _result;
  String? _errorMsg;

  // Score ring
  late final AnimationController _scoreCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
      value: 0);

  // Loading — texto que rota
  late final AnimationController _loadingCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat();
  int _loadingStep = 0;
  static const _loadingMessages = [
    'Analizando transacciones…',
    'Detectando patrones…',
    'Generando recomendaciones…',
    'Preparando tu análisis…',
  ];

  // Mock data
  final _health     = _Health.good;
  final _score      = 78.0;
  final _savingsAdv = 12.0;
  final _monthsAdv  = 4;

  late final _recs = <_Rec>[
    const _Rec(title: 'Reducir gastos fijos',
        description: 'Al bajar 5% en recurrentes liberarás más capital',
        projectedImpact: 200000, impactUnit: '/mes',
        icon: Iconsax.money_remove, color: _kOrange),
    const _Rec(title: 'Automatizar inversiones',
        description: 'Invierte excedentes automáticamente cada mes',
        projectedImpact: 8, impactUnit: '% anual',
        icon: Iconsax.chart_success, color: _kGreen),
    const _Rec(title: 'Optimizar deudas',
        description: 'Consolida deudas de alta tasa en un solo préstamo',
        projectedImpact: 150000, impactUnit: '/año',
        icon: Iconsax.receipt_discount, color: _kBlue),
  ];

  late final _insights = <_Insight>[
    _Insight(title: 'Riesgo de sobregiro',
        description: 'Tu flujo de caja podría estar en riesgo en 21 días',
        impact: 'Riesgo alto', icon: Iconsax.danger, color: _kRed,
        actionLabel: 'Prevenir ahora'),
    _Insight(title: 'Oportunidad de ahorro',
        description: 'Puedes redirigir \$300.000 a inversiones este mes',
        impact: '+\$3.6M al año', icon: Iconsax.coin_1, color: _kGreen,
        actionLabel: 'Activar ahorro'),
  ];

  @override
  void initState() {
    super.initState();
    _loadingCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _loadingCtrl.repeat();
        if (mounted && _state == _AiState.loading) {
          setState(() =>
              _loadingStep = (_loadingStep + 1) % _loadingMessages.length);
        }
      }
    });
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    _loadingCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    HapticFeedback.mediumImpact();
    setState(() { _state = _AiState.loading; _loadingStep = 0; });
    try {
      await Future.delayed(const Duration(milliseconds: 2500));
      final r = await _aiService.getFinancialAnalysis();
      if (!mounted) return;
      setState(() { _result = r; _state = _AiState.success; });
      _scoreCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString().replaceFirst('Exception: ', '');
        _state = _AiState.error;
      });
      HapticFeedback.heavyImpact();
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final onSurf  = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(children: [
        // ── Header blur sticky ───────────────────────────────────────────
        ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.93),
              padding: EdgeInsets.only(
                  top: statusH + 10, left: _T.h + 4,
                  right: 8, bottom: 14),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SASPER',
                        style: _T.label(10, w: FontWeight.w700,
                            c: onSurf.withOpacity(0.35))),
                    Text('Análisis IA',
                        style: _T.display(28, c: onSurf)),
                  ],
                )),
                // Refrescar (solo en success)
                if (_state == _AiState.success)
                  _HeaderBtn(icon: Iconsax.refresh, onTap: _run),
                _HeaderBtn(
                  icon: Iconsax.setting_4,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _openSettings();
                  },
                ),
                const SizedBox(width: 8),
              ]),
            ),
          ),
        ),

        // ── Contenido ────────────────────────────────────────────────────
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: _buildBody(),
          ),
        ),
      ]),
    );
  }

  Widget _buildBody() {
    return switch (_state) {
      _AiState.initial => _InitialView(onStart: _run),
      _AiState.loading => _LoadingView(
          ctrl: _loadingCtrl,
          message: _loadingMessages[_loadingStep]),
      _AiState.success => _SuccessView(
          health:      _health,
          score:       _score,
          savingsAdv:  _savingsAdv,
          monthsAdv:   _monthsAdv,
          scoreCtrl:   _scoreCtrl,
          insights:    _insights,
          recs:        _recs,
          result:      _result,
          onRecTap:    _openRecDetail,
        ),
      _AiState.error => _ErrorView(
          message: _errorMsg,
          onRetry: _run,
          onHelp:  _openTroubleshoot,
        ),
    };
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: const _SettingsSheet(),
      ),
    );
  }

  void _openRecDetail(_Rec rec) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _RecDetailSheet(rec: rec),
      ),
    );
  }

  void _openTroubleshoot() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: const _TroubleshootSheet(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO INICIAL
// ─────────────────────────────────────────────────────────────────────────────
// Una sola propuesta de valor clara + botón. Sin grid de features que
// bloquee la acción principal. El usuario llega, entiende, pulsa.

class _InitialView extends StatelessWidget {
  final VoidCallback onStart;
  const _InitialView({required this.onStart});

  static const _features = <(IconData, String, String)>[
    (Iconsax.chart_success, 'Proyecciones', 'Anticipa tu flujo futuro'),
    (Iconsax.shield_tick,   'Riesgos',      'Detecta amenazas a tiempo'),
    (Iconsax.lamp_on,       'Oportunidades','Descubre dónde mejorar'),
    (Iconsax.trend_up,      'Optimización', 'Acciones concretas y claras'),
  ];

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(_T.h, 32, _T.h, 100),
      children: [
        // Ícono central — sin gradiente, sin sombra
        Center(
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Center(
                child: Icon(Iconsax.cpu_charge5,
                    size: 42, color: _kBlue)),
          ),
        ),
        const SizedBox(height: 28),

        // Headline
        Text('Tu asesor financiero\npersonal',
            style: _T.display(30, c: onSurf),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Text(
          'Activa el análisis para recibir recomendaciones personalizadas '
          'y optimizar tu salud financiera.',
          style: _T.label(15,
              c: onSurf.withOpacity(0.48), w: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 36),

        // Features — lista limpia, sin tarjetas con borde
        _FeatureList(features: _features),
        const SizedBox(height: 36),

        // CTA
        _PillBtn(
          label: 'Activar análisis',
          icon: Iconsax.flash_15,
          onTap: onStart,
        ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  final List<(IconData, String, String)> features;
  const _FeatureList({required this.features});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Column(
        children: features.indexed.map((e) {
          final (i, (icon, title, sub)) = e;
          final isLast = i == features.length - 1;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kBlue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                      child: Icon(icon, size: 17, color: _kBlue)),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: _T.label(14,
                            w: FontWeight.w700, c: onSurf)),
                    const SizedBox(height: 1),
                    Text(sub,
                        style: _T.label(12,
                            c: onSurf.withOpacity(0.42))),
                  ],
                )),
              ]),
            ),
            if (!isLast)
              Padding(
                padding: const EdgeInsets.only(left: 66),
                child: Container(
                    height: 0.5,
                    color: onSurf.withOpacity(0.07))),
          ]);
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO LOADING
// ─────────────────────────────────────────────────────────────────────────────
// Un solo mensaje que cambia cada ciclo. Sin spinners múltiples.
// El punto animado (...) comunica actividad sin ansiedad.

class _LoadingView extends StatelessWidget {
  final AnimationController ctrl;
  final String message;
  const _LoadingView({required this.ctrl, required this.message});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Spinner iOS — delgado, color primario
            SizedBox(
              width: 56, height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                    AlwaysStoppedAnimation<Color>(_kBlue),
              ),
            ),
            const SizedBox(height: 32),
            Text('Procesando',
                style: _T.display(22, c: onSurf)),
            const SizedBox(height: 10),
            // Mensaje que cambia — fade in/out suave
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                message,
                key: ValueKey(message),
                style: _T.label(15,
                    c: onSurf.withOpacity(0.48),
                    w: FontWeight.w400),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'La IA analiza patrones y genera recomendaciones\npersonalizadas para tu situación.',
              style: _T.label(13,
                  c: onSurf.withOpacity(0.30),
                  w: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO SUCCESS
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessView extends StatelessWidget {
  final _Health health;
  final double score, savingsAdv;
  final int monthsAdv;
  final AnimationController scoreCtrl;
  final List<_Insight> insights;
  final List<_Rec> recs;
  final String? result;
  final void Function(_Rec) onRecTap;

  const _SuccessView({
    required this.health, required this.score,
    required this.savingsAdv, required this.monthsAdv,
    required this.scoreCtrl, required this.insights,
    required this.recs, required this.result,
    required this.onRecTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
      children: [
        // Hero — score ring
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _T.h),
          child: _ScoreCard(
            health: health, score: score,
            savingsAdv: savingsAdv, monthsAdv: monthsAdv,
            ctrl: scoreCtrl,
          ),
        ),
        const SizedBox(height: 28),

        // Métricas rápidas
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _T.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('ESTE MES'),
              const SizedBox(height: 10),
              _MetricsRow(),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Alertas e insights
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _T.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('ALERTAS'),
              const SizedBox(height: 10),
              ...insights.asMap().entries.map((e) =>
                _InsightTile(insight: e.value,
                    delay: 80 * e.key)),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Recomendaciones
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _T.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel('RECOMENDACIONES'),
              const SizedBox(height: 10),
              ...recs.asMap().entries.map((e) =>
                _RecTile(rec: e.value,
                    delay: 80 * e.key,
                    onTap: () => onRecTap(e.value))),
            ],
          ),
        ),

        // Markdown análisis detallado
        if (result != null) ...[
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _T.h),
            child: _AnalysisCard(markdown: result!),
          ),
        ],
      ],
    );
  }
}

// ── Score card ────────────────────────────────────────────────────────────────
// Surface limpia. El número es el protagonista.
// Sin LinearGradient, sin border coloreado, sin boxShadow enorme.

class _ScoreCard extends StatelessWidget {
  final _Health health;
  final double score, savingsAdv;
  final int monthsAdv;
  final AnimationController ctrl;
  const _ScoreCard({
    required this.health, required this.score,
    required this.savingsAdv, required this.monthsAdv,
    required this.ctrl,
  });

  Color get _color => switch (health) {
    _Health.excellent => _kGreen,
    _Health.good      => _kBlue,
    _Health.fair      => _kOrange,
    _Health.poor      => _kOrange,
    _Health.critical  => _kRed,
  };

  String get _label => switch (health) {
    _Health.excellent => 'Excelente',
    _Health.good      => 'Buena',
    _Health.fair      => 'Regular',
    _Health.poor      => 'Mejorable',
    _Health.critical  => 'Crítica',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(22)),
      child: Row(children: [
        // Score ring
        AnimatedBuilder(
          animation: ctrl,
          builder: (_, __) => SizedBox(
            width: 90, height: 90,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: ctrl.value * (score / 100),
                strokeWidth: 6,
                backgroundColor: onSurf.withOpacity(0.08),
                valueColor: AlwaysStoppedAnimation<Color>(_color),
                strokeCap: StrokeCap.round,
              ),
              Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                  '${(score * ctrl.value).toInt()}',
                  style: _T.display(28, c: _color)),
                Text(_label,
                    style: _T.label(10,
                        c: onSurf.withOpacity(0.42))),
              ]),
            ]),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salud financiera',
                style: _T.label(12,
                    c: onSurf.withOpacity(0.40))),
            const SizedBox(height: 4),
            Text('Ahorro mejoró\n${savingsAdv.toStringAsFixed(0)}% este mes',
                style: _T.display(17, c: onSurf)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Iconsax.flash_15,
                  size: 13, color: _color),
              const SizedBox(width: 5),
              Expanded(child: Text(
                '$monthsAdv  meses antes a tu objetivo',
                style: _T.label(12,
                    c: onSurf.withOpacity(0.48)))),
            ]),
          ],
        )),
      ]),
    );
  }
}

// ── Métricas rápidas ──────────────────────────────────────────────────────────
// Sin border, sin color de fondo colorido. Número protagonista.

class _MetricsRow extends StatelessWidget {
  static const _data = <(String, String, String, Color)>[
    ('Ingresos', '\$3.2M', '+12%', _kGreen),
    ('Gastos',   '\$2.1M', '-5%',  _kBlue),
    ('Ahorro',   '\$1.1M', '+34%', _kPurple),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Row(children: _data.indexed.map((e) {
      final (i, (label, value, trend, color)) = e;
      final isLast = i == _data.length - 1;
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(right: isLast ? 0 : 10),
          padding: const EdgeInsets.symmetric(
              vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: _T.label(11,
                      c: onSurf.withOpacity(0.40))),
              const SizedBox(height: 4),
              Text(value,
                  style: _T.mono(16, c: onSurf)),
              const SizedBox(height: 4),
              Text(trend,
                  style: _T.label(11,
                      c: color, w: FontWeight.w700)),
            ],
          ),
        ),
      );
    }).toList());
  }
}

// ── Insight tile ──────────────────────────────────────────────────────────────
// Surface con accent sutil. Sin border coloreado.

class _InsightTile extends StatefulWidget {
  final _Insight insight;
  final int delay;
  const _InsightTile({required this.insight, this.delay = 0});
  @override
  State<_InsightTile> createState() => _InsightTileState();
}

class _InsightTileState extends State<_InsightTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final ins     = widget.insight;
    final bg      = isDark
        ? ins.color.withOpacity(0.09)
        : ins.color.withOpacity(0.06);

    return GestureDetector(
      onTapDown: (_) {
        _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) {
        _c.reverse(); ins.onAction?.call(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.985, _c.value)!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(_T.r)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: ins.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(ins.icon,
                    color: ins.color, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(ins.title,
                        style: _T.label(14,
                            w: FontWeight.w700, c: onSurf))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ins.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(ins.impact,
                          style: _T.label(10,
                              c: ins.color,
                              w: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(ins.description,
                      style: _T.label(13,
                          c: onSurf.withOpacity(0.48),
                          w: FontWeight.w400)),
                ],
              )),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Rec tile ──────────────────────────────────────────────────────────────────

class _RecTile extends StatefulWidget {
  final _Rec rec;
  final int delay;
  final VoidCallback onTap;
  const _RecTile({required this.rec, required this.onTap, this.delay = 0});
  @override State<_RecTile> createState() => _RecTileState();
}

class _RecTileState extends State<_RecTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final rec    = widget.rec;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final impactStr = rec.impactUnit.contains('%')
        ? '+${rec.projectedImpact.toStringAsFixed(0)}${rec.impactUnit}'
        : '+${_fmt.format(rec.projectedImpact)}${rec.impactUnit}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: ()  { _c.reverse(); },
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.985, _c.value)!,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(_T.r)),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: rec.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: Icon(rec.icon,
                    color: rec.color, size: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.title,
                      style: _T.label(14,
                          w: FontWeight.w700, c: onSurf)),
                  const SizedBox(height: 2),
                  Text(rec.description,
                      style: _T.label(12,
                          c: onSurf.withOpacity(0.45),
                          w: FontWeight.w400)),
                  const SizedBox(height: 6),
                  Text(impactStr,
                      style: _T.mono(12, c: rec.color)),
                ],
              )),
              Icon(Icons.chevron_right_rounded,
                  size: 17,
                  color: onSurf.withOpacity(0.22)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Análisis markdown ─────────────────────────────────────────────────────────

class _AnalysisCard extends StatelessWidget {
  final String markdown;
  const _AnalysisCard({required this.markdown});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(_T.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Iconsax.document_text5, size: 16, color: _kBlue),
            const SizedBox(width: 8),
            Text('Análisis detallado',
                style: _T.label(13,
                    c: onSurf.withOpacity(0.60),
                    w: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          MarkdownBody(
            data: markdown,
            styleSheet: MarkdownStyleSheet.fromTheme(
                Theme.of(context)).copyWith(
              p: _T.label(14, w: FontWeight.w400,
                  c: onSurf.withOpacity(0.80)).copyWith(height: 1.65),
              h3: _T.label(15, w: FontWeight.w700,
                  c: onSurf).copyWith(height: 2.0),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADO ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry, onHelp;
  const _ErrorView({
    required this.message,
    required this.onRetry, required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _kRed.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                  child: Icon(Iconsax.warning_25,
                      size: 34, color: _kRed)),
            ),
            const SizedBox(height: 24),
            Text('Algo salió mal',
                style: _T.display(22, c: onSurf)),
            const SizedBox(height: 10),
            Text(
              message ??
                  'No se pudo completar el análisis.\nIntenta nuevamente.',
              style: _T.label(14,
                  c: onSurf.withOpacity(0.48), w: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _PillBtn(
                label: 'Reintentar',
                icon: Iconsax.refresh,
                onTap: onRetry),
            const SizedBox(height: 12),
            _GhostBtn(
                label: 'Ver soluciones',
                onTap: onHelp),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEETS
// ─────────────────────────────────────────────────────────────────────────────

class _RecDetailSheet extends StatelessWidget {
  final _Rec rec;
  const _RecDetailSheet({required this.rec});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    final impactStr = rec.impactUnit.contains('%')
        ? '+${rec.projectedImpact.toStringAsFixed(0)}${rec.impactUnit}'
        : '+${_fmt.format(rec.projectedImpact)}${rec.impactUnit}';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: onSurf.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2))),
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: sheetBg, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: rec.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(child: Icon(rec.icon,
                    size: 26, color: rec.color)),
              ),
              const SizedBox(height: 14),
              Text(rec.title, style: _T.display(20, c: onSurf),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(rec.description,
                  style: _T.label(14,
                      c: onSurf.withOpacity(0.50), w: FontWeight.w400),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              // Impacto proyectado — número protagonista
              Column(children: [
                Text('Impacto proyectado',
                    style: _T.label(11,
                        c: onSurf.withOpacity(0.38))),
                const SizedBox(height: 4),
                Text(impactStr,
                    style: _T.mono(32, c: rec.color)),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: _InlineBtn(
                    label: 'Cancelar', color: onSurf,
                    onTap: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                    label: 'Activar', color: rec.color, impact: true,
                    onTap: () {
                      Navigator.pop(context);
                      HapticFeedback.heavyImpact();
                    })),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _TroubleshootSheet extends StatelessWidget {
  const _TroubleshootSheet();

  static const _tips = <(IconData, String)>[
    (Iconsax.wifi,          'Verifica tu conexión a internet'),
    (Iconsax.receipt_add,   'Asegúrate de tener transacciones registradas'),
    (Iconsax.refresh,       'Cierra y abre la app'),
    (Iconsax.message_question, 'Si persiste, contacta soporte'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: onSurf.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2))),
          Text('Posibles soluciones',
              style: _T.label(13,
                  c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: sheetBg, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              ..._tips.indexed.map((e) {
                final (i, (icon, text)) = e;
                final isLast = i == _tips.length - 1;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    child: Row(children: [
                      Icon(icon, size: 16,
                          color: onSurf.withOpacity(0.50)),
                      const SizedBox(width: 14),
                      Expanded(child: Text(text,
                          style: _T.label(14, c: onSurf))),
                    ]),
                  ),
                  if (!isLast)
                    Padding(padding: const EdgeInsets.only(left: 48),
                        child: Container(height: 0.5,
                            color: onSurf.withOpacity(0.07))),
                ]);
              }),
            ]),
          ),
          const SizedBox(height: 10),
          _CancelRow(),
        ]),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  static const _items = <(IconData, String, String)>[
    (Iconsax.personalcard, 'Personalización',         'Alto'),
    (Iconsax.notification, 'Notificaciones predictivas', 'Activadas'),
    (Iconsax.timer_1,      'Frecuencia de análisis',   'Diaria'),
    (Iconsax.shield_tick,  'Privacidad de datos',       'Máxima seguridad'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                  color: onSurf.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(2))),
          Text('Configuración IA',
              style: _T.label(13,
                  c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
                color: sheetBg, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              ..._items.indexed.map((e) {
                final (i, (icon, title, val)) = e;
                final isFirst = i == 0;
                final isLast  = i == _items.length - 1;
                final topR = isFirst
                    ? const Radius.circular(16) : Radius.zero;
                final botR = isLast
                    ? const Radius.circular(16) : Radius.zero;
                return Column(children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.only(
                          topLeft: topR, topRight: topR,
                          bottomLeft: botR, bottomRight: botR)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      child: Row(children: [
                        Icon(icon, size: 16,
                            color: onSurf.withOpacity(0.50)),
                        const SizedBox(width: 14),
                        Expanded(child: Text(title,
                            style: _T.label(14, c: onSurf))),
                        Text(val,
                            style: _T.label(13,
                                c: _kBlue, w: FontWeight.w600)),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded,
                            size: 16,
                            color: onSurf.withOpacity(0.22)),
                      ]),
                    ),
                  ),
                  if (!isLast)
                    Padding(padding: const EdgeInsets.only(left: 48),
                        child: Container(height: 0.5,
                            color: onSurf.withOpacity(0.07))),
                ]);
              }),
            ]),
          ),
          const SizedBox(height: 10),
          _PillBtn(label: 'Guardar cambios', onTap: () => Navigator.pop(context)),
          const SizedBox(height: 10),
          _CancelRow(),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Text(text,
        style: _T.label(11, w: FontWeight.w700,
            c: onSurf.withOpacity(0.35)));
  }
}

class _HeaderBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});
  @override State<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends State<_HeaderBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(widget.icon,
                size: 20, color: onSurf.withOpacity(0.60)),
          ),
        ),
      ),
    );
  }
}

class _PillBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.onTap, this.icon});
  @override State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.mediumImpact(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: _kBlue, borderRadius: BorderRadius.circular(14)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
                children: [
              if (widget.icon != null) ...[
                Icon(widget.icon!, size: 17, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(widget.label,
                  style: _T.label(16,
                      c: Colors.white, w: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GhostBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GhostBtn({required this.label, required this.onTap});
  @override State<_GhostBtn> createState() => _GhostBtnState();
}

class _GhostBtnState extends State<_GhostBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(widget.label,
                style: _T.label(15, c: _kBlue, w: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _InlineBtn extends StatefulWidget {
  final String label; final Color color;
  final bool impact; final VoidCallback onTap;
  const _InlineBtn({required this.label, required this.color,
      required this.onTap, this.impact = false});
  @override State<_InlineBtn> createState() => _InlineBtnState();
}

class _InlineBtnState extends State<_InlineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.impact ? HapticFeedback.mediumImpact()
                      : HapticFeedback.selectionClick();
      },
      onTapUp: (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(widget.label,
                style: _T.label(15,
                    w: FontWeight.w600, c: widget.color))),
          ),
        ),
      ),
    );
  }
}

class _CancelRow extends StatefulWidget {
  @override State<_CancelRow> createState() => _CancelRowState();
}

class _CancelRowState extends State<_CancelRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); Navigator.pop(context); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.97, _c.value)!,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text('Cancelar',
                style: _T.label(16,
                    w: FontWeight.w600, c: _kBlue))),
          ),
        ),
      ),
    );
  }
}