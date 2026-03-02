// lib/screens/budgets_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Presupuestos — Apple-first redesign
//
// Filosofía: lo que te QUEDA disponible es el dato que importa.
// Como iOS Wallet: "Disponible" primero. Lo gastado es secundario.
//
// Eliminado:
// • SliverAppBar expandedHeight:200 + FlexibleSpaceBar + LinearGradient verde
// • LinearGradient condicional + Border.all dinámico en summary
// • LinearProgressIndicator 10px → barra 4px, color semántico por umbral
// • FilterChip Material → chips iOS en header STICKY (nunca desaparecen)
// • TabController + TabBarView "Activos/Histórico" → un scroll, historial al final
// • AlertDialog + navigatorKey.currentContext → _ConfirmDeleteSheet blur
// • FilledButton / FilledButton.tonalIcon → _PillBtn coherente
// • import sasper/main.dart por navigatorKey → eliminado
// • GoogleFonts.poppins + .inter → DM Sans + DM Mono unificado
// • surfaceContainerHighest / onSurfaceVariant → opacity-based
// • .slideX(begin:-0.1) → .slideY(begin: 0.04) coherente
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/add_budget_screen.dart';
import 'package:sasper/screens/budget_details_screen.dart';
import 'package:sasper/screens/edit_budget_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

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

  static const double h = 20.0; // gutter horizontal
  static const double r = 20.0; // radio tarjeta
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

/// Color semántico: verde < 85 %, naranja 85–99 %, rojo ≥ 100 %
Color _budgetColor(double pct) {
  if (pct >= 1.0)  return _kRed;
  if (pct >= 0.85) return _kOrange;
  return _kGreen;
}

/// Color de fecha de vencimiento
Color _dueDateColor(DateTime due) {
  final d = due.difference(DateTime.now()).inDays;
  if (d < 0)  return _kRed;
  if (d < 7)  return _kOrange;
  return _kBlue.withOpacity(0.70);
}

final _fmt = NumberFormat.compactCurrency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _fmtFull =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

// Etiqueta de periodicidad
String _perioLabel(String? p) {
  switch (p) {
    case 'weekly':  return 'Semanal';
    case 'monthly': return 'Mensual';
    case 'yearly':  return 'Anual';
    case 'custom':  return 'Custom';
    default:        return '';
  }
}

