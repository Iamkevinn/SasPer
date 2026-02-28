// lib/screens/goals_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Metas — diseño Apple-first
// Filosofía: una sola superficie, jerarquía tipográfica, microinteracciones
// con haptics. Inspirado en iOS Wallet + Monzo Goals.
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

import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/main.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/screens/add_goal_screen.dart';
import 'package:sasper/screens/edit_goal_screen.dart';
import 'package:sasper/screens/goal_notes_editor_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/goals/contribute_to_goal_dialog.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens de diseño ──────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.5, height: 1.1);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);

  static const h  = 20.0;
  static const r  = 20.0;
  static const ri = 13.0;
}

// ── Sistema de color semántico iOS ────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kOrange = Color(0xFFFF9F0A);
const _kRed    = Color(0xFFFF453A);

Color _priorityColor(GoalPriority p) {
  switch (p) {
    case GoalPriority.low:    return _kGreen;
    case GoalPriority.medium: return _kOrange;
    case GoalPriority.high:   return _kRed;
  }
}

Color _progressColor(double progress) {
  if (progress >= 0.75) return _kGreen;
  if (progress >= 0.40) return _kOrange;
  return _kBlue;
}

String _priorityLabel(GoalPriority p) {
  switch (p) {
    case GoalPriority.low:    return 'Baja';
    case GoalPriority.medium: return 'Media';
    case GoalPriority.high:   return 'Alta';
  }
}

String _timeframeLabel(GoalTimeframe tf) {
  switch (tf) {
    case GoalTimeframe.short:  return 'Corto plazo';
    case GoalTimeframe.medium: return 'Mediano plazo';
    case GoalTimeframe.long:   return 'Largo plazo';
    case GoalTimeframe.custom: return 'Personalizado';
  }
}

