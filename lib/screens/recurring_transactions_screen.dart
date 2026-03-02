// lib/screens/recurring_transactions_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO — Apple iOS                                            │
// │  • Respeta el tema del sistema: oscuro / claro / automático.               │
// │  • Colores semánticos vivos con opacidad adaptable al fondo.               │
// │  • Jerarquía clara: tarjeta, monto, badge de estado, acciones.             │
// │  • Micro-feedback háptico en cada interacción con propósito.               │
// │  • Resumen mensual con métricas de impacto real.                           │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/screens/add_recurring_transaction_screen.dart';
import 'package:sasper/screens/edit_recurring_transaction_screen.dart';
import 'package:sasper/screens/pending_payments_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/main.dart';
import 'dart:developer' as developer;

// ─── TOKENS DINÁMICOS ────────────────────────────────────────────────────────
// Resueltos en tiempo de ejecución según el tema activo del sistema.
// Nunca colores de superficie hardcodeados — siempre relativos al tema.
class _C {
  final BuildContext _ctx;
  _C(this._ctx);

  bool get isDark => Theme.of(_ctx).brightness == Brightness.dark;

  // Superficies — escala iOS systemGroupedBackground
  Color get bg =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get surfaceRaised =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get separator =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  // Texto — escala iOS label
  Color get label =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get label2 =>
      isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get label3 =>
      isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get label4 =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  // Semánticos — vivos y con propósito, no apagados
  static const Color expense = Color(0xFFFF3B30); // iOS Red
  static const Color income  = Color(0xFF30D158); // iOS Green
  static const Color warning = Color(0xFFFF9F0A); // iOS Orange
  static const Color accent  = Color(0xFF0A84FF); // iOS Blue

  Color get expenseBg => expense.withOpacity(isDark ? 0.18 : 0.09);
  Color get incomeBg  => income.withOpacity(isDark ? 0.18 : 0.09);
  Color get warningBg => warning.withOpacity(isDark ? 0.18 : 0.10);
  Color get accentBg  => accent.withOpacity(isDark ? 0.18 : 0.09);

  // Espaciado
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;

  // Radios
  static const double rSM = 8.0;
  static const double rMD = 12.0;
  static const double rLG = 16.0;
  static const double rXL = 22.0;

  // Animaciones
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration mid    = Duration(milliseconds: 280);
  static const Duration slow   = Duration(milliseconds: 440);
  static const Curve curveOut  = Curves.easeOutCubic;
}