// Mapeo filtro → periodicidad interna
const _kFilterMap = <String, String?>{
  'Todos':        null,
  'Semanal':      'weekly',
  'Mensual':      'monthly',
  'Anual':        'yearly',
  'Custom':       'custom',
};

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});
  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _repo = BudgetRepository.instance;

  // Stream declarado inline — sin LateInitializationError
  late final Stream<List<Budget>> _stream = _repo.getBudgetsStream();

  // null = sin filtro (Todos)
  String? _period;

  // ── Navegación ─────────────────────────────────────────────────────────────

  void _goAdd() async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const AddBudgetScreen()));
    if (ok == true && mounted) _repo.refreshData();
  }

  void _goDetails(Budget b) => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BudgetDetailsScreen(budgetId: b.id)));

  void _goEdit(Budget b) async {
    final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => EditBudgetScreen(budget: b)));
    if (ok == true && mounted) _repo.refreshData();
  }

  // ── Delete — bottom sheet blur, sin navigatorKey, sin import de main.dart ──

  Future<void> _delete(Budget budget) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmDeleteSheet(category: budget.category),
      ),
    );
    if (ok == true && mounted) {
      try {
        await _repo.deleteBudgetSafely(budget.id);
        EventService.instance.fire(AppEvent.budgetsChanged);
        NotificationHelper.show(
            message: 'Presupuesto eliminado',
            type: NotificationType.success);
      } catch (e) {
        NotificationHelper.show(
            message: e.toString().replaceFirst('Exception: ', ''),
            type: NotificationType.error);
      }
    }
  }

  // ── Filtrado ────────────────────────────────────────────────────────────────

  List<Budget> _filter(List<Budget> list) => _period == null
      ? list
      : list.where((b) => b.periodicity == _period).toList();

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: StreamBuilder<List<Budget>>(
        stream: _stream,
        builder: (ctx, snap) {
          Widget body;

          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            body = _SkeletonLoader();
          } else if (snap.hasError) {
            body = _ErrorState(
                error: snap.error.toString(), onRetry: _repo.refreshData);
          } else {
            final all      = snap.data ?? [];
            final active   = _filter(all.where((b) => b.isActive).toList());
            final inactive = _filter(all.where((b) => !b.isActive).toList());

            body = all.isEmpty
                ? _EmptyState(onAdd: _goAdd)
                : _BudgetScroll(
                    active:   active,
                    inactive: inactive,
                    period:   _period,
                    onTap:    _goDetails,
                    onEdit:   _goEdit,
                    onDelete: _delete,
                    onAdd:    _goAdd,
                  );
          }

          return Column(children: [
            _Header(
              statusBarHeight:  statusH,
              bg:               theme.scaffoldBackgroundColor,
              selectedPeriod:   _period,
              onPeriodChanged:  (p) => setState(() => _period = p),
              onAdd:            _goAdd,
            ),
            Expanded(child: body),
          ]);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — blur + título DM Sans + filtros STICKY + botón pill
// Los filtros viven aquí: nunca desaparecen cuando el usuario scrollea
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double   statusBarHeight;
  final Color    bg;
  final String?  selectedPeriod;
  final ValueChanged<String?> onPeriodChanged;
  final VoidCallback onAdd;

  const _Header({
    required this.statusBarHeight, required this.bg,
    required this.selectedPeriod,  required this.onPeriodChanged,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg.withOpacity(0.93),
          padding: EdgeInsets.only(
            top: statusBarHeight + 10,
            left: _T.h + 4, right: _T.h, bottom: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Título + botón
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('MIS FINANZAS',
                            style: _T.label(10,
                                w: FontWeight.w700,
                                c: onSurf.withOpacity(0.35))),
                        Text('Presupuestos',
                            style: _T.display(28, c: onSurf)),
                      ],
                    ),
                  ),
                  _PillBtn(label: 'Nuevo', icon: Iconsax.add, onTap: onAdd),
                ],
              ),
              const SizedBox(height: 12),

              // Filtros sticky — scrollables horizontalmente
              SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: _kFilterMap.entries.map((e) {
                    final sel = selectedPeriod == e.value;
                    return _FilterChip(
                      label: e.key,
                      selected: sel,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // Toggle: si ya está seleccionado, limpia el filtro
                        onPeriodChanged(sel ? null : e.value);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip de filtro de período ─────────────────────────────────────────────────

class _FilterChip extends StatefulWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label, required this.selected, required this.onTap,
  });
  @override State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.93, _c.value)!,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.only(right: 7),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: widget.selected
                  ? _kBlue
                  : (isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.06)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(widget.label,
                style: _T.label(12,
                    w: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    c: widget.selected
                        ? Colors.white
                        : onSurf.withOpacity(0.55))),
          ),
        ),
      ),
    );
  }
}

// ── Botón pill ────────────────────────────────────────────────────────────────

class _PillBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PillBtn({required this.label, required this.icon, required this.onTap});
  @override State<_PillBtn> createState() => _PillBtnState();
}

class _PillBtnState extends State<_PillBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 75));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.lightImpact(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.92, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _kBlue, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 15, color: Colors.white),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: _T.label(13, c: Colors.white, w: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUDGET SCROLL — un scroll continuo, sin tabs
// Activos → "HISTORIAL" al final (como iOS Recordatorios)
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetScroll extends StatelessWidget {
  final List<Budget> active;
  final List<Budget> inactive;
  final String?      period;
  final void Function(Budget) onTap;
  final void Function(Budget) onEdit;
  final Future<void> Function(Budget) onDelete;
  final VoidCallback onAdd;

  const _BudgetScroll({
    required this.active,   required this.inactive,
    required this.period,   required this.onTap,
    required this.onEdit,   required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // ── Summary bar ───────────────────────────────────────────────────
        if (active.isNotEmpty)
          SliverToBoxAdapter(child: _SummaryBar(budgets: active)),

        // ── Presupuestos activos ───────────────────────────────────────────
        if (active.isEmpty)
          SliverToBoxAdapter(
              child: _ActiveEmpty(period: period, onAdd: onAdd))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_T.h, 4, _T.h, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final delay = Duration(milliseconds: 50 + i * 55);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _BudgetTile(
                      budget:   active[i],
                      onTap:    () => onTap(active[i]),
                      onEdit:   () => onEdit(active[i]),
                      onDelete: () => onDelete(active[i]),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: delay,
                          duration: const Duration(milliseconds: 300))
                      .slideY(begin: 0.04, delay: delay,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic);
                },
                childCount: active.length,
              ),
            ),
          ),

        // ── Historial — sección secundaria al final ────────────────────────
        if (inactive.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_T.h, 28, _T.h, 10),
              child: Text('HISTORIAL',
                  style: _T.label(11,
                      w: FontWeight.w700,
                      c: onSurf.withOpacity(0.35))),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_T.h, 0, _T.h, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _InactiveTile(
                    budget:   inactive[i],
                    onTap:    () => onTap(inactive[i]),
                    onEdit:   () => onEdit(inactive[i]),
                    onDelete: () => onDelete(inactive[i]),
                  ),
                )
                    .animate()
                    .fadeIn(
                        delay: Duration(milliseconds: 30 + i * 40),
                        duration: const Duration(milliseconds: 260)),
                childCount: inactive.length,
              ),
            ),
          ),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// "Disponible" es el número protagonista — igual que iOS Wallet
