// lib/screens/dashboard_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER — Dashboard Premium, diseño Apple-first
// Jerarquía: identidad → balance → aspiraciones → control → análisis
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:sasper/data/challenge_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/models/challenge_model.dart';
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/screens/budget_details_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/screens/can_i_afford_it_screen.dart';
import 'package:sasper/screens/goals_screen.dart';
import 'package:sasper/screens/ia_screen.dart';
import 'package:sasper/screens/manifestations_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:sasper/services/widgets/widget_orchestrator.dart';
import 'package:sasper/widgets/dashboard/active_challenges_widget.dart';
import 'package:sasper/widgets/dashboard/category_spending_chart.dart';

// ── Tokens de diseño ─────────────────────────────────────────────────────────
class _D {
  // Colores semánticos — se adaptan al tema del sistema
  static const teal    = Color(0xFF00C896);   // acento principal
  static const tealDim = Color(0xFF00C896);
  static const gold    = Color(0xFFFFCC00);   // metas / manifestaciones
  static const rose    = Color(0xFFFF6B6B);   // alertas

  // Espaciado
  static const h  = 20.0;   // horizontal gutter
  static const r  = 24.0;   // radio base de tarjetas
  static const r2 = 16.0;   // radio secundario

  // Tipografía — DM Sans para UI, Playfair para números grandes
  static TextStyle display(double size, {Color? color}) => GoogleFonts.playfairDisplay(
    fontSize: size, fontWeight: FontWeight.w700,
    color: color, letterSpacing: -1.0, height: 1.0,
  );
  static TextStyle label(double size, {FontWeight w = FontWeight.w500, Color? color}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: w, color: color);
  static TextStyle caption(double size, {Color? color}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: FontWeight.w400, color: color, letterSpacing: 0.1);
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  final _repo = DashboardRepository.instance;

  // Initialized at field level — safe before initState completes.
  late final Stream<DashboardData> _stream =
      _repo.getDashboardDataStream();

  StreamSubscription? _sub;
  bool _hasShownCelebration = false;
  bool _reduceMotion = false;

  // Nullable until initState — avoids LateInitializationError.
  // Access via _breathe getter which asserts non-null.
  AnimationController? _breatheCtrl;
  AnimationController get _breathe => _breatheCtrl!;

  // Fallback used only if build() fires before initState (hot-reload edge case).
  // A zero-duration stopped controller — no vsync needed, never ticks.
  static final _breatheFallback = AnimationController(
    vsync: const _NoVsync(),
    duration: Duration.zero,
  );