// ─── PANTALLA PRINCIPAL ──────────────────────────────────────────────────────
class RecurringTransactionsScreen extends StatefulWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen>
    with TickerProviderStateMixin {
  final RecurringRepository _repository = RecurringRepository.instance;
  late final Stream<List<RecurringTransaction>> _stream;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _stream = _repository.getRecurringTransactionsStream();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToEdit(RecurringTransaction t) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<bool>(
      _iosRoute(EditRecurringTransactionScreen(transaction: t)),
    );
    if (result == true) _repository.refreshData();
  }

  void _navigateToAdd() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<bool>(
      _iosRoute(const AddRecurringTransactionScreen()),
    );
    if (result == true) _repository.refreshData();
  }

  Future<void> _handleDelete(RecurringTransaction item) async {
    HapticFeedback.mediumImpact();
    final c = _C(context);
    final confirmed = await _showDeleteDialog(item, c);
    if (confirmed != true || !mounted) return;
    try {
      await _repository.deleteRecurringTransaction(item.id);
      await NotificationService.instance.cancelRecurringReminders(item.id);
      _repository.refreshData();
      HapticFeedback.heavyImpact();
      NotificationHelper.show(message: 'Eliminado', type: NotificationType.success);
    } catch (_) {
      HapticFeedback.mediumImpact();
      NotificationHelper.show(message: 'Error al eliminar', type: NotificationType.error);
    }
  }

  PageRouteBuilder<bool> _iosRoute(Widget page) => PageRouteBuilder<bool>(
        pageBuilder: (_, a, __) => page,
        transitionDuration: _C.slow,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: _C.curveOut)),
          child: child,
        ),
      );

  Future<bool?> _showDeleteDialog(RecurringTransaction item, _C c) {
    return showDialog<bool>(
      context: navigatorKey.currentContext!,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(_C.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(_C.rXL),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(c.isDark ? 0.4 : 0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                      color: c.expenseBg,
                      borderRadius: BorderRadius.circular(_C.rMD)),
                  child: const Icon(Iconsax.trash, color: _C.expense, size: 22),
                ),
                const SizedBox(height: _C.md),
                Text('Eliminar gasto fijo',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: c.label, letterSpacing: -0.3)),
                const SizedBox(height: _C.sm),
                Text(
                  '¿Eliminar "${item.description}"? Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 15, color: c.label3, height: 1.45),
                ),
                const SizedBox(height: _C.lg),
                Row(
                  children: [
                    Expanded(
                        child: _OutlineBtn(
                            label: 'Cancelar', c: c,
                            onTap: () => Navigator.pop(ctx, false))),
                    const SizedBox(width: _C.sm),
                    Expanded(
                        child: _FilledBtn(
                            label: 'Eliminar',
                            color: _C.expense,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(ctx, true);
                            })),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _C(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            c.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) =>
              [_buildAppBar(c, innerBoxIsScrolled)],
          body: StreamBuilder<List<RecurringTransaction>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _SkeletonLoader(c: c);
              }
              if (snapshot.hasError) {
                return _ErrorState(
                    error: '${snapshot.error}', c: c,
                    onRetry: _repository.refreshData);
              }
              final items = snapshot.data ?? [];
              if (items.isEmpty) {
                return _EmptyState(c: c, onAdd: _navigateToAdd);
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _RecurringList(
                    key: const ValueKey('expenses'),
                    items: items.where((i) => i.type == 'Gasto').toList(),
                    isExpense: true, c: c,
                    repository: _repository,
                    onEdit: _navigateToEdit,
                    onDelete: _handleDelete,
                    onAdd: _navigateToAdd,
                    onRefresh: _repository.refreshData,
                  ),
                  _RecurringList(
                    key: const ValueKey('incomes'),
                    items: items.where((i) => i.type == 'Ingreso').toList(),
                    isExpense: false, c: c,
                    repository: _repository,
                    onEdit: _navigateToEdit,
                    onDelete: _handleDelete,
                    onAdd: _navigateToAdd,
                    onRefresh: _repository.refreshData,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────
  // El título expandido (grande) solo vive en el FlexibleSpaceBar.
  // Al hacer scroll, colapsa y aparece el título compacto en el AppBar.
  // NUNCA se muestran los dos al mismo tiempo.
  Widget _buildAppBar(_C c, bool innerBoxIsScrolled) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,

      // Título compacto — visible solo al hacer scroll
      title: AnimatedOpacity(
        opacity: innerBoxIsScrolled ? 1.0 : 0.0,
        duration: _C.mid,
        child: Text(
          'Recurrentes',
          style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w600,
            color: c.label, letterSpacing: -0.2,
          ),
        ),
      ),

      // Botón añadir — siempre visible
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: _C.md, top: 6, bottom: 6),
          child: GestureDetector(
            onTap: _navigateToAdd,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                  color: _C.accent,
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 4),
                  Text('Nuevo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],

      // Título expandido — oculto cuando el AppBar está colapsado
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, 52),
        title: AnimatedOpacity(
          opacity: innerBoxIsScrolled ? 0.0 : 1.0,
          duration: _C.mid,
          child: Align(
            alignment: Alignment.bottomLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMPROMISOS',
                  style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.3, color: _C.accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Recurrentes',
                  style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w800,
                    color: c.label, letterSpacing: -0.8, height: 1.05,
                  ),
                ),
              ],
            ),
          ),
        ),
        background: Container(color: c.bg),
      ),

      // Tab bar adaptado al tema
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, _C.sm),
          child: _PremiumTabBar(controller: _tabController, c: c),
        ),
      ),
    );
  }
}

// ─── TAB BAR PREMIUM ─────────────────────────────────────────────────────────
class _PremiumTabBar extends StatelessWidget {
  final TabController controller;
  final _C c;
  const _PremiumTabBar({required this.controller, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: c.separator.withOpacity(0.5),
        borderRadius: BorderRadius.circular(_C.rMD - 2),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(_C.rMD - 4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(c.isDark ? 0.3 : 0.07),
              blurRadius: 8, offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: c.label,
        unselectedLabelColor: c.label3,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        padding: const EdgeInsets.all(2),
        tabs: const [Tab(text: 'Gastos'), Tab(text: 'Ingresos')],
      ),
    );
  }
}