final _fmtFull    = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _fmtCompact = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with TickerProviderStateMixin {
  final _repo = GoalRepository.instance;
  late final Stream<List<Goal>> _goalsStream = _repo.getGoalsStream();
  late final TabController _tabController = TabController(length: 2, vsync: this);

  final _activeFilters    = _GoalFilters();
  final _completedFilters = _GoalFilters();
  bool _showFilters = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _repo.refreshData();

  void _goAdd() async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddGoalScreen()),
    );
    if (ok == true) _repo.refreshData();
  }

  void _goEdit(Goal g) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditGoalScreen(goal: g)),
    );
    if (ok == true) _repo.refreshData();
  }

  void _goNotes(Goal g) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => GoalNotesEditorScreen(goal: g)),
  );

  Future<void> _deleteGoal(Goal goal) async {
    final ok = await showModalBottomSheet<bool>(
      context: navigatorKey.currentContext!,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmDeleteSheet(goalName: goal.name),
      ),
    );

    if (ok == true && mounted) {
      try {
        await _repo.deleteGoalSafely(goal.id);
        _repo.refreshData();
        EventService.instance.fire(AppEvent.goalsChanged);
        NotificationHelper.show(
            message: 'Meta eliminada', type: NotificationType.success);
      } catch (e) {
        NotificationHelper.show(
            message: e.toString().replaceFirst('Exception: ', ''),
            type: NotificationType.error);
      }
    }
  }

  List<Goal> _filter(List<Goal> goals, _GoalFilters f) {
    if (!f.hasActiveFilters) return goals;
    return goals.where((g) =>
        (f.timeframe == null || g.timeframe == f.timeframe) &&
        (f.priority  == null || g.priority  == f.priority)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverPersistentHeader(
            pinned: true,
            delegate: _HeaderDelegate(
              statusBarHeight: statusH,
              bg: theme.scaffoldBackgroundColor,
              showFilters: _showFilters,
              tabController: _tabController,
              onFilter: () {
                HapticFeedback.selectionClick();
                setState(() => _showFilters = !_showFilters);
              },
              onAdd: _goAdd,
            ),
          ),
        ],
        body: StreamBuilder<List<Goal>>(
          stream: _goalsStream,
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
              return _SkeletonLoader();
            }
            if (snap.hasError) {
              return _ErrorState(error: snap.error.toString(), onRetry: _refresh);
            }

            final all = snap.data ?? [];
            if (all.isEmpty) return _EmptyState(onAdd: _goAdd);

            final active    = _filter(
                all.where((g) => g.status == GoalStatus.active).toList(),
                _activeFilters);
            final completed = _filter(
                all.where((g) => g.status != GoalStatus.active).toList(),
                _completedFilters);

            return TabBarView(
              controller: _tabController,
              children: [
                _GoalsList(
                  goals: active,
                  isCompleted: false,
                  filters: _activeFilters,
                  showFilters: _showFilters,
                  onRefresh: _refresh,
                  onEdit: _goEdit,
                  onDelete: _deleteGoal,
                  onNotes: _goNotes,
                  onFilterChanged: () => setState(() {}),
                ),
                _GoalsList(
                  goals: completed,
                  isCompleted: true,
                  filters: _completedFilters,
                  showFilters: _showFilters,
                  onRefresh: _refresh,
                  onFilterChanged: () => setState(() {}),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final double statusBarHeight;
  final Color bg;
  final bool showFilters;
  final TabController tabController;
  final VoidCallback onFilter, onAdd;

  const _HeaderDelegate({
    required this.statusBarHeight, required this.bg,
    required this.showFilters, required this.tabController,
    required this.onFilter, required this.onAdd,
  });

  @override double get minExtent => statusBarHeight + 100;
  @override double get maxExtent => statusBarHeight + 158;
  @override bool shouldRebuild(covariant _HeaderDelegate old) => true;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlaps) {
    final t         = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    final onSurface = Theme.of(ctx).colorScheme.onSurface;
    final titleSize = lerpDouble(30, 19, t)!;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg.withOpacity(t > 0.15 ? 0.93 : 0),
          padding: EdgeInsets.only(
            top: statusBarHeight + 10,
            left: _T.h + 4, right: _T.h, bottom: 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedOpacity(
                          opacity: (1 - t * 2.2).clamp(0.0, 1.0),
                          duration: const Duration(milliseconds: 50),
                          child: Text('MIS METAS',
                              style: _T.label(10, w: FontWeight.w700,
                                  c: onSurface.withOpacity(0.35))),
                        ),
                        Text('Objetivos',
                            style: _T.display(titleSize, c: onSurface)),
                      ],
                    ),
                  ),
                  _PillIconButton(
                      icon: showFilters ? Iconsax.filter_remove : Iconsax.filter,
                      onTap: onFilter),
                  const SizedBox(width: 8),
                  _PillButton(label: 'Nueva', icon: Iconsax.add, onTap: onAdd),
                ],
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: tabController,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2,
                indicatorColor: _kBlue,
                dividerColor: Colors.transparent,
                labelStyle: _T.label(14, w: FontWeight.w600),
                unselectedLabelStyle: _T.label(14),
                labelColor: _kBlue,
                unselectedLabelColor: onSurface.withOpacity(0.4),
                tabs: const [Tab(text: 'Activas'), Tab(text: 'Completadas')],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PillIconButton({required this.icon, required this.onTap});
  @override State<_PillIconButton> createState() => _PillIconButtonState();
}
class _PillIconButtonState extends State<_PillIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 75));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.87, _c.value)!,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(widget.icon, size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.65)),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.icon, required this.onTap});
  @override State<_PillButton> createState() => _PillButtonState();
}
class _PillButtonState extends State<_PillButton>
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
              color: _kBlue,
              borderRadius: BorderRadius.circular(20),
            ),
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
// LISTA
// ─────────────────────────────────────────────────────────────────────────────

class _GoalsList extends StatelessWidget {
  final List<Goal> goals;
  final bool isCompleted, showFilters;
  final _GoalFilters filters;
  final Future<void> Function() onRefresh;
  final void Function(Goal)? onEdit, onDelete, onNotes;
  final VoidCallback onFilterChanged;