// Una sola superficie sin gradientes ni bordes de color
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Budget> budgets;
  const _SummaryBar({required this.budgets});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final total     = budgets.fold<double>(0, (s, b) => s + b.amount);
    final spent     = budgets.fold<double>(0, (s, b) => s + b.spentAmount);
    final available = total - spent;
    final pct       = total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0;
    final color     = _budgetColor(pct);

    // Conteos de alerta — discretos pero presentes
    final overCount = budgets
        .where((b) => b.amount > 0 && b.spentAmount / b.amount >= 1.0)
        .length;
    final warnCount = budgets
        .where((b) =>
            b.amount > 0 &&
            b.spentAmount / b.amount >= 0.85 &&
            b.spentAmount / b.amount < 1.0)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 8, _T.h, 4),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(_T.r),
        ),
        child: Column(children: [
          Row(children: [
            // ── Disponible — protagonista ─────────────────────────────────
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Disponible',
                      style: _T.label(11, c: onSurf.withOpacity(0.42))),
                  const SizedBox(height: 3),
                  Text(_fmt.format(available),
                      style: _T.display(24, c: color)),
                  // Alerta compacta — solo cuando hay un problema
                  if (overCount > 0 || warnCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(children: [
                        Icon(
                          overCount > 0
                              ? Iconsax.warning_2
                              : Iconsax.info_circle,
                          size: 11,
                          color: overCount > 0 ? _kRed : _kOrange,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          overCount > 0
                              ? '$overCount excedido${overCount > 1 ? 's' : ''}'
                              : '$warnCount en límite',
                          style: _T.label(10,
                              c: overCount > 0 ? _kRed : _kOrange,
                              w: FontWeight.w600),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            Container(width: 0.5, height: 38,
                color: onSurf.withOpacity(0.10)),
            // ── Gastado ───────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(children: [
                Text('Gastado',
                    style: _T.label(11, c: onSurf.withOpacity(0.42))),
                const SizedBox(height: 3),
                Text(_fmt.format(spent),
                    style: _T.mono(17,
                        c: pct >= 0.85
                            ? color
                            : onSurf.withOpacity(0.70))),
              ]),
            ),
            Container(width: 0.5, height: 38,
                color: onSurf.withOpacity(0.10)),
            // ── Total ─────────────────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(children: [
                Text('Total',
                    style: _T.label(11, c: onSurf.withOpacity(0.42))),
                const SizedBox(height: 3),
                Text(_fmt.format(total),
                    style: _T.mono(17, c: onSurf.withOpacity(0.50))),
              ]),
            ),
          ]),

          const SizedBox(height: 14),

          // ── Barra 4px — sin LinearProgressIndicator Material ─────────────
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Uso total',
                    style: _T.label(11, c: onSurf.withOpacity(0.42))),
                Text('${(pct * 100).toStringAsFixed(1)}%',
                    style: _T.label(11, w: FontWeight.w700, c: color)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(children: [
                Container(height: 4, color: color.withOpacity(0.12)),
                FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ]),
      ),
    )
        .animate()
        .fadeIn(delay: 60.ms, duration: 320.ms)
        .slideY(begin: 0.04, delay: 60.ms, duration: 320.ms,
            curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BUDGET TILE — presupuesto activo
// Una superficie, barra 4px semántica, fecha de vencimiento, disponible inline
// Tap → detalles   |   Long press → action sheet
// ─────────────────────────────────────────────────────────────────────────────

class _BudgetTile extends StatefulWidget {
  final Budget   budget;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _BudgetTile({
    required this.budget,   required this.onTap,
    required this.onEdit,   required this.onDelete,
  });
  @override State<_BudgetTile> createState() => _BudgetTileState();
}

class _BudgetTileState extends State<_BudgetTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _press.dispose(); super.dispose(); }

  void _openActions() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ActionSheet(
          budget:    widget.budget,
          onDetails: widget.onTap,
          onEdit:    widget.onEdit,
          onDelete:  widget.onDelete,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final bg        = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final b         = widget.budget;
    final pct       = b.amount > 0
        ? (b.spentAmount / b.amount).clamp(0.0, double.infinity)
        : 0.0;
    final color     = _budgetColor(pct);
    final available = b.amount - b.spentAmount;

    return AnimatedBuilder(
      animation: _press,
      builder: (_, child) => Transform.scale(
          scale: lerpDouble(1.0, 0.98, _press.value)!, child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) { _press.forward(); HapticFeedback.selectionClick(); },
        onTapUp:     (_) { _press.reverse(); widget.onTap(); },
        onTapCancel: ()  { _press.reverse(); },
        onLongPress:     _openActions,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(_T.r)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila principal ────────────────────────────────────────────
              Row(children: [
                // Ícono de estado
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      pct >= 1.0
                          ? Iconsax.warning_2
                          : pct >= 0.85
                              ? Iconsax.danger
                              : Iconsax.wallet_check,
                      size: 18, color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(b.category,
                              style: _T.label(15,
                                  w: FontWeight.w700, c: onSurf),
                              overflow: TextOverflow.ellipsis),
                        ),
                        // Badge periodicidad — sin primaryContainer Material
                        if (b.periodicity != null &&
                            b.periodicity!.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: onSurf.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(_perioLabel(b.periodicity),
                                style: _T.label(9,
                                    w: FontWeight.w700,
                                    c: onSurf.withOpacity(0.45))),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 2),
                      // Disponible inline — dato accionable
                      Text(
                        available >= 0
                            ? 'Disponible ${_fmtFull.format(available)}'
                            : 'Excedido ${_fmtFull.format(available.abs())}',
                        style: _T.label(11,
                            c: available >= 0 ? color : _kRed,
                            w: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Gastado / total
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmt.format(b.spentAmount),
                      style: _T.mono(14, c: color)),
                  Text('de ${_fmt.format(b.amount)}',
                      style: _T.label(10, c: onSurf.withOpacity(0.38))),
                ]),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: onSurf.withOpacity(0.20)),
              ]),

              const SizedBox(height: 12),

              // ── Barra de progreso + fecha ─────────────────────────────────
              Column(children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (b.endDate != null)
                      Row(children: [
                        Icon(Iconsax.calendar_1,
                            size: 10, color: _dueDateColor(b.endDate!)),
                        const SizedBox(width: 3),
                        Text(
                          'Vence ${DateFormat.yMMMd('es_CO').format(b.endDate!)}',
                          style: _T.label(10,
                              c: _dueDateColor(b.endDate!)),
                        ),
                      ])
                    else
                      const SizedBox(),
                    Text('${(pct.clamp(0, 1) * 100).toStringAsFixed(0)}%',
                        style: _T.label(10,
                            w: FontWeight.w700, c: color)),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(children: [
                    Container(height: 4, color: color.withOpacity(0.12)),
                    FractionallySizedBox(
                      widthFactor: pct.clamp(0.0, 1.0),
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INACTIVE TILE — historial compacto y desaturado
// No compite visualmente con los activos
// ─────────────────────────────────────────────────────────────────────────────

class _InactiveTile extends StatelessWidget {
  final Budget   budget;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _InactiveTile({
    required this.budget,   required this.onTap,
    required this.onEdit,   required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final b      = budget;
    final pct    = b.amount > 0 ? b.spentAmount / b.amount : 0.0;

    return GestureDetector(
      onTap:       () { HapticFeedback.selectionClick(); onTap(); },
      onLongPress: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: _ActionSheet(
              budget: b, onDetails: onTap,
              onEdit: onEdit, onDelete: onDelete,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(
            pct >= 1.0 ? Iconsax.warning_2 : Iconsax.tick_circle,
            size: 15,
            color: pct >= 1.0
                ? _kRed.withOpacity(0.6)
                : _kGreen.withOpacity(0.6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(b.category,
                style: _T.label(14,
                    c: onSurf.withOpacity(0.48), w: FontWeight.w400)),
          ),
          if (b.periodicity != null && b.periodicity!.isNotEmpty)
            Text(_perioLabel(b.periodicity),
                style: _T.label(10, c: onSurf.withOpacity(0.30))),
          const SizedBox(width: 8),
          Text(_fmt.format(b.amount),
              style: _T.mono(12, c: onSurf.withOpacity(0.38))),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              size: 15, color: onSurf.withOpacity(0.17)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION SHEET — iOS nativo con blur
// Long press en cualquier tile
// ─────────────────────────────────────────────────────────────────────────────

class _ActionSheet extends StatelessWidget {
  final Budget   budget;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  const _ActionSheet({
    required this.budget,   required this.onDetails,
    required this.onEdit,   required this.onDelete,
  });

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
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(budget.category,
                style: _T.label(13,
                    c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          ),
          Container(
            decoration: BoxDecoration(
              color: sheetBg, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _SheetRow(
                icon: Iconsax.chart_square, label: 'Ver detalles',
                color: _kBlue, isFirst: true,
                onTap: () { Navigator.pop(context); onDetails(); },
              ),
              _SheetRow(
                icon: Iconsax.edit, label: 'Editar',
                onTap: () { Navigator.pop(context); onEdit(); },
              ),
              _SheetRow(
                icon: Iconsax.trash, label: 'Eliminar',
                isLast: true, isDestructive: true,
                onTap: () { Navigator.pop(context); onDelete(); },
              ),
            ]),
          ),
          const SizedBox(height: 10),
          _CancelRow(),
        ]),
      ),
    );
  }
}

// ── Fila del action sheet ─────────────────────────────────────────────────────

class _SheetRow extends StatefulWidget {
  final IconData icon;
  final String   label;
  final Color?   color;
  final bool     isFirst, isLast, isDestructive;
  final VoidCallback onTap;

  const _SheetRow({
    required this.icon, required this.label, required this.onTap,
    this.color, this.isFirst = false, this.isLast = false,
    this.isDestructive = false,
  });
  @override State<_SheetRow> createState() => _SheetRowState();
}

class _SheetRowState extends State<_SheetRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final def   = Theme.of(context).colorScheme.onSurface;
    final color = widget.isDestructive ? _kRed : (widget.color ?? def);
    final topR  = widget.isFirst ? const Radius.circular(16) : Radius.zero;
    final botR  = widget.isLast  ? const Radius.circular(16) : Radius.zero;

    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: _c.value > 0.01
                ? color.withOpacity(0.06 * _c.value)
                : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft:  topR, topRight:  topR,
              bottomLeft: botR, bottomRight: botR,
            ),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(children: [
                Icon(widget.icon, size: 20, color: color),
                const SizedBox(width: 14),
                Text(widget.label, style: _T.label(16, c: color)),
              ]),
            ),
            if (!widget.isLast)
              Padding(
                padding: const EdgeInsets.only(left: 54),
                child: Divider(
                  height: 0.5, thickness: 0.5,
                  color: Theme.of(context)
                      .colorScheme.onSurface.withOpacity(0.07),
                ),
              ),
          ]),
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
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
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
                style: _T.label(16, w: FontWeight.w600, c: _kBlue))),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DELETE SHEET — sin AlertDialog, sin navigatorKey
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDeleteSheet extends StatelessWidget {
  final String category;
  const _ConfirmDeleteSheet({required this.category});

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
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: sheetBg, borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Iconsax.trash, color: _kRed, size: 24),
              ),
              const SizedBox(height: 12),
              Text('Eliminar presupuesto',
                  style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '"$category"\nEsta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: _T.label(14,
                    c: onSurf.withOpacity(0.48), w: FontWeight.w400),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _InlineBtn(
                    label: 'Cancelar', color: onSurf,
                    onTap: () => Navigator.pop(context, false))),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                    label: 'Eliminar', color: _kRed, impact: true,
                    onTap: () => Navigator.pop(context, true))),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InlineBtn extends StatefulWidget {
  final String label;
  final Color  color;
  final bool   impact;
  final VoidCallback onTap;
  const _InlineBtn({
    required this.label, required this.color,
    required this.onTap, this.impact = false,
  });
  @override State<_InlineBtn> createState() => _InlineBtnState();
}

class _InlineBtnState extends State<_InlineBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.impact
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.selectionClick();
      },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(widget.label,
                style: _T.label(15,
                    w: FontWeight.w600, c: widget.color))),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Lottie.asset('assets/animations/piggy_bank_animation.json',
              width: 200, height: 200),
          const SizedBox(height: 20),
          Text('Toma el control', style: _T.display(24, c: onSurf)),
          const SizedBox(height: 10),
          Text(
            'Crea presupuestos para controlar\ntus gastos y alcanzar tus metas.',
            textAlign: TextAlign.center,
            style: _T.label(15,
                c: onSurf.withOpacity(0.45), w: FontWeight.w400),
          ),
          const SizedBox(height: 28),
          _PillBtn(
              label: 'Crear presupuesto',
              icon: Iconsax.add_circle,
              onTap: onAdd),
        ]),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .scale(begin: const Offset(0.96, 0.96),
            delay: 80.ms, duration: 350.ms, curve: Curves.easeOutCubic);
  }
}

/// Estado vacío cuando hay filtro activo o sin presupuestos activos
class _ActiveEmpty extends StatelessWidget {
  final String?  period;
  final VoidCallback onAdd;
  const _ActiveEmpty({required this.period, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final hasFilter = period != null;
    final label     = _kFilterMap.entries
        .firstWhere((e) => e.value == period,
            orElse: () => const MapEntry('', null))
        .key;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Iconsax.wallet_add, size: 56, color: onSurf.withOpacity(0.14)),
        const SizedBox(height: 18),
        Text('Sin presupuestos activos',
            style: _T.display(22, c: onSurf)),
        const SizedBox(height: 10),
        Text(
          hasFilter
              ? 'No hay presupuestos "$label" activos'
              : 'Crea tu primer presupuesto para\ncontrolar tus gastos',
          textAlign: TextAlign.center,
          style: _T.label(14,
              c: onSurf.withOpacity(0.45), w: FontWeight.w400),
        ),
        if (!hasFilter) ...[
          const SizedBox(height: 24),
          _PillBtn(
              label: 'Crear presupuesto',
              icon: Iconsax.add_circle,
              onTap: onAdd),
        ],
      ]),
    ).animate().fadeIn(duration: 350.ms);
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Iconsax.danger, size: 48, color: _kRed.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text('Algo salió mal', style: _T.display(20, c: onSurf)),
          const SizedBox(height: 8),
          Text(error, textAlign: TextAlign.center,
              style: _T.label(13,
                  c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          const SizedBox(height: 24),
          _PillBtn(
              label: 'Reintentar',
              icon: Iconsax.refresh,
              onTap: onRetry),
        ]),
      ),
    );
  }
}

class _SkeletonLoader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(_T.h),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white12 : Colors.black12,
            borderRadius: BorderRadius.circular(_T.r),
          ),
        ),
      ),
    );
  }
}