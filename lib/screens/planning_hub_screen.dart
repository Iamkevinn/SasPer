// lib/screens/planning_hub_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER — Planning Hub, diseño Apple-first
// Filosofía: editorial list, jerarquía clara, cero ruido visual.
// Inspirado en: Ajustes iOS, Robinhood, Monzo.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import 'package:sasper/screens/accounts_screen.dart';
import 'package:sasper/screens/analysis_screen.dart';
import 'package:sasper/screens/budgets_screen.dart';
import 'package:sasper/screens/challenges_screen.dart';
import 'package:sasper/screens/debts_screen.dart';
import 'package:sasper/screens/goals_screen.dart';
import 'package:sasper/screens/recurring_transactions_screen.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
class _T {
  // Tipografía — DM Sans para UI, números en SF-style via DM Sans Numeric
  static TextStyle title(double s, {FontWeight w = FontWeight.w700, Color? c}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.3);
  static TextStyle body(double s, {FontWeight w = FontWeight.w400, Color? c}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle label(double s, {FontWeight w = FontWeight.w500, Color? c}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: 0.1);

  // Espaciado
  static const h = 20.0;   // gutter horizontal
  static const r = 18.0;   // radio de sección
  static const ri = 14.0;  // radio de ícono
}

// ── Paleta de íconos — sistema cohesivo iOS-like ──────────────────────────────
// Cada color es una variante del sistema de colores de iOS
const _kBlue    = Color(0xFF0A84FF);
const _kGreen   = Color(0xFF30D158);
const _kOrange  = Color(0xFFFF9F0A);
const _kRed     = Color(0xFFFF453A);
const _kPurple  = Color(0xFFBF5AF2);
const _kTeal    = Color(0xFF5AC8FA);
const _kYellow  = Color(0xFFFFD60A);

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────

class _Item {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Widget destination;

  const _Item({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.destination,
  });
}

class _Section {
  final String title;
  final String? footnote;
  final List<_Item> items;
  const _Section({required this.title, this.footnote, required this.items});
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class PlanningHubScreen extends StatefulWidget {
  const PlanningHubScreen({super.key});
  @override
  State<PlanningHubScreen> createState() => _PlanningHubScreenState();
}

class _PlanningHubScreenState extends State<PlanningHubScreen>
    with SingleTickerProviderStateMixin {

  // mount controller drives nothing now — sections use flutter_animate.
  // Kept as a no-op placeholder in case future animations need it.
  AnimationController? _mountCtrl;

  late final List<_Section> _sections =[
    _Section(
      title: 'FINANZAS',
      footnote: 'Administra el flujo de tu dinero.',
      items: [
        _Item(
          icon: Iconsax.wallet_3,
          iconColor: _kBlue,
          title: 'Cuentas',
          subtitle: 'Bancos, efectivo y tarjetas',
          destination: const AccountsScreen(),
        ),
        _Item(
          icon: Iconsax.money_tick,
          iconColor: _kGreen,
          title: 'Presupuestos',
          subtitle: 'Límites mensuales por categoría',
          destination: const BudgetsScreen(),
        ),
        _Item(
          icon: Iconsax.receipt_2_1,
          iconColor: _kRed,
          title: 'Deudas',
          subtitle: 'Préstamos y pagos pendientes',
          destination: const DebtsScreen(),
        ),
        _Item(
          icon: Iconsax.repeat,
          iconColor: _kTeal,
          title: 'Gastos Fijos',
          subtitle: 'Automatiza ingresos y egresos',
          destination: const RecurringTransactionsScreen(),
        ),
      ],
    ),
    _Section(
      title: 'OBJETIVOS',
      footnote: 'Define hacia dónde va tu dinero.',
      items: [
        _Item(
          icon: Iconsax.flag,
          iconColor: _kOrange,
          title: 'Metas',
          subtitle: 'Ahorra para lo que importa',
          destination: const GoalsScreen(),
        ),
        _Item(
          icon: Iconsax.cup,
          iconColor: _kYellow,
          title: 'Retos',
          subtitle: 'Hábitos financieros gamificados',
          badge: 'NUEVO',
          destination: const ChallengesScreen(),
        ),
      ],
    ),
    _Section(
      title: 'ANÁLISIS',
      footnote: 'Entiende a dónde va tu dinero.',
      items: [
        _Item(
          icon: Iconsax.chart_1,
          iconColor: _kPurple,
          title: 'Análisis',
          subtitle: 'Informes y distribución de gastos',
          destination: const AnalysisScreen(),
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    // vsync (this) is ready here — safe to create the controller.
    _mountCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _mountCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final statusH = MediaQuery.of(context).padding.top;
    final bottomH = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── Header compacto con blur ──────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(
              statusBarHeight: statusH,
              backgroundColor: theme.scaffoldBackgroundColor,
            ),
          ),

          // ── Secciones ─────────────────────────────────────────────
          for (int si = 0; si < _sections.length; si++)
            SliverToBoxAdapter(
              child: _SectionBlock(
                section: _sections[si],
                sectionIndex: si,
                onTap: (item) => _navigate(item),
              ),
            ),

          // Espacio inferior para nav bar
          SliverToBoxAdapter(
            child: SizedBox(height: 100 + bottomH),
          ),
        ],
      ),
    );
  }