  const _GoalsList({
    required this.goals, required this.isCompleted, required this.showFilters,
    required this.filters, required this.onRefresh,
    this.onEdit, this.onDelete, this.onNotes, required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kBlue,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          if (showFilters)
            SliverToBoxAdapter(
              child: _FilterPanel(filters: filters, onChanged: onFilterChanged)
                  .animate()
                  .fadeIn(duration: const Duration(milliseconds: 220))
                  .slideY(begin: -0.06, curve: Curves.easeOutCubic),
            ),
          if (!isCompleted && goals.isNotEmpty)
            SliverToBoxAdapter(child: _SummaryBar(goals: goals)),
          if (goals.isEmpty)
            SliverFillRemaining(
              child: _EmptyFilterState(
                filters: filters,
                onClear: () { filters.clear(); onFilterChanged(); },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(_T.h, 4, _T.h, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _GoalCard(
                    goal: goals[i], index: i, isCompleted: isCompleted,
                    onEdit:       onEdit   != null ? () => onEdit!(goals[i])   : null,
                    onDelete:     onDelete != null ? () => onDelete!(goals[i]) : null,
                    onNotes:      onNotes  != null ? () => onNotes!(goals[i])  : null,
                    onContribute: onRefresh,
                  ),
                  childCount: goals.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Goal> goals;
  const _SummaryBar({required this.goals});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04);

    final totalSaved  = goals.fold<double>(0, (s, g) => s + g.currentAmount);
    final avgProgress = goals.fold<double>(0, (s, g) => s + g.progress) / goals.length;
    final nearDone    = goals.where((g) => g.progress >= 0.8).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 8, _T.h, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(_T.r)),
        child: Row(children: [
          Expanded(
            flex: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total ahorrado',
                  style: _T.label(11, c: onSurf.withOpacity(0.42))),
              const SizedBox(height: 3),
              Text(_fmtCompact.format(totalSaved),
                  style: _T.display(22, c: onSurf)),
            ]),
          ),
          Container(width: 0.5, height: 36, color: onSurf.withOpacity(0.10)),
          Expanded(
            flex: 3,
            child: Column(children: [
              Text('Promedio', style: _T.label(11, c: onSurf.withOpacity(0.42))),
              const SizedBox(height: 3),
              Text('${(avgProgress * 100).round()}%', style: _T.mono(20, c: _kGreen)),
            ]),
          ),
          Container(width: 0.5, height: 36, color: onSurf.withOpacity(0.10)),
          Expanded(
            flex: 3,
            child: Column(children: [
              Text('Al 80%+', style: _T.label(11, c: onSurf.withOpacity(0.42))),
              const SizedBox(height: 3),
              Text('$nearDone', style: _T.mono(20, c: _kOrange)),
            ]),
          ),
        ]),
      ),
    )
    .animate()
    .fadeIn(delay: const Duration(milliseconds: 80), duration: const Duration(milliseconds: 350))
    .slideY(begin: 0.04, delay: const Duration(milliseconds: 80),
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GOAL CARD
// ─────────────────────────────────────────────────────────────────────────────

class _GoalCard extends StatefulWidget {
  final Goal goal;
  final int index;
  final bool isCompleted;
  final VoidCallback? onEdit, onDelete, onNotes;
  final Future<void> Function() onContribute;

  const _GoalCard({
    required this.goal, required this.index, required this.isCompleted,
    this.onEdit, this.onDelete, this.onNotes, required this.onContribute,
  });

  @override State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 75));
  @override void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final pColor   = _priorityColor(widget.goal.priority);
    final barColor = _progressColor(widget.goal.progress);
    final pct      = widget.goal.progress.clamp(0.0, 1.0);
    final cardColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.04);
    final delay = Duration(milliseconds: 50 + widget.index * 65);

    return AnimatedBuilder(
      animation: _press,
      builder: (_, child) => Transform.scale(
        scale: lerpDouble(1.0, 0.982, _press.value)!,
        child: child,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press.forward(),
        onTapUp:   (_) => _press.reverse(),
        onTapCancel: () => _press.reverse(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(_T.r),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: widget.isCompleted
                ? _CompletedLayout(goal: widget.goal, pColor: pColor)
                : _ActiveLayout(
                    goal: widget.goal, pColor: pColor,
                    barColor: barColor, pct: pct,
                    onEdit: widget.onEdit, onDelete: widget.onDelete,
                    onNotes: widget.onNotes, onContribute: widget.onContribute,
                  ),
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(delay: delay, duration: const Duration(milliseconds: 320))
    .slideY(begin: 0.05, end: 0, delay: delay,
        duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }
}

// ── Layouts ───────────────────────────────────────────────────────────────────

class _ActiveLayout extends StatelessWidget {
  final Goal goal;
  final Color pColor, barColor;
  final double pct;
  final VoidCallback? onEdit, onDelete, onNotes;
  final Future<void> Function() onContribute;

  const _ActiveLayout({
    required this.goal, required this.pColor, required this.barColor,
    required this.pct, this.onEdit, this.onDelete, this.onNotes,
    required this.onContribute,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf    = Theme.of(context).colorScheme.onSurface;
    final remaining = (goal.targetAmount - goal.currentAmount).clamp(0, double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fila superior
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _GoalIcon(icon: goal.category?.icon ?? Iconsax.flag, color: pColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(goal.name,
                  style: _T.display(16, c: onSurf, w: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                _Tag(label: _priorityLabel(goal.priority), color: pColor),
                const SizedBox(width: 6),
                _Tag(label: _timeframeLabel(goal.timeframe),
                    color: onSurf.withOpacity(0.3)),
              ]),
            ]),
          ),
          if (onEdit != null)
            _MenuDot(onEdit: onEdit!, onNotes: onNotes, onDelete: onDelete!),
        ]),

        const SizedBox(height: 18),

        // Números protagonistas
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ahorrado',
                  style: _T.label(11, c: onSurf.withOpacity(0.42))),
              const SizedBox(height: 2),
              Text(_fmtFull.format(goal.currentAmount),
                  style: _T.display(24, c: onSurf)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('Falta', style: _T.label(11, c: onSurf.withOpacity(0.42))),
            const SizedBox(height: 2),
            Text(_fmtFull.format(remaining),
                style: _T.mono(14, c: onSurf.withOpacity(0.50))),
          ]),
        ]),

        const SizedBox(height: 14),

        // Barra de progreso 4px
        Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Progreso',
                style: _T.label(11, c: onSurf.withOpacity(0.42))),
            Text('${(pct * 100).toStringAsFixed(1)}%',
                style: _T.label(12, w: FontWeight.w700, c: barColor)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(children: [
              Container(height: 4, color: barColor.withOpacity(0.13)),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ]),
          ),
        ]),

        if (goal.targetDate != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Iconsax.calendar_1, size: 11, color: onSurf.withOpacity(0.32)),
            const SizedBox(width: 4),
            Text(DateFormat.yMMMd('es_CO').format(goal.targetDate!),
                style: _T.label(11, c: onSurf.withOpacity(0.36))),
          ]),
        ],

        const SizedBox(height: 14),

        // Acciones
        Row(children: [
          Expanded(
            child: _ActionButton(
              label: 'Aportar', icon: Iconsax.add_circle, color: _kBlue,
              onTap: () {
                HapticFeedback.lightImpact();
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: ContributeToGoalDialog(
                          goal: goal, onSuccess: onContribute),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_fmtCompact.format(goal.targetAmount),
                style: _T.mono(12, c: onSurf.withOpacity(0.45))),
          ),
        ]),
      ],
    );
  }
}

class _CompletedLayout extends StatelessWidget {
  final Goal goal;
  final Color pColor;
  const _CompletedLayout({required this.goal, required this.pColor});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Row(children: [
      _GoalIcon(icon: Iconsax.verify5, color: _kGreen),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(goal.name,
              style: _T.label(15, c: onSurf.withOpacity(0.65), w: FontWeight.w500)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Iconsax.verify5, size: 12, color: _kGreen),
            const SizedBox(width: 4),
            Text('Completada · ${_fmtCompact.format(goal.targetAmount)}',
                style: _T.label(12, c: onSurf.withOpacity(0.42))),
          ]),
        ]),
      ),
    ]);
  }
}

// ── Átomos visuales ───────────────────────────────────────────────────────────

class _GoalIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _GoalIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 42, height: 42,
    decoration: BoxDecoration(
      color: color.withOpacity(0.13),
      borderRadius: BorderRadius.circular(_T.ri),
    ),
    child: Icon(icon, size: 20, color: color),
  );
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label, style: _T.label(10, w: FontWeight.w700, c: color)),
  );
}

class _ActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.icon,
      required this.color, required this.onTap});
  @override State<_ActionButton> createState() => _ActionButtonState();
}
class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 70));
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
          scale: lerpDouble(1.0, 0.96, _c.value)!,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: widget.color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 7),
              Text(widget.label,
                  style: _T.label(14, w: FontWeight.w600, c: widget.color)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MENÚ Y ACTION SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _MenuDot extends StatefulWidget {
  final VoidCallback onEdit, onDelete;
  final VoidCallback? onNotes;
  const _MenuDot({required this.onEdit, required this.onDelete, this.onNotes});
  @override State<_MenuDot> createState() => _MenuDotState();
}
class _MenuDotState extends State<_MenuDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) { _c.reverse(); _openSheet(context); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.85, _c.value)!,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.more_horiz_rounded,
                size: 18, color: onSurf.withOpacity(0.45)),
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _GoalActionSheet(
          onEdit: widget.onEdit, onNotes: widget.onNotes, onDelete: widget.onDelete,
        ),
      ),
    );
  }
}

class _GoalActionSheet extends StatelessWidget {
  final VoidCallback onEdit, onDelete;
  final VoidCallback? onNotes;
  const _GoalActionSheet({required this.onEdit, required this.onDelete, this.onNotes});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final sheetBg  = isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.92);
    final onSurf   = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: sheetBg, borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              _SheetRow(icon: Iconsax.edit, label: 'Editar meta', isFirst: true,
                  onTap: () { Navigator.pop(context); onEdit(); }),
              if (onNotes != null)
                _SheetRow(icon: Iconsax.document_text_1, label: 'Ver notas',
                    onTap: () { Navigator.pop(context); onNotes!(); }),
              _SheetRow(icon: Iconsax.trash, label: 'Eliminar meta', isLast: true,
                  isDestructive: true,
                  onTap: () { Navigator.pop(context); onDelete(); }),
            ]),
          ),
          const SizedBox(height: 10),
          _SheetCancel(),
        ]),
      ),
    );
  }
}

class _SheetRow extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isFirst, isLast, isDestructive;
  final VoidCallback onTap;
  const _SheetRow({required this.icon, required this.label, required this.onTap,
      this.isFirst = false, this.isLast = false, this.isDestructive = false});
  @override State<_SheetRow> createState() => _SheetRowState();
}
class _SheetRowState extends State<_SheetRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final color   = widget.isDestructive ? _kRed : Theme.of(context).colorScheme.onSurface;
    final topR    = widget.isFirst ? const Radius.circular(16) : Radius.zero;
    final bottomR = widget.isLast  ? const Radius.circular(16) : Radius.zero;
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            color: _c.value > 0.01 ? color.withOpacity(0.06 * _c.value) : Colors.transparent,
            borderRadius: BorderRadius.only(
              topLeft: topR, topRight: topR, bottomLeft: bottomR, bottomRight: bottomR,
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
                child: Divider(height: 0.5, thickness: 0.5,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.07)),
              ),
          ]),
        ),
      ),
    );
  }
}

class _SheetCancel extends StatefulWidget {
  @override State<_SheetCancel> createState() => _SheetCancelState();
}
class _SheetCancelState extends State<_SheetCancel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.92);
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
              color: bg, borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text('Cancelar',
                style: _T.label(16, w: FontWeight.w600, c: _kBlue))),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DELETE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDeleteSheet extends StatelessWidget {
  final String goalName;
  const _ConfirmDeleteSheet({required this.goalName});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? Colors.white.withOpacity(0.10) : Colors.white.withOpacity(0.92);
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
              color: sheetBg, borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.12), shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.trash, color: _kRed, size: 26),
              ),
              const SizedBox(height: 14),
              Text('Eliminar meta', style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '¿Eliminar "$goalName"?\nEsta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: _T.label(14, c: onSurf.withOpacity(0.50), w: FontWeight.w400),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _InlineButton(
                  label: 'Cancelar',
                  color: onSurf,
                  onTap: () => Navigator.pop(context, false),
                )),
                const SizedBox(width: 10),
                Expanded(child: _InlineButton(
                  label: 'Eliminar',
                  color: _kRed,
                  onTap: () => Navigator.pop(context, true),
                  useImpact: true,
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _InlineButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool useImpact;
  const _InlineButton({required this.label, required this.color,
      required this.onTap, this.useImpact = false});
  @override State<_InlineButton> createState() => _InlineButtonState();
}
class _InlineButtonState extends State<_InlineButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _c.forward();
        widget.useImpact
            ? HapticFeedback.mediumImpact()
            : HapticFeedback.selectionClick();
      },
      onTapUp:     (_) { _c.reverse(); widget.onTap(); },
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
                style: _T.label(15, w: FontWeight.w600, c: widget.color))),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _FilterPanel extends StatelessWidget {
  final _GoalFilters filters;
  final VoidCallback onChanged;
  const _FilterPanel({required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.04);

    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 8, _T.h, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(_T.r)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Filtros', style: _T.label(14, w: FontWeight.w700, c: onSurf)),
            if (filters.hasActiveFilters)
              GestureDetector(
                onTap: () { HapticFeedback.selectionClick(); filters.clear(); onChanged(); },
                child: Text('Limpiar',
                    style: _T.label(13, w: FontWeight.w600, c: _kBlue)),
              ),
          ]),
          const SizedBox(height: 14),
          Text('Plazo', style: _T.label(11, c: onSurf.withOpacity(0.42))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: GoalTimeframe.values
                .where((tf) => tf != GoalTimeframe.custom)
                .map((tf) => _FilterPill(
                  label: _timeframeLabel(tf),
                  selected: filters.timeframe == tf,
                  onTap: () { filters.timeframe = filters.timeframe == tf ? null : tf; onChanged(); },
                )).toList(),
          ),
          const SizedBox(height: 14),
          Text('Prioridad', style: _T.label(11, c: onSurf.withOpacity(0.42))),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: GoalPriority.values.map((p) => _FilterPill(
              label: _priorityLabel(p),
              selected: filters.priority == p,
              activeColor: filters.priority == p ? _priorityColor(p) : null,
              onTap: () { filters.priority = filters.priority == p ? null : p; onChanged(); },
            )).toList(),
          ),
        ]),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? activeColor;
  final VoidCallback onTap;
  const _FilterPill({required this.label, required this.selected,
      required this.onTap, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final color  = activeColor ?? _kBlue;
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : onSurf.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color.withOpacity(0.35) : Colors.transparent,
          ),
        ),
        child: Text(label,
            style: _T.label(12,
                w: selected ? FontWeight.w600 : FontWeight.w400,
                c: selected ? color : onSurf.withOpacity(0.55))),
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
          Lottie.asset('assets/animations/trophy_animation.json',
              width: 200, height: 200),
          const SizedBox(height: 20),
          Text('Tu primer objetivo', style: _T.display(24, c: onSurf)),
          const SizedBox(height: 10),
          Text(
            'Crea una meta y empieza a ahorrar\npara lo que realmente importa.',
            textAlign: TextAlign.center,
            style: _T.label(15, c: onSurf.withOpacity(0.48), w: FontWeight.w400),
          ),
          const SizedBox(height: 28),
          _PillButton(label: 'Crear primera meta', icon: Iconsax.add_circle, onTap: onAdd),
        ]),
      ),
    )
    .animate()
    .fadeIn(duration: const Duration(milliseconds: 450))
    .scale(begin: const Offset(0.96, 0.96), delay: const Duration(milliseconds: 80),
        duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }
}

class _EmptyFilterState extends StatelessWidget {
  final _GoalFilters filters;
  final VoidCallback onClear;
  const _EmptyFilterState({required this.filters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Iconsax.search_status, size: 52, color: onSurf.withOpacity(0.18)),
          const SizedBox(height: 16),
          Text('Sin resultados', style: _T.display(20, c: onSurf)),
          const SizedBox(height: 8),
          Text(
            'Ninguna meta coincide\ncon los filtros activos.',
            textAlign: TextAlign.center,
            style: _T.label(14, c: onSurf.withOpacity(0.42), w: FontWeight.w400),
          ),
          if (filters.hasActiveFilters) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onClear,
              child: Text('Limpiar filtros',
                  style: _T.label(14, w: FontWeight.w600, c: _kBlue)),
            ),
          ],
        ]),
      ),
    );
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
              style: _T.label(13, c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.11),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text('Reintentar',
                  style: _T.label(14, w: FontWeight.w600, c: _kBlue)),
            ),
          ),
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
        itemCount: 3,
        itemBuilder: (_, __) => Container(
          height: 185,
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

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS PÚBLICOS
// ─────────────────────────────────────────────────────────────────────────────

class _GoalFilters {
  GoalTimeframe? timeframe;
  GoalPriority?  priority;
  bool get hasActiveFilters => timeframe != null || priority != null;
  void clear() { timeframe = null; priority = null; }
}

class GoalHelpers {
  static String getPriorityText(GoalPriority p)     => _priorityLabel(p);
  static String getTimeframeText(GoalTimeframe tf)   => _timeframeLabel(tf);
  static Color  getPriorityColor(BuildContext _, GoalPriority p) => _priorityColor(p);
  static IconData getPriorityIcon(GoalPriority p) {
    switch (p) {
      case GoalPriority.low:    return Iconsax.arrow_down;
      case GoalPriority.medium: return Iconsax.minus;
      case GoalPriority.high:   return Iconsax.arrow_up_3;
    }
  }
}