// ─── LISTA DE RECURRENTES ────────────────────────────────────────────────────
class _RecurringList extends StatelessWidget {
  final List<RecurringTransaction> items;
  final bool isExpense;
  final _C c;
  final RecurringRepository repository;
  final Function(RecurringTransaction) onEdit;
  final Function(RecurringTransaction) onDelete;
  final VoidCallback onAdd;
  final Future<void> Function() onRefresh;

  const _RecurringList({
    super.key,
    required this.items, required this.isExpense, required this.c,
    required this.repository, required this.onEdit, required this.onDelete,
    required this.onAdd, required this.onRefresh,
  });

  DateTime _day(RecurringTransaction t) =>
      DateTime(t.nextDueDate.year, t.nextDueDate.month, t.nextDueDate.day);

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _ListEmptyState(isExpense: isExpense, c: c, onAdd: onAdd);
    }

    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final overdue  = items.where((i) => _day(i).isBefore(today)).toList();
    final dueToday = items.where((i) => _day(i) == today).toList();
    final upcoming = items.where((i) => _day(i).isAfter(today)).toList();

    // --- LÓGICA DE LA ALERTA INTELIGENTE ---
    // Contamos items que vencen hoy o ya vencieron
    final pendingCount = items.where((i) {
      final itemDate = DateTime(i.nextDueDate.year, i.nextDueDate.month, i.nextDueDate.day);
      return itemDate.isBefore(today) || itemDate.isAtSameMomentAs(today);
    }).length;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _C.accent,
      strokeWidth: 1.5,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: _FadeSlide(
              delay: 0,
              child: _MonthlySummaryCard(
                  items: items, isExpense: isExpense, c: c),
            ),
          ),
          // --- AQUÍ INSERTAMOS LA ALERTA ---
        SliverToBoxAdapter(
          child: _FadeSlide(
            delay: 50,
            child: _PendingAlertBanner(
              count: pendingCount,
              c: c,
              onTap: () {
                HapticFeedback.mediumImpact();
                // Navegamos a la pantalla que creamos antes
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PendingPaymentsScreen()),
                );
              },
            ),
          ),
        ),
          if (overdue.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                  label: 'Vencidos', count: overdue.length,
                  color: _C.expense, c: c),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FadeSlide(
                  delay: 60 + i * 45,
                  child: _PaymentCard(
                    item: overdue[i], c: c, repository: repository,
                    onEdit: () => onEdit(overdue[i]),
                    onDelete: () => onDelete(overdue[i]),
                  ),
                ),
                childCount: overdue.length,
              ),
            ),
          ],

          if (dueToday.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                  label: 'Para hoy', count: dueToday.length,
                  color: _C.warning, c: c),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FadeSlide(
                  delay: 70 + i * 45,
                  child: _PaymentCard(
                    item: dueToday[i], c: c, repository: repository,
                    onEdit: () => onEdit(dueToday[i]),
                    onDelete: () => onDelete(dueToday[i]),
                  ),
                ),
                childCount: dueToday.length,
              ),
            ),
          ],

          if (upcoming.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionLabel(
                  label: 'Próximos', count: upcoming.length,
                  color: _C.income, c: c),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FadeSlide(
                    delay: 80 + i * 45,
                    child: _PaymentCard(
                      item: upcoming[i], c: c, repository: repository,
                      onEdit: () => onEdit(upcoming[i]),
                      onDelete: () => onDelete(upcoming[i]),
                    ),
                  ),
                  childCount: upcoming.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── RESUMEN MENSUAL ─────────────────────────────────────────────────────────
class _MonthlySummaryCard extends StatelessWidget {
  final List<RecurringTransaction> items;
  final bool isExpense;
  final _C c;

  const _MonthlySummaryCard(
      {required this.items, required this.isExpense, required this.c});

  double get _monthly => items.fold<double>(0, (sum, item) {
        final m = switch (item.frequency) {
          'daily'     => 30.0,
          'weekly'    => 4.33,
          'biweekly'  => 2.17,
          'monthly'   => 1.0,
          'quarterly' => 1 / 3.0,
          'yearly'    => 1 / 12.0,
          _           => 1.0,
        };
        return sum + (item.amount * m);
      });

  @override
  Widget build(BuildContext context) {
    final color = isExpense ? _C.expense : _C.income;
    final total = _monthly;
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final compactFmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);

    return Container(
      margin: const EdgeInsets.fromLTRB(_C.md, _C.md, _C.md, 0),
      padding: const EdgeInsets.all(_C.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: color.withOpacity(0.15), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(c.isDark ? 0.12 : 0.06),
            blurRadius: 20, offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.2 : 0.04),
            blurRadius: 8, offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color)),
                  const SizedBox(width: 6),
                  Text(
                    isExpense ? 'GASTO MENSUAL' : 'INGRESO MENSUAL',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        letterSpacing: 0.8, color: c.label3),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  total > 9999999 ? compactFmt.format(total) : fmt.format(total),
                  style: TextStyle(
                    fontSize: 32, fontWeight: FontWeight.w800,
                    color: color, letterSpacing: -1, height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${items.length} activo${items.length != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: c.label3),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniStat(label: 'Diario',
                  value: fmt.format(total / 30), color: color, c: c),
              const SizedBox(height: _C.sm),
              _MiniStat(label: 'Anual',
                  value: compactFmt.format(total * 12), color: color, c: c),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final _C c;

  const _MiniStat({
    required this.label, required this.value,
    required this.color, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(c.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(_C.rSM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.7), letterSpacing: 0.3)),
          Text(value,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

// ─── LABEL DE SECCIÓN ────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final _C c;

  const _SectionLabel({
    required this.label, required this.count,
    required this.color, required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_C.md, _C.lg, _C.md, _C.sm),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: c.label3, letterSpacing: 0.2)),
          const SizedBox(width: _C.sm),
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
                color: color.withOpacity(0.15), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

// ─── TARJETA DE PAGO ─────────────────────────────────────────────────────────
class _PaymentCard extends StatefulWidget {
  final RecurringTransaction item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final RecurringRepository repository;
  final _C c;

  const _PaymentCard({
    required this.item, required this.onEdit, required this.onDelete,
    required this.repository, required this.c,
  });

  @override
  State<_PaymentCard> createState() => _PaymentCardState();
}

class _PaymentCardState extends State<_PaymentCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;

  _C get c => widget.c;
  bool get _isExpense => widget.item.type == 'Gasto';

  DateTime get _dueDay => DateTime(widget.item.nextDueDate.year,
      widget.item.nextDueDate.month, widget.item.nextDueDate.day);

  int get _daysUntil {
    final now = DateTime.now();
    return _dueDay.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  Color get _statusColor {
    if (_daysUntil < 0) return _C.expense;
    if (_daysUntil == 0) return _C.warning;
    return _C.income;
  }

  String get _statusLabel {
    if (_daysUntil < 0) return 'Vencido';
    if (_daysUntil == 0) return 'Hoy';
    if (_daysUntil == 1) return 'Mañana';
    if (_daysUntil <= 7) return 'En $_daysUntil días';
    return DateFormat.MMMd('es_CO').format(widget.item.nextDueDate);
  }

  String get _freqLabel => switch (widget.item.frequency) {
        'daily'     => 'Diario',
        'weekly'    => 'Semanal',
        'biweekly'  => 'Quincenal',
        'monthly'   => 'Mensual',
        'quarterly' => 'Trimestral',
        'yearly'    => 'Anual',
        _           => widget.item.frequency,
      };

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        duration: const Duration(milliseconds: 100), vsync: this);
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
        CurvedAnimation(parent: _pressCtrl, curve: Curves.easeIn));
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    HapticFeedback.lightImpact();
    try {
      await widget.repository.processPayment(widget.item.id);
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Pago registrado', type: NotificationType.success);
    } catch (_) {
      HapticFeedback.mediumImpact();
      NotificationHelper.show(
          message: 'Error al registrar', type: NotificationType.error);
    }
  }

  Future<void> _skip() async {
    HapticFeedback.selectionClick();
    try {
      await widget.repository.skipPayment(widget.item.id);
      NotificationHelper.show(
          message: 'Período omitido', type: NotificationType.success);
    } catch (_) {
      NotificationHelper.show(
          message: 'Error al omitir', type: NotificationType.error);
    }
  }

  Future<void> _snooze() async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: widget.item.nextDueDate.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (ctx, child) => Theme(
        data: c.isDark
            ? ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(primary: _C.accent))
            : ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(primary: _C.accent)),
        child: child!,
      ),
    );
    if (newDate != null) {
      try {
        await widget.repository.snoozePayment(widget.item.id, newDate);
        HapticFeedback.selectionClick();
        NotificationHelper.show(
            message: 'Pospuesto', type: NotificationType.success);
      } catch (_) {
        NotificationHelper.show(
            message: 'Error al posponer', type: NotificationType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final color = _isExpense ? _C.expense : _C.income;

    return Padding(
      padding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, _C.sm + 4),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) { _pressCtrl.reverse(); _showOptionsSheet(context); },
          onTapCancel: () => _pressCtrl.reverse(),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(_C.rXL),
              border: _daysUntil < 0
                  ? Border.all(color: _C.expense.withOpacity(0.35), width: 1)
                  : Border.all(color: c.separator.withOpacity(0.4), width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(c.isDark ? 0.2 : 0.05),
                  blurRadius: 12, offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Cuerpo
                Padding(
                  padding: const EdgeInsets.all(_C.md),
                  child: Row(
                    children: [
                      // Ícono
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: color.withOpacity(c.isDark ? 0.18 : 0.1),
                          borderRadius: BorderRadius.circular(_C.rMD),
                        ),
                        child: Icon(
                          _isExpense
                              ? Iconsax.receipt_minus
                              : Iconsax.receipt_add,
                          color: color, size: 22),
                      ),
                      const SizedBox(width: _C.md),

                      // Nombre + metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.item.description,
                                style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: c.label, letterSpacing: -0.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Row(children: [
                              Text(_freqLabel,
                                  style: TextStyle(
                                      fontSize: 13, color: c.label3)),
                              const SizedBox(width: 6),
                              Container(
                                  width: 3, height: 3,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: c.label4)),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor
                                      .withOpacity(c.isDark ? 0.2 : 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(_statusLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _statusColor,
                                    )),
                              ),
                            ]),
                          ],
                        ),
                      ),

                      // Monto + ícono de menú
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${_isExpense ? '−' : '+'}${fmt.format(widget.item.amount)}',
                            style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800,
                              color: color, letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Icon(Icons.more_horiz_rounded,
                              size: 18, color: c.label4),
                        ],
                      ),
                    ],
                  ),
                ),

                // Separador
                Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(horizontal: _C.md),
                    color: c.separator),

                // Acciones rápidas
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      _C.md, _C.sm, _C.md, _C.sm),
                  child: Row(
                    children: [
                      _QuickAction(
                        label: 'Omitir',
                        icon: Iconsax.next,
                        color: c.label3,
                        bgColor: c.surfaceRaised,
                        onTap: _skip,
                      ),
                      const SizedBox(width: _C.sm),
                      Expanded(
                        child: _PrimaryActionBtn(
                          label: _isExpense
                              ? 'Pagar ahora'
                              : 'Registrar ingreso',
                          color: color,
                          onTap: _pay,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _OptionsSheet(
        item: widget.item, isExpense: _isExpense, c: c,
        onPay: _pay, onSkip: _skip, onSnooze: _snooze,
        onEdit: widget.onEdit, onDelete: widget.onDelete,
      ),
    );
  }
}

// ─── QUICK ACTION ────────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _QuickAction({
    required this.label, required this.icon, required this.color,
    required this.bgColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); onTap(); },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: _C.md, vertical: 8),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(_C.rMD)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}