  @override
  void initState() {
    super.initState();

    _sub = _stream.listen((data) {
      if (!data.isLoading && mounted) {
        WidgetOrchestrator().updateAllFromDashboard(data, context);
      }
    });
    _repo.forceRefresh(silent: true);

    // vsync (this) is available here — safe to create controller.
    _breatheCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _reduceMotion = MediaQuery.of(context).disableAnimations);
    });
  }

  @override
  void dispose() {
    _breatheCtrl?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _refresh() => _repo.forceRefresh(silent: false);

  void _go(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  Future<void> _checkCelebrations(DashboardData data) async {
    if (_hasShownCelebration) return;
    _hasShownCelebration = true;
    try {
      final done = await ChallengeRepository.instance.checkUserChallengesStatus();
      for (final c in done) {
        await Future.delayed(500.ms);
        if (mounted) {
          showDialog(
            context: context, barrierDismissible: false,
            builder: (_) => _CelebrationDialog(challenge: c, reduceMotion: _reduceMotion),
          );
        }
      }
    } catch (e) {
      developer.log('🔥 celebration error: $e', name: 'Dashboard');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false, bottom: false,
        child: StreamBuilder<DashboardData>(
          stream: _stream,
          builder: (context, snap) {
            final loading = !snap.hasData || snap.data!.isLoading;
            final data = loading ? DashboardData.empty() : snap.data!;
            if (!loading && !_hasShownCelebration) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _checkCelebrations(data));
            }
            return Skeletonizer(
              enabled: loading,
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: _D.teal,
                child: _DashboardBody(
                  data: data,
                  breathe: _breatheCtrl ?? _breatheFallback,
                  reduceMotion: _reduceMotion,
                  onAiTap: () => _go(const AiFinancialAnalysisScreen()),
                  onSimulateTap: () => _go(_AiAnalysisFullScreen(dashboardData: data)),
                  onAddTap: () => _go(const TransactionsScreen()),
                  onGoalsTap: () => _go(const GoalsScreen()),
                  onManifestTap: () => _go(const ManifestationsScreen()),
                  onAffordTap: () => _go(const CanIAffordItScreen()),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD BODY — CustomScrollView orquestado
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final DashboardData data;
  final AnimationController breathe;
  final bool reduceMotion;
  final VoidCallback onAiTap, onSimulateTap, onAddTap,
      onGoalsTap, onManifestTap, onAffordTap;

  const _DashboardBody({
    required this.data,
    required this.breathe,
    required this.reduceMotion,
    required this.onAiTap,
    required this.onSimulateTap,
    required this.onAddTap,
    required this.onGoalsTap,
    required this.onManifestTap,
    required this.onAffordTap,
  });

  Widget _sliver(Widget w, {int delayMs = 0}) => SliverToBoxAdapter(
    child: reduceMotion ? w : w.animate().fadeIn(
      delay: Duration(milliseconds: delayMs),
      duration: const Duration(milliseconds: 500),
    ).slideY(begin: 0.04, curve: Curves.easeOutCubic),
  );

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // ── 1. Header compacto con saludo + balance ─────────────────
        SliverPersistentHeader(
          pinned: true,
          delegate: _CompactHeaderDelegate(
            data: data,
            breathe: breathe,
            onAiTap: onAiTap,
          ),
        ),

        // ── 2. Sección de Aspiraciones (Metas + Manifestaciones) ────
        _sliver(
          _AspirationsSection(
            onGoalsTap: onGoalsTap,
            onManifestTap: onManifestTap,
          ),
          delayMs: 80,
        ),

        // ── 3. Acciones rápidas ─────────────────────────────────────
        _sliver(
          _QuickBar(
            onAddTap: onAddTap,
            onSimulateTap: onSimulateTap,
            onAffordTap: onAffordTap,
          ),
          delayMs: 140,
        ),

        // ── 4. Presupuestos ─────────────────────────────────────────
        _sliver(_BudgetsSection(budgets: data.featuredBudgets), delayMs: 200),

        // ── 5. Retos activos ────────────────────────────────────────
        _sliver(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _D.h),
            child: const ActiveChallengesWidget(),
          ),
          delayMs: 260,
        ),

        // ── 6. Distribución de gastos ───────────────────────────────
        _sliver(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _D.h),
            child: CategorySpendingChart(spendingData: data.categorySpendingSummary),
          ),
          delayMs: 320,
        ),

        // ── Espacio inferior para nav bar ───────────────────────────
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPACT HEADER — Hero compacto con Saldo Operativo, Reservado y Deudas
// ─────────────────────────────────────────────────────────────────────────────

class _CompactHeaderDelegate extends SliverPersistentHeaderDelegate {
  final DashboardData data;
  final AnimationController breathe;
  final VoidCallback onAiTap;

  _CompactHeaderDelegate({
    required this.data,
    required this.breathe,
    required this.onAiTap,
  });

  @override double get minExtent => 110;
  @override double get maxExtent => 170;

  @override
  bool shouldRebuild(covariant _CompactHeaderDelegate old) =>
      data != old.data || onAiTap != old.onAiTap;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final statusH = MediaQuery.of(ctx).padding.top;
    final theme = Theme.of(ctx);
    final isDark = theme.brightness == Brightness.dark;
    
    // Formateador compacto para el patrimonio (ej: $12M)
    final fmtCompact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$');
    // Formateador normal para el saldo disponible (ej: $12.000.000)
    final fmtNormal = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    
    final onSurface = theme.colorScheme.onSurface;

    // Colores adaptativos
    final surfaceBg = isDark
        ? theme.scaffoldBackgroundColor.withOpacity(0.92)
        : theme.scaffoldBackgroundColor.withOpacity(0.94);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: surfaceBg,
          padding: EdgeInsets.only(
            top: statusH + 8,
            left: _D.h + 4,
            right: _D.h,
            bottom: 12,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children:[
              // Fila superior: saludo + Disponible + IA button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children:[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:[
                        // Saludo
                        AnimatedOpacity(
                          opacity: (1 - t * 2).clamp(0.0, 1.0),
                          duration: const Duration(milliseconds: 80),
                          child: Text(
                            _greeting(data.fullName),
                            style: _D.caption(13, color: onSurface.withOpacity(0.55)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        
                        // BALANCE OPERATIVO (El Disponible)
                        AnimatedBuilder(
                          animation: breathe,
                          builder: (_, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:[
                              Text(
                                // Usamos formato completo para el número principal si cabe
                                fmtNormal.format(data.availableBalance),
                                style: _D.display(lerpDouble(34, 24, t)!, color: onSurface),
                              ),
                              AnimatedOpacity(
                                opacity: (1 - t * 2).clamp(0.0, 1.0),
                                duration: const Duration(milliseconds: 80),
                                child: Row(
                                  children:[
                                    Icon(Iconsax.wallet_check, size: 12, color: _D.teal.withOpacity(0.9)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Disponible para gastar',
                                      style: _D.label(11, color: _D.teal.withOpacity(0.9), w: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // IA Pill button
                  _AiButton(onTap: onAiTap, breathe: breathe),
                ],
              ),

              const SizedBox(height: 12),

              // BARRA INFERIOR: PATRIMONIO NETO + SALUD
              AnimatedOpacity(
                opacity: (1 - t * 1.5).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 80),
                child: Row(
                  children:[
                    // Patrimonio Neto (Activos - Pasivos)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Iconsax.bank, size: 13, color: onSurface.withOpacity(0.7)),
                          const SizedBox(width: 6),
                          Text(
                            'Patrimonio: ${fmtCompact.format(data.netWorth)}',
                            style: _D.label(12, w: FontWeight.w600, color: onSurface.withOpacity(0.7)),
                          ),
                        ],
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Salud Financiera (Ya existente)
                    _HealthPill(score: data.healthScore),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(String fullName) {
    final hour = DateTime.now().hour;
    final first = fullName.split(' ').first;
    if (hour < 12) return 'Buenos días, $first 🌤';
    if (hour < 18) return 'Buenas tardes, $first ☀️';
    return 'Buenas noches, $first 🌙';
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// AI BUTTON — pill compacto con shimmer
// ─────────────────────────────────────────────────────────────────────────────

class _AiButton extends StatefulWidget {
  final VoidCallback onTap;
  final AnimationController breathe;
  const _AiButton({required this.onTap, required this.breathe});

  @override
  State<_AiButton> createState() => _AiButtonState();
}

class _AiButtonState extends State<_AiButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 90));
  }
  @override
  void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _press.forward(); HapticFeedback.lightImpact(); },
      onTapUp:   (_) { _press.reverse(); widget.onTap(); },
      onTapCancel: () => _press.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_press, widget.breathe]),
        builder: (_, __) {
          final scale = lerpDouble(1.0, 0.93, _press.value)!;
          final glow  = lerpDouble(8.0, 14.0, widget.breathe.value)!;
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C896), Color(0xFF00A3FF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: _D.teal.withOpacity(0.35),
                    blurRadius: glow,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.magic_star, size: 15, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('IA', style: _D.label(13,
                      w: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEALTH PILL — compacto, en el header
// ─────────────────────────────────────────────────────────────────────────────

class _HealthPill extends StatelessWidget {
  final double score;
  const _HealthPill({required this.score});

  (Color, String) _status() {
    if (score >= 80) return (const Color(0xFF30D158), 'Excelente');
    if (score >= 60) return (const Color(0xFF0A84FF), 'Bueno');
    if (score >= 40) return (const Color(0xFFFF9F0A), 'Regular');
    return (const Color(0xFFFF453A), 'Atención');
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = _status();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('$label · ${score.toInt()}',
              style: _D.label(11, w: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ASPIRACIONES — Metas + Manifestaciones (protagonistas visuales)
// ─────────────────────────────────────────────────────────────────────────────

class _AspirationsSection extends StatelessWidget {
  final VoidCallback onGoalsTap, onManifestTap;
  const _AspirationsSection({required this.onGoalsTap, required this.onManifestTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_D.h, 8, _D.h, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'TU FUTURO',
              style: _D.label(10,
                  w: FontWeight.w700,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.35)),
            ).animate().fadeIn(delay: 100.ms),
          ),

          // Dos tarjetas lado a lado
          Row(
            children: [
              Expanded(
                child: _AspirationCard(
                  icon: Iconsax.flag,
                  label: 'Metas',
                  sublabel: 'Define tus logros',
                  gradient: [const Color(0xFF0A84FF), const Color(0xFF5AC8FA)],
                  isDark: isDark,
                  onTap: onGoalsTap,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AspirationCard(
                  icon: Iconsax.magicpen,
                  label: 'Manifestar',
                  sublabel: 'Visualiza tu abundancia',
                  gradient: [const Color(0xFFFFCC00), const Color(0xFFFF9500)],
                  isDark: isDark,
                  onTap: onManifestTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AspirationCard extends StatefulWidget {
  final IconData icon;
  final String label, sublabel;
  final List<Color> gradient;
  final bool isDark;
  final VoidCallback onTap;

  const _AspirationCard({
    required this.icon, required this.label, required this.sublabel,
    required this.gradient, required this.isDark, required this.onTap,
  });

  @override
  State<_AspirationCard> createState() => _AspirationCardState();
}

class _AspirationCardState extends State<_AspirationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 100));
    _scale = Tween(begin: 1.0, end: 0.96).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          height: 108,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(_D.r),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withOpacity(0.28),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Círculo decorativo de fondo
              Positioned(
                right: -18, bottom: -18,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                right: 12, top: -10,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),

              // Contenido
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, size: 18, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(widget.label,
                        style: _D.label(16,
                            w: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(widget.sublabel,
                        style: _D.caption(11,
                            color: Colors.white.withOpacity(0.75))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUICK BAR — tres acciones horizontales compactas
// ─────────────────────────────────────────────────────────────────────────────

class _QuickBar extends StatelessWidget {
  final VoidCallback onAddTap, onSimulateTap, onAffordTap;
  const _QuickBar({required this.onAddTap, required this.onSimulateTap,
      required this.onAffordTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surface = theme.colorScheme.surfaceContainer;
    final onSurface = theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_D.h, 16, _D.h, 0),
      child: Row(
        children: [
          _QuickChip(
            icon: Iconsax.add_circle,
            label: 'Agregar',
            color: _D.teal,
            surface: surface,
            onSurface: onSurface,
            onTap: onAddTap,
          ),
          const SizedBox(width: 10),
          _QuickChip(
            icon: Iconsax.calculator,
            label: 'Simular',
            color: const Color(0xFF5AC8FA),
            surface: surface,
            onSurface: onSurface,
            onTap: onSimulateTap,
          ),
          const SizedBox(width: 10),
          _QuickChip(
            icon: Iconsax.wallet_3,
            label: '¿Lo puedo?',
            color: const Color(0xFFFF9500),
            surface: surface,
            onSurface: onSurface,
            onTap: onAffordTap,
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color, surface, onSurface;
  final VoidCallback onTap;

  const _QuickChip({
    required this.icon, required this.label, required this.color,
    required this.surface, required this.onSurface, required this.onTap,
  });

  @override
  State<_QuickChip> createState() => _QuickChipState();
}

class _QuickChipState extends State<_QuickChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTapDown: (_) { _ctrl.forward(); HapticFeedback.selectionClick(); },
        onTapUp:   (_) { _ctrl.reverse(); widget.onTap(); },
        onTapCancel: () => _ctrl.reverse(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Transform.scale(
            scale: lerpDouble(1.0, 0.94, _ctrl.value)!,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: widget.surface,
                borderRadius: BorderRadius.circular(_D.r),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.13),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 18, color: widget.color),
                  ),
                  const SizedBox(height: 7),
                  Text(widget.label,
                      style: _D.label(11,
                          w: FontWeight.w600,
                          color: widget.onSurface.withOpacity(0.8)),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUDGETS SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetsSection extends StatelessWidget {
  final List<Budget> budgets;
  const _BudgetsSection({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de sección
        Padding(
          padding: const EdgeInsets.fromLTRB(_D.h, 24, _D.h, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('Presupuestos',
                  style: _D.label(17, w: FontWeight.w700, color: onSurface)),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetsScreen())),
                child: Text('Ver todos',
                    style: _D.label(13,
                        w: FontWeight.w600,
                        color: _D.teal)),
              ),
            ],
          ),
        ),

        if (budgets.isEmpty)
          _EmptyBudgets()
        else
          SizedBox(
            height: 148,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: _D.h),
              itemCount: budgets.length,
              itemBuilder: (ctx, i) => Padding(
                padding: EdgeInsets.only(right: i < budgets.length - 1 ? 12 : 0),
                child: _BudgetCard(budget: budgets[i]),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyBudgets extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _D.h),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(_D.r),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _D.teal.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Iconsax.wallet_add, size: 20, color: _D.teal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Crea tu primer presupuesto y toma el control.',
                style: _D.caption(13,
                    color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetCard extends StatefulWidget {
  final Budget budget;
  const _BudgetCard({required this.budget});
  @override
  State<_BudgetCard> createState() => _BudgetCardState();
}

class _BudgetCardState extends State<_BudgetCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 80));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  (Color, IconData) _status(double p) {
    if (p >= 0.9) return (const Color(0xFFFF453A), Iconsax.danger);
    if (p >= 0.7) return (const Color(0xFFFF9F0A), Iconsax.warning_2);
    return (const Color(0xFF30D158), Iconsax.shield_tick);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$');
    final progress = (widget.budget.amount > 0
        ? widget.budget.spentAmount / widget.budget.amount
        : 0.0).clamp(0.0, 1.0);
    final (statusColor, statusIcon) = _status(progress);
    final onSurface = theme.colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) {
        _ctrl.reverse();
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => BudgetDetailsScreen(budgetId: widget.budget.id)));
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _ctrl.value)!,
          child: Container(
            width: 180,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(_D.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoría + ícono de estado
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.budget.category,
                        style: _D.label(14, w: FontWeight.w700, color: onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(statusIcon, size: 16, color: statusColor),
                  ],
                ),
                const Spacer(),

                // Montos
                Text(
                  fmt.format(widget.budget.spentAmount),
                  style: _D.display(20, color: onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'de ${fmt.format(widget.budget.amount)}',
                  style: _D.caption(11,
                      color: onSurface.withOpacity(0.45)),
                ),
                const SizedBox(height: 10),

                // Barra de progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: statusColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(progress * 100).toInt()}% usado',
                  style: _D.label(10,
                      w: FontWeight.w600, color: statusColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CELEBRATION DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _CelebrationDialog extends StatelessWidget {
  final UserChallenge challenge;
  final bool reduceMotion;
  const _CelebrationDialog({required this.challenge, required this.reduceMotion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!reduceMotion)
              SizedBox(
                width: 180, height: 130,
                child: Lottie.asset(
                    'assets/animations/confetti_celebration.json',
                    repeat: false),
              ),
            Text('¡Reto Completado!',
                style: _D.label(20, w: FontWeight.w800,
                    color: theme.colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(challenge.challengeDetails.title,
                textAlign: TextAlign.center,
                style: _D.caption(14,
                    color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _D.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.star_1, size: 16, color: _D.gold),
                  const SizedBox(width: 6),
                  Text('+${challenge.challengeDetails.rewardXp} XP',
                      style: _D.label(14,
                          w: FontWeight.w700, color: _D.gold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: _D.teal,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text('¡Genial!',
                    style: _D.label(15, w: FontWeight.w700,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI ANALYSIS SCREEN (pantalla de simulación, sin cambios estructurales)
// ─────────────────────────────────────────────────────────────────────────────

class _AiAnalysisFullScreen extends StatefulWidget {
  final DashboardData dashboardData;
  const _AiAnalysisFullScreen({required this.dashboardData});
  @override
  State<_AiAnalysisFullScreen> createState() => _AiAnalysisFullScreenState();
}

class _AiAnalysisFullScreenState extends State<_AiAnalysisFullScreen> {
  double _expenseChange = 0;
  double _savingsChange = 0;
  Timer? _debounce;

  @override
  void dispose() { _debounce?.cancel(); super.dispose(); }

  void _slide(double v, String type) {
    _debounce?.cancel();
    _debounce = Timer(200.ms, () {
      setState(() {
        if (type == 'expense') _expenseChange = v;
        else _savingsChange = v;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    
    // NOTA: La simulación ahora se hace sobre el saldo DISPONIBLE, no el total
    final cb = widget.dashboardData.availableBalance; 
    final cp = widget.dashboardData.monthlyProjection;
    final nb = cb - _expenseChange + _savingsChange;
    final np = cp - _expenseChange + _savingsChange;

    return Scaffold(
      appBar: AppBar(
        title: Row(children:[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00C896), Color(0xFF00A3FF)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.magic_star, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Text('Simulación', style: _D.label(18, w: FontWeight.w700)),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(_D.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:[
            Text('Ajusta los valores', style: _D.label(18, w: FontWeight.w700)),
            const SizedBox(height: 16),
            _Slider(
              label: 'Reducir gastos',
              value: _expenseChange, max: 500000,
              color: const Color(0xFFFF453A),
              icon: Iconsax.arrow_down_1,
              onChanged: (v) => _slide(v, 'expense'),
            ),
            const SizedBox(height: 12),
            _Slider(
              label: 'Aumentar ahorro',
              value: _savingsChange, max: 300000,
              color: const Color(0xFF30D158),
              icon: Iconsax.arrow_up_1,
              onChanged: (v) => _slide(v, 'savings'),
            ),
            const SizedBox(height: 28),
            Text('Impacto', style: _D.label(18, w: FontWeight.w700)),
            const SizedBox(height: 12),
            _Comparison(
              title: 'Disponible para gastar', // <-- Actualizado
              before: fmt.format(cb), after: fmt.format(nb),
              diff: fmt.format(nb - cb), isPos: nb >= cb,
            ),
            const SizedBox(height: 12),
            _Comparison(
              title: 'Proyección mensual',
              before: fmt.format(cp), after: fmt.format(np),
              diff: fmt.format(np - cp), isPos: np >= cp,
            ),
            if (_expenseChange > 0 || _savingsChange > 0) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cambios guardados'),
                          behavior: SnackBarBehavior.floating),
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Iconsax.tick_circle),
                  label: Text('Aplicar cambios',
                      style: _D.label(15, w: FontWeight.w700)),
                  style: FilledButton.styleFrom(
                    backgroundColor: _D.teal,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class _Slider extends StatelessWidget {
  final String label;
  final double value, max;
  final Color color;
  final IconData icon;
  final ValueChanged<double> onChanged;

  const _Slider({required this.label, required this.value, required this.max,
    required this.color, required this.icon, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(_D.r),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: _D.label(14, w: FontWeight.w600))),
          Text(fmt.format(value),
              style: _D.label(15, w: FontWeight.w700, color: color)),
        ]),
        Slider(value: value, max: max, divisions: 20,
            onChanged: onChanged, activeColor: color),
      ]),
    );
  }
}

class _Comparison extends StatelessWidget {
  final String title, before, after, diff;
  final bool isPos;
  const _Comparison({required this.title, required this.before,
    required this.after, required this.diff, required this.isPos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isPos ? const Color(0xFF30D158) : const Color(0xFFFF453A);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_D.r),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _D.caption(13, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Antes', style: _D.caption(11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 3),
            Text(before, style: _D.display(18, color: theme.colorScheme.onSurface)),
          ])),
          Icon(Iconsax.arrow_right_3, size: 18,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4)),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Después', style: _D.caption(11, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 3),
            Text(after, style: _D.display(18, color: color)),
          ])),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isPos ? Iconsax.arrow_up_2 : Iconsax.arrow_down_2,
                size: 14, color: color),
            const SizedBox(width: 5),
            Text('${isPos ? "+" : ""}$diff',
                style: _D.label(12, w: FontWeight.w700, color: color)),
          ]),
        ),
      ]),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06);
  }
}

// ── No-op TickerProvider for static/fallback AnimationControllers ────────────
class _NoVsync implements TickerProvider {
  const _NoVsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}