  void _navigate(_Item item) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, a, __) => item.destination,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(a),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 380),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER DELEGATE — compacto, blur, colapsa limpiamente
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final Color backgroundColor;

  const _HeaderDelegate({
    required this.statusBarHeight,
    required this.backgroundColor,
  });

  @override double get minExtent => statusBarHeight + 52;
  @override double get maxExtent => statusBarHeight + 120;

  @override
  bool shouldRebuild(covariant _HeaderDelegate old) =>
      statusBarHeight != old.statusBarHeight ||
      backgroundColor != old.backgroundColor;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    final t = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final theme = Theme.of(ctx);
    final onSurface = theme.colorScheme.onSurface;

    // Tamaño del título interpolado
    final titleSize = lerpDouble(32, 20, t)!;
    final subtitleOpacity = (1 - t * 2).clamp(0.0, 1.0);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: backgroundColor.withOpacity(t > 0.3 ? 0.92 : 0),
          padding: EdgeInsets.only(
            top: statusBarHeight + 12,
            left: _T.h + 4,
            right: _T.h,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Subtítulo — desaparece al colapsar
              Opacity(
                opacity: subtitleOpacity,
                child: Text(
                  'PLANIFICACIÓN',
                  style: _T.label(10, w: FontWeight.w700, c: onSurface.withOpacity(0.35)),
                ),
              ),
              const SizedBox(height: 2),
              // Título principal — se comprime
              Text(
                'Centro',
                style: _T.title(titleSize, c: onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION BLOCK — grupo de ítems estilo iOS Settings
// ─────────────────────────────────────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  final _Section section;
  final int sectionIndex;
  final ValueChanged<_Item> onTap;

  const _SectionBlock({
    required this.section,
    required this.sectionIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    // Explicit surface color that is always visible regardless of theme variant.
    // iOS uses a slightly elevated surface — we replicate that manually.
    final cardColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.04);

    final delay = Duration(milliseconds: 80 + sectionIndex * 90);

    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 24, _T.h, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label — estilo iOS Settings
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              section.title,
              style: _T.label(11,
                  w: FontWeight.w700,
                  c: onSurface.withOpacity(0.38)),
            ),
          ),

          // Card de sección
          Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(_T.r),
            ),
            child: Column(
              children: section.items.asMap().entries.map((e) {
                final isFirst = e.key == 0;
                final isLast = e.key == section.items.length - 1;
                return _ItemRow(
                  item: e.value,
                  isFirst: isFirst,
                  isLast: isLast,
                  onTap: () => onTap(e.value),
                );
              }).toList(),
            ),
          ),

          // Footnote
          if (section.footnote != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 7),
              child: Text(
                section.footnote!,
                style: _T.body(12, c: onSurface.withOpacity(0.38)),
              ),
            ),
        ],
      ),
    )
    .animate()
    .fadeIn(delay: delay, duration: const Duration(milliseconds: 400))
    .slideY(
      begin: 0.04, end: 0,
      delay: delay,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ITEM ROW — fila individual con press state, separador, chevron
// ─────────────────────────────────────────────────────────────────────────────

class _ItemRow extends StatefulWidget {
  final _Item item;
  final bool isFirst, isLast;
  final VoidCallback onTap;

  const _ItemRow({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _pressAnim;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
    );
    _pressAnim = Tween<double>(begin: 1.0, end: 0.97)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    // Radio de esquinas según posición en la lista
    final topLeft    = widget.isFirst ? Radius.circular(_T.r) : Radius.zero;
    final topRight   = widget.isFirst ? Radius.circular(_T.r) : Radius.zero;
    final bottomLeft = widget.isLast  ? Radius.circular(_T.r) : Radius.zero;
    final bottomRight= widget.isLast  ? Radius.circular(_T.r) : Radius.zero;

    return ScaleTransition(
      scale: _pressAnim,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          _press.forward();
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          _press.reverse();
          widget.onTap();
        },
        onTapCancel: () => _press.reverse(),
        child: AnimatedBuilder(
          animation: _press,
          builder: (_, child) {
            // Highlight de press — como iOS
            final pressProgress = _press.value;
            return Container(
              decoration: BoxDecoration(
                color: pressProgress > 0.01
                    ? (isDark
                        ? Colors.white.withOpacity(0.04 * pressProgress)
                        : Colors.black.withOpacity(0.04 * pressProgress))
                    : Colors.transparent,
                borderRadius: BorderRadius.only(
                  topLeft: topLeft, topRight: topRight,
                  bottomLeft: bottomLeft, bottomRight: bottomRight,
                ),
              ),
              child: child,
            );
          },
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    // ── Ícono con fondo coloreado ─────────────────
                    _IconBadge(
                      icon: widget.item.icon,
                      color: widget.item.iconColor,
                    ),
                    const SizedBox(width: 14),

                    // ── Texto ─────────────────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.item.title,
                                style: _T.title(15,
                                    w: FontWeight.w600,
                                    c: onSurface),
                              ),
                              if (widget.item.badge != null) ...[
                                const SizedBox(width: 8),
                                _Badge(label: widget.item.badge!),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.item.subtitle,
                            style: _T.body(12,
                                c: onSurface.withOpacity(0.45)),
                          ),
                        ],
                      ),
                    ),

                    // ── Chevron ───────────────────────────────────
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: onSurface.withOpacity(0.25),
                    ),
                  ],
                ),
              ),

              // Separador — no aparece después del último ítem
              if (!widget.isLast)
                Padding(
                  padding: const EdgeInsets.only(left: 58),
                  child: Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: onSurface.withOpacity(0.08),
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
// ICON BADGE — ícono con fondo coloreado, estilo iOS
// ─────────────────────────────────────────────────────────────────────────────

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(_T.ri),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BADGE — etiqueta "NUEVO" discreta
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  const _Badge({required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: _T.label(9,
            w: FontWeight.w700,
            c: color),
      ),
    );
  }
}

// ── No-op TickerProvider — para controladores estáticos de fallback ───────────
class _NoVsync implements TickerProvider {
  const _NoVsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}