// ─── PRIMARY ACTION BTN ──────────────────────────────────────────────────────
class _PrimaryActionBtn extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  State<_PrimaryActionBtn> createState() => _PrimaryActionBtnState();
}

class _PrimaryActionBtnState extends State<_PrimaryActionBtn> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) { setState(() => _pressing = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: _pressing
              ? widget.color.withOpacity(0.8)
              : widget.color,
          borderRadius: BorderRadius.circular(_C.rMD),
        ),
        alignment: Alignment.center,
        child: Text(widget.label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: Colors.white)),
      ),
    );
  }
}

// ─── BOTTOM SHEET ────────────────────────────────────────────────────────────
class _OptionsSheet extends StatelessWidget {
  final RecurringTransaction item;
  final bool isExpense;
  final _C c;
  final VoidCallback onPay;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _OptionsSheet({
    required this.item, required this.isExpense, required this.c,
    required this.onPay, required this.onSkip, required this.onSnooze,
    required this.onEdit, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: c.separator, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: c.separator,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_C.lg, 0, _C.lg, _C.md),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: c.label, letterSpacing: -0.3)),
                    Text(isExpense ? 'Gasto fijo' : 'Ingreso fijo',
                        style: TextStyle(fontSize: 13, color: c.label3)),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                        color: c.surfaceRaised, shape: BoxShape.circle),
                    child: Icon(Icons.close_rounded,
                        size: 16, color: c.label3),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 0.5, color: c.separator),
          const SizedBox(height: _C.sm),
          _SheetOption(
            icon: Iconsax.tick_circle,
            label: isExpense ? 'Pagar ahora' : 'Registrar ingreso',
            subtitle: 'Registrar como transacción',
            color: isExpense ? _C.expense : _C.income, c: c,
            onTap: () { Navigator.pop(context); onPay(); },
          ),
          _SheetOption(
            icon: Iconsax.clock, label: 'Posponer',
            subtitle: 'Elegir nueva fecha', color: _C.accent, c: c,
            onTap: () { Navigator.pop(context); onSnooze(); },
          ),
          _SheetOption(
            icon: Iconsax.next, label: 'Omitir período',
            subtitle: 'Saltar al siguiente ciclo', color: _C.warning, c: c,
            onTap: () { Navigator.pop(context); onSkip(); },
          ),
          Container(
            margin: const EdgeInsets.symmetric(
                horizontal: _C.lg, vertical: _C.sm),
            height: 0.5, color: c.separator,
          ),
          _SheetOption(
            icon: Iconsax.edit, label: 'Editar',
            subtitle: 'Modificar detalles', color: c.label2, c: c,
            onTap: () { Navigator.pop(context); onEdit(); },
          ),
          _SheetOption(
            icon: Iconsax.trash, label: 'Eliminar',
            subtitle: 'Eliminar permanentemente', color: _C.expense, c: c,
            isDestructive: true,
            onTap: () { Navigator.pop(context); onDelete(); },
          ),
          SizedBox(
              height: _C.lg + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _SheetOption extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final _C c;
  final VoidCallback onTap;
  final bool isDestructive;

  const _SheetOption({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.c, required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_SheetOption> createState() => _SheetOptionState();
}

class _SheetOptionState extends State<_SheetOption> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressing
            ? widget.c.surfaceRaised
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: _C.lg, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.color
                    .withOpacity(widget.c.isDark ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(_C.rSM + 2),
              ),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
            const SizedBox(width: _C.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600,
                      color: widget.isDestructive
                          ? widget.color
                          : widget.c.label,
                    )),
                Text(widget.subtitle,
                    style: TextStyle(
                        fontSize: 13, color: widget.c.label3)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: widget.c.label4, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── ESTADOS ─────────────────────────────────────────────────────────────────
class _ListEmptyState extends StatelessWidget {
  final bool isExpense;
  final _C c;
  final VoidCallback onAdd;
  const _ListEmptyState(
      {required this.isExpense, required this.c, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_C.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                  color: c.surfaceRaised, shape: BoxShape.circle),
              child: Icon(
                isExpense ? Iconsax.receipt_minus : Iconsax.receipt_add,
                size: 32, color: c.label4,
              ),
            ),
            const SizedBox(height: _C.lg),
            Text(
              isExpense ? 'Sin gastos fijos' : 'Sin ingresos fijos',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                  color: c.label, letterSpacing: -0.3),
            ),
            const SizedBox(height: _C.sm),
            Text(
              isExpense
                  ? 'Añade suscripciones, alquiler\no cualquier gasto recurrente.'
                  : 'Añade tu salario u otros\ningresos periódicos.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: c.label3, height: 1.45),
            ),
            const SizedBox(height: _C.lg),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onAdd(); },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _C.lg, vertical: 13),
                decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(_C.rMD)),
                child: const Text('Añadir primero',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final _C c;
  final VoidCallback onAdd;
  const _EmptyState({required this.c, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_C.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/automation_animation.json',
                width: 220, height: 220),
            const SizedBox(height: _C.lg),
            Text('Automatiza tus finanzas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                    color: c.label, letterSpacing: -0.5),
                textAlign: TextAlign.center),
            const SizedBox(height: _C.sm),
            Text(
              'Registra una vez y la app se\nencarga del resto automáticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: c.label3, height: 1.45),
            ),
            const SizedBox(height: _C.xl),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onAdd(); },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(_C.rMD)),
                child: const Text('Añadir gasto fijo',
                    style: TextStyle(
                        color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final _C c;
  final VoidCallback onRetry;
  const _ErrorState(
      {required this.error, required this.c, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_C.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.danger, size: 48, color: _C.expense),
            const SizedBox(height: _C.md),
            Text('Algo salió mal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                    color: c.label)),
            const SizedBox(height: _C.sm),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.label3)),
            const SizedBox(height: _C.lg),
            GestureDetector(
              onTap: () { HapticFeedback.lightImpact(); onRetry(); },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: _C.lg, vertical: 12),
                decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(_C.rMD)),
                child: const Text('Reintentar',
                    style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SKELETON LOADER ─────────────────────────────────────────────────────────
class _SkeletonLoader extends StatefulWidget {
  final _C c;
  const _SkeletonLoader({required this.c});

  @override
  State<_SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<_SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this)
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final shimmer =
            Color.lerp(c.surface, c.surfaceRaised, _anim.value)!;
        return ListView.builder(
          padding: const EdgeInsets.all(_C.md),
          itemCount: 3,
          itemBuilder: (_, i) => Container(
            margin: const EdgeInsets.only(bottom: _C.sm + 4),
            height: 120,
            decoration: BoxDecoration(
                color: shimmer,
                borderRadius: BorderRadius.circular(_C.rXL)),
          ),
        );
      },
    );
  }
}

// ─── BOTONES ─────────────────────────────────────────────────────────────────
class _OutlineBtn extends StatelessWidget {
  final String label;
  final _C c;
  final VoidCallback onTap;
  const _OutlineBtn(
      {required this.label, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(_C.rMD),
          border: Border.all(color: c.separator, width: 0.5),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                color: c.label, fontSize: 15,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _FilledBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FilledBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(_C.rMD)),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─── ANIMACIÓN DE ENTRADA ────────────────────────────────────────────────────
class _FadeSlide extends StatefulWidget {
  final Widget child;
  final int delay;
  const _FadeSlide({required this.child, required this.delay});

  @override
  State<_FadeSlide> createState() => _FadeSlideState();
}

class _FadeSlideState extends State<_FadeSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: _C.slow, vsync: this);
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: _C.curveOut));
    Future.delayed(Duration(milliseconds: widget.delay),
        () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _PendingAlertBanner extends StatelessWidget {
  final int count;
  final _C c;
  final VoidCallback onTap;

  const _PendingAlertBanner({required this.count, required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(_C.md, _C.md, _C.md, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Usamos un gradiente sutil o un color sólido vibrante pero elegante
          color: _C.warning.withOpacity(c.isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(_C.rLG),
          border: Border.all(color: _C.warning.withOpacity(0.3), width: 0.5),
        ),
        child: Row(
          children: [
            // Icono animado o con un badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Iconsax.notification, color: _C.warning, size: 22),
                Positioned(
                  top: -2, right: -2,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: _C.expense,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.surface, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Acción requerida',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, 
                      color: c.label, letterSpacing: -0.2
                    ),
                  ),
                  Text(
                    'Tienes $count ${count == 1 ? 'pago pendiente' : 'pagos pendientes'} por confirmar.',
                    style: TextStyle(fontSize: 12, color: c.label2),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _C.warning),
          ],
        ),
      ),
    );
  }
}