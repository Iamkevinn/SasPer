// lib/screens/accounts_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO — Apple iOS / Wallet                                  │
// │  • El balance total es el protagonista absoluto de la pantalla.            │
// │  • Cada cuenta es una fila limpia — nombre izquierda, saldo derecha.       │
// │  • Los grupos de tipo actúan como secciones, no como tarjetas grandes.     │
// │  • Las acciones viven en un bottom sheet — no contaminan la vista.         │
// │  • El filtro de chips es una píldora segmentada estilo iOS.                │
// │  • Cero ruido visual: sin gradientes decorativos, sin bordes dobles.       │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:developer' as developer;
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/screens/add_account_screen.dart';
import 'package:sasper/screens/add_transfer_screen.dart';
import 'package:sasper/screens/account_details_screen.dart';
import 'package:sasper/screens/edit_account_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/main.dart';

// ─── TOKENS DINÁMICOS ────────────────────────────────────────────────────────
class _C {
  final BuildContext ctx;
  _C(this.ctx);

  bool get isDark => Theme.of(ctx).brightness == Brightness.dark;

  // Superficies — escala iOS systemGroupedBackground
  Color get bg =>
      isDark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
  Color get surface =>
      isDark ? const Color(0xFF1C1C1E) : Colors.white;
  Color get surfaceRaised =>
      isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F5F7);
  Color get separator =>
      isDark ? const Color(0xFF38383A) : const Color(0xFFE5E5EA);

  // Texto
  Color get label =>
      isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E);
  Color get label2 =>
      isDark ? const Color(0xFFEBEBF5) : const Color(0xFF3A3A3C);
  Color get label3 =>
      isDark ? const Color(0xFF8E8E93) : const Color(0xFF636366);
  Color get label4 =>
      isDark ? const Color(0xFF48484A) : const Color(0xFFAEAEB2);

  // Semánticos iOS
  static const Color expense = Color(0xFFFF3B30);
  static const Color income  = Color(0xFF30D158);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color accent  = Color(0xFF0A84FF);

  // Colores por tipo de cuenta
  static const Map<String, Color> typeColors = {
    'Efectivo':           Color(0xFF30D158),
    'Cuenta Bancaria':    Color(0xFF0A84FF),
    'Tarjeta de Crédito': Color(0xFFBF5AF2),
    'Ahorros':            Color(0xFFFF9F0A),
    'Inversión':          Color(0xFF64D2FF),
  };
  static const Color typeColorDefault = Color(0xFF8E8E93);

  static const Map<String, IconData> typeIcons = {
    'Efectivo':           Iconsax.money_3,
    'Cuenta Bancaria':    Iconsax.building_4,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros':            Iconsax.safe_home,
    'Inversión':          Iconsax.chart_1,
  };
  static const IconData typeIconDefault = Iconsax.wallet_3;

  Color typeColor(String type) => typeColors[type] ?? typeColorDefault;
  IconData typeIcon(String type) => typeIcons[type] ?? typeIconDefault;

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
  static const double rXL = 20.0;

  // Animaciones
  static const Duration fast  = Duration(milliseconds: 150);
  static const Duration mid   = Duration(milliseconds: 280);
  static const Duration slow  = Duration(milliseconds: 420);
  static const Curve curveOut = Curves.easeOutCubic;
}

// ─── PANTALLA PRINCIPAL ──────────────────────────────────────────────────────
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  final AccountRepository _repo = AccountRepository.instance;
  late final Stream<List<Account>> _stream;

  String _selectedFilter = 'Todas';
  bool _showArchived = false;

  static const List<String> _filters = [
    'Todas', 'Efectivo', 'Bancarias', 'Crédito', 'Ahorros',
  ];

  @override
  void initState() {
    super.initState();
    developer.log('AccountsScreen initState', name: 'AccountsScreen');
    _stream = _repo.getAccountsStream();
    _repo.refreshData();
  }

  Future<void> _handleRefresh() => _repo.refreshData();

  // ── Navegación ───────────────────────────────────────────────────────────
  void _navigateToAddAccount() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<bool>(
      _iosRoute(const AddAccountScreen()),
    );
    if (result == true && mounted) _repo.refreshData();
  }

  void _navigateToAddTransfer() async {
    HapticFeedback.lightImpact();
    final result = await Navigator.of(context).push<bool>(
      _iosRoute(const AddTransferScreen()),
    );
    if (result == true && mounted) _repo.refreshData();
  }

  void _navigateToEditAccount(Account account) async {
    HapticFeedback.selectionClick();
    final result = await Navigator.of(context).push<bool>(
      _iosRoute(EditAccountScreen(account: account)),
    );
    if (result == true && mounted) _repo.refreshData();
  }

  void _navigateToDetails(Account account) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      _iosRoute(AccountDetailsScreen(accountId: account.id)),
    );
  }

  PageRouteBuilder<T> _iosRoute<T>(Widget page) => PageRouteBuilder<T>(
        pageBuilder: (_, a, __) => page,
        transitionDuration: _C.slow,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
                  begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: animation, curve: _C.curveOut)),
          child: child,
        ),
      );

  // ── Acciones sobre cuenta ────────────────────────────────────────────────
  Future<void> _handleDelete(Account account) async {
    if (account.balance != 0) {
      NotificationHelper.show(
        message: 'La cuenta aún tiene saldo.',
        type: NotificationType.error,
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final c = _C(context);
    final confirmed = await _showDeleteDialog(account, c);
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deleteAccountSafely(account.id);
      _repo.refreshData();
      EventService.instance.fire(AppEvent.accountUpdated);
      HapticFeedback.heavyImpact();
      NotificationHelper.show(
          message: 'Cuenta eliminada', type: NotificationType.success);
    } catch (e) {
      HapticFeedback.mediumImpact();
      NotificationHelper.show(
          message: e.toString().replaceFirst('Exception: ', ''),
          type: NotificationType.error);
    }
  }

  Future<void> _handleArchive(Account account) async {
    HapticFeedback.selectionClick();
    try {
      await _repo.archiveAccount(account.id);
      _repo.refreshData();
      EventService.instance.fire(AppEvent.accountUpdated);
      NotificationHelper.show(
          message: '"${account.name}" archivada.',
          type: NotificationType.info);
    } catch (e) {
      NotificationHelper.show(
          message: e.toString(), type: NotificationType.error);
    }
  }

  Future<void> _handleUnarchive(Account account) async {
    HapticFeedback.selectionClick();
    try {
      await _repo.unarchiveAccount(account.id);
      _repo.refreshData();
      EventService.instance.fire(AppEvent.accountUpdated);
      NotificationHelper.show(
          message: '"${account.name}" restaurada.',
          type: NotificationType.success);
    } catch (e) {
      NotificationHelper.show(
          message: e.toString(), type: NotificationType.error);
    }
  }

  Future<bool?> _showDeleteDialog(Account account, _C c) {
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
              borderRadius: BorderRadius.circular(28),
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
                    color: _C.expense.withOpacity(c.isDark ? 0.18 : 0.09),
                    borderRadius: BorderRadius.circular(_C.rMD),
                  ),
                  child: const Icon(Iconsax.trash, color: _C.expense, size: 22),
                ),
                const SizedBox(height: _C.md),
                Text('Eliminar cuenta',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: c.label, letterSpacing: -0.3)),
                const SizedBox(height: _C.sm),
                Text(
                  '¿Eliminar "${account.name}"? Esta acción no se puede deshacer.',
                  style: TextStyle(fontSize: 15, color: c.label3, height: 1.45),
                ),
                const SizedBox(height: _C.lg),
                Row(children: [
                  Expanded(
                    child: _OutlineBtn(
                        label: 'Cancelar', c: c,
                        onTap: () => Navigator.pop(ctx, false)),
                  ),
                  const SizedBox(width: _C.sm),
                  Expanded(
                    child: _FilledBtn(
                        label: 'Eliminar', color: _C.expense,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          Navigator.pop(ctx, true);
                        }),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Account> _filterAccounts(List<Account> accounts) {
    return switch (_selectedFilter) {
      'Efectivo'  => accounts.where((a) => a.type == 'Efectivo').toList(),
      'Bancarias' => accounts.where((a) => a.type == 'Cuenta Bancaria').toList(),
      'Crédito'   => accounts.where((a) => a.type == 'Tarjeta de Crédito').toList(),
      'Ahorros'   => accounts.where((a) => a.type == 'Ahorros' || a.type == 'Inversión').toList(),
      _           => accounts,
    };
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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
        body: StreamBuilder<List<Account>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _SkeletonLoader(c: c);
            }
            if (snapshot.hasError) {
              return _ErrorState(
                  error: '${snapshot.error}', c: c,
                  onRetry: _handleRefresh);
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _EmptyState(c: c, onAdd: _navigateToAddAccount);
            }

            final all      = snapshot.data!;
            final active   = all.where((a) => a.status == AccountStatus.active).toList();
            final archived = all.where((a) => a.status == AccountStatus.archived).toList();

            return _buildBody(active, archived, c);
          },
        ),
      ),
    );
  }

  Widget _buildBody(
      List<Account> active, List<Account> archived, _C c) {
    final filtered = _filterAccounts(active);
    final total = active.fold<double>(0, (s, a) => s + a.balance);

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: _C.accent,
      strokeWidth: 1.5,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          // ── APP BAR ──────────────────────────────────────────────────────
          _buildSliverAppBar(c),

          // ── BALANCE TOTAL — protagonista ─────────────────────────────────
          SliverToBoxAdapter(
            child: _FadeSlide(
              delay: 0,
              child: _BalanceHero(
                  total: total,
                  accountCount: active.length,
                  c: c),
            ),
          ),

          // ── ACCIONES RÁPIDAS ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FadeSlide(
              delay: 40,
              child: _QuickActions(
                c: c,
                onTransfer: _navigateToAddTransfer,
                onAdd: _navigateToAddAccount,
              ),
            ),
          ),

          // ── FILTROS ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _FadeSlide(
              delay: 70,
              child: _FilterBar(
                selected: _selectedFilter,
                filters: _filters,
                c: c,
                onSelect: (f) => setState(() => _selectedFilter = f),
              ),
            ),
          ),

          // ── CUENTAS ACTIVAS ──────────────────────────────────────────────
          if (filtered.isEmpty)
            SliverFillRemaining(
              child: _FilterEmptyState(c: c),
            )
          else ...[
            ..._buildAccountGroups(filtered, archived: false, c: c),
          ],

          // ── ARCHIVADAS ───────────────────────────────────────────────────
          if (archived.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _ArchivadosToggle(
                show: _showArchived,
                count: archived.length,
                c: c,
                onToggle: () =>
                    setState(() => _showArchived = !_showArchived),
              ),
            ),
            if (_showArchived)
              ..._buildAccountGroups(archived, archived: true, c: c),
          ],

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────────────────
  Widget _buildSliverAppBar(_C c) {
    return SliverAppBar(
      expandedHeight: 0,
      floating: false,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 56,
      title: Padding(
        // Padding generoso para separar del borde y del botón de regreso
        padding: const EdgeInsets.only(left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'MIS CUENTAS',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: _C.accent,
              ),
            ),
            Text(
              'Patrimonio',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.label,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grupos de cuentas por tipo ───────────────────────────────────────────
  List<Widget> _buildAccountGroups(
      List<Account> accounts, {
      required bool archived,
      required _C c,
  }) {
    // Agrupar por tipo
    final Map<String, List<Account>> groups = {};
    for (final acc in accounts) {
      groups.putIfAbsent(acc.type, () => []).add(acc);
    }
    final types = groups.keys.toList();

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, 0),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final type = types[i];
              return _FadeSlide(
                delay: 100 + i * 55,
                child: _AccountGroup(
                  type: type,
                  accounts: groups[type]!,
                  c: c,
                  isArchived: archived,
                  onTapAccount: _navigateToDetails,
                  onEdit: _navigateToEditAccount,
                  onDelete: _handleDelete,
                  onArchive: _handleArchive,
                  onUnarchive: _handleUnarchive,
                ),
              );
            },
            childCount: types.length,
          ),
        ),
      ),
    ];
  }
}

// ─── BALANCE HERO ─────────────────────────────────────────────────────────────
// El número grande. El protagonista. Todo lo demás es soporte.
// ─── BALANCE HERO (Actualizado) ───────────────────────────────────────────────
// El número grande. El protagonista. Todo lo demás es soporte.
class _BalanceHero extends StatelessWidget {
  final double total;
  final int accountCount;
  final _C c;

  const _BalanceHero({
    required this.total,
    required this.accountCount,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final isNeg = total < 0;
    final color = isNeg ? _C.expense : _C.income;
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final compactFmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final displayTotal =
        total.abs() > 99999999 ? compactFmt.format(total) : fmt.format(total);

    return Container(
      margin: const EdgeInsets.fromLTRB(_C.md, _C.sm, _C.md, _C.md),
      padding: const EdgeInsets.all(_C.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
            color: color.withOpacity(0.12), width: 0.5),
        boxShadow:[
          BoxShadow(
            color: color.withOpacity(c.isDark ? 0.12 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          // Eyebrow
          Row(
            children:[
              Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: color)),
              const SizedBox(width: 6),
              Text(
                'SALDO CONTABLE (FÍSICO)', // <-- Cambio de etiqueta
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 0.9, color: c.label3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Número grande — el protagonista
          Text(
            displayTotal,
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: isNeg ? _C.expense : c.label,
              letterSpacing: -1.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),

          // Metadata: cuántas cuentas + Nota educativa
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(_C.rSM),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children:[
                    Icon(Iconsax.card, size: 13, color: c.label3),
                    const SizedBox(width: 5),
                    Text(
                      '$accountCount cuenta${accountCount != 1 ? 's' : ''} activa${accountCount != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w500,
                        color: c.label3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // --- NUEVA NOTA EDUCATIVA ---
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children:[
                    Icon(Iconsax.info_circle, size: 12, color: _C.accent.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Este es el dinero exacto que hay en tus bancos (incluye tu dinero reservado). Ve a Inicio para ver tu saldo disponible.',
                        style: TextStyle(
                          fontSize: 11, 
                          color: c.label4, 
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// ─── ACCIONES RÁPIDAS ────────────────────────────────────────────────────────
// Dos acciones frecuentes: transferir y añadir. Sin más ruido.
class _QuickActions extends StatelessWidget {
  final _C c;
  final VoidCallback onTransfer;
  final VoidCallback onAdd;

  const _QuickActions({
    required this.c, required this.onTransfer, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, _C.md),
      child: Row(
        children: [
          Expanded(
            child: _ActionBtn(
              label: 'Transferir',
              icon: Iconsax.arrow_swap_horizontal,
              color: _C.accent,
              c: c,
              onTap: onTransfer,
            ),
          ),
          const SizedBox(width: _C.sm),
          Expanded(
            child: _ActionBtn(
              label: 'Nueva cuenta',
              icon: Iconsax.add,
              color: _C.income,
              c: c,
              onTap: onAdd,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final _C c;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label, required this.icon, required this.color,
    required this.c, required this.onTap,
  });

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _pressing
              ? widget.color.withOpacity(widget.c.isDark ? 0.25 : 0.15)
              : widget.color.withOpacity(widget.c.isDark ? 0.18 : 0.09),
          borderRadius: BorderRadius.circular(_C.rLG),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(widget.icon, size: 16, color: widget.color),
            const SizedBox(width: 6),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: widget.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── FILTER BAR ──────────────────────────────────────────────────────────────
// Chips de filtro con estilo iOS — compactos, sin borde doble.
class _FilterBar extends StatelessWidget {
  final String selected;
  final List<String> filters;
  final _C c;
  final Function(String) onSelect;

  const _FilterBar({
    required this.selected, required this.filters,
    required this.c, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(_C.md, 0, _C.md, _C.sm),
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: _C.xs + 2),
        itemBuilder: (context, i) {
          final f = filters[i];
          final isSelected = f == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(f);
            },
            child: AnimatedContainer(
              duration: _C.fast,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? _C.accent
                    : c.surfaceRaised,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isSelected ? Colors.white : c.label3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── GRUPO DE CUENTAS ────────────────────────────────────────────────────────
// Sección colapsable por tipo. El header es compacto, no compite.
class _AccountGroup extends StatefulWidget {
  final String type;
  final List<Account> accounts;
  final _C c;
  final bool isArchived;
  final Function(Account) onTapAccount;
  final Function(Account) onEdit;
  final Function(Account) onDelete;
  final Function(Account) onArchive;
  final Function(Account) onUnarchive;

  const _AccountGroup({
    required this.type, required this.accounts, required this.c,
    required this.isArchived, required this.onTapAccount, required this.onEdit,
    required this.onDelete, required this.onArchive, required this.onUnarchive,
  });

  @override
  State<_AccountGroup> createState() => _AccountGroupState();
}

class _AccountGroupState extends State<_AccountGroup>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  late AnimationController _arrowCtrl;

  _C get c => widget.c;

  @override
  void initState() {
    super.initState();
    _arrowCtrl = AnimationController(
      duration: _C.mid, vsync: this,
      value: 1.0, // empieza expanded
    );
  }

  @override
  void dispose() { _arrowCtrl.dispose(); super.dispose(); }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    _expanded ? _arrowCtrl.forward() : _arrowCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final color = c.typeColor(widget.type);
    final icon  = c.typeIcon(widget.type);
    final subtotal = widget.accounts
        .fold<double>(0, (s, a) => s + a.balance);
    final fmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: _C.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(_C.rXL),
        border: Border.all(color: c.separator.withOpacity(0.4), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(c.isDark ? 0.18 : 0.04),
            blurRadius: 10, offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header del grupo ──────────────────────────────────────────
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(_C.md),
              child: Row(
                children: [
                  // Ícono de tipo
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(c.isDark ? 0.18 : 0.1),
                      borderRadius: BorderRadius.circular(_C.rSM + 2),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  const SizedBox(width: _C.md),

                  // Nombre del tipo + conteo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.type,
                              style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: c.label, letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: _C.xs + 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: color.withOpacity(
                                    c.isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.accounts.length}',
                                style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          fmt.format(subtotal),
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500,
                            color: subtotal < 0 ? _C.expense : c.label3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Flecha animada
                  RotationTransition(
                    turns: Tween(begin: 0.0, end: 0.5)
                        .animate(CurvedAnimation(
                            parent: _arrowCtrl,
                            curve: _C.curveOut)),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: c.label4, size: 22),
                  ),
                ],
              ),
            ),
          ),

          // ── Cuentas colapsables ───────────────────────────────────────
          AnimatedCrossFade(
            duration: _C.mid,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                Container(height: 0.5, color: c.separator),
                ...widget.accounts.asMap().entries.map((entry) {
                  final i = entry.key;
                  final account = entry.value;
                  final isLast = i == widget.accounts.length - 1;
                  return Column(
                    children: [
                      _AccountRow(
                        account: account,
                        c: c,
                        isArchived: widget.isArchived,
                        onTap: () => widget.onTapAccount(account),
                        onOptions: () => _showAccountSheet(account),
                      ),
                      if (!isLast)
                        Container(
                          height: 0.5,
                          margin: const EdgeInsets.only(left: 72),
                          color: c.separator,
                        ),
                    ],
                  );
                }),
              ],
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }

  // Options bottom sheet — las acciones no contaminan la vista
  void _showAccountSheet(Account account) {
    HapticFeedback.selectionClick();
    final isActive = account.status == AccountStatus.active;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (_) => _AccountOptionsSheet(
        account: account,
        c: c,
        isActive: isActive,
        onEdit: () { Navigator.pop(context); widget.onEdit(account); },
        onArchive: () { Navigator.pop(context); widget.onArchive(account); },
        onUnarchive: () { Navigator.pop(context); widget.onUnarchive(account); },
        onDelete: () { Navigator.pop(context); widget.onDelete(account); },
      ),
    );
  }
}

// ─── FILA DE CUENTA ──────────────────────────────────────────────────────────
// La unidad mínima de información. Nombre + saldo + acceso a detalle.
class _AccountRow extends StatefulWidget {
  final Account account;
  final _C c;
  final bool isArchived;
  final VoidCallback onTap;
  final VoidCallback onOptions;

  const _AccountRow({
    required this.account, required this.c, required this.isArchived,
    required this.onTap, required this.onOptions,
  });

  @override
  State<_AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<_AccountRow> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final acc = widget.account;
    final isNeg = acc.balance < 0;
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final compactFmt = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 1);
    final displayBalance = acc.balance.abs() > 9999999
        ? compactFmt.format(acc.balance)
        : fmt.format(acc.balance);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressing
            ? c.surfaceRaised
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: _C.md, vertical: 12),
        child: Opacity(
          opacity: widget.isArchived ? 0.6 : 1.0,
          child: Row(
            children: [
              // Inicial del nombre en círculo de color
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: c.typeColor(acc.type)
                      .withOpacity(c.isDark ? 0.18 : 0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  acc.name.isNotEmpty
                      ? acc.name[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: c.typeColor(acc.type),
                  ),
                ),
              ),
              const SizedBox(width: _C.md),

              // Nombre de la cuenta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      acc.name,
                      style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600,
                        color: c.label, letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.isArchived)
                      Text(
                        'Archivada',
                        style: TextStyle(fontSize: 12, color: c.label4),
                      ),
                  ],
                ),
              ),

              // Saldo + menú
              Row(
                children: [
                  Text(
                    displayBalance,
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: isNeg ? _C.expense : c.label,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: _C.sm),
                  GestureDetector(
                    onTap: widget.onOptions,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz_rounded,
                          size: 18, color: c.label4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET DE OPCIONES ────────────────────────────────────────────────
class _AccountOptionsSheet extends StatelessWidget {
  final Account account;
  final _C c;
  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  const _AccountOptionsSheet({
    required this.account, required this.c, required this.isActive,
    required this.onEdit, required this.onArchive,
    required this.onUnarchive, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

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
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: c.separator,
                borderRadius: BorderRadius.circular(2)),
          ),

          // Header — nombre de la cuenta + saldo
          Padding(
            padding: const EdgeInsets.fromLTRB(_C.lg, 0, _C.lg, _C.md),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: c.typeColor(account.type)
                        .withOpacity(c.isDark ? 0.18 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    account.name.isNotEmpty ? account.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700,
                      color: c.typeColor(account.type),
                    ),
                  ),
                ),
                const SizedBox(width: _C.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.name,
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700,
                              color: c.label, letterSpacing: -0.3)),
                      Text(fmt.format(account.balance),
                          style: TextStyle(
                              fontSize: 14, color: c.label3,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
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

          if (isActive) ...[
            _SheetOption(
              icon: Iconsax.edit, label: 'Editar',
              subtitle: 'Modificar nombre o detalles',
              color: _C.accent, c: c, onTap: onEdit,
            ),
            _SheetOption(
              icon: Iconsax.archive, label: 'Archivar',
              subtitle: 'Ocultar sin eliminar',
              color: _C.warning, c: c, onTap: onArchive,
            ),
          ] else ...[
            _SheetOption(
              icon: Iconsax.undo, label: 'Restaurar',
              subtitle: 'Volver a cuentas activas',
              color: _C.income, c: c, onTap: onUnarchive,
            ),
            if (account.balance == 0)
              _SheetOption(
                icon: Iconsax.trash, label: 'Eliminar',
                subtitle: 'Eliminar permanentemente',
                color: _C.expense, c: c,
                isDestructive: true, onTap: onDelete,
              ),
          ],

          SizedBox(height: _C.lg + MediaQuery.of(context).padding.bottom),
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
        color: _pressing ? widget.c.surfaceRaised : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: _C.lg, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: widget.color
                    .withOpacity(widget.c.isDark ? 0.18 : 0.10),
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

// ─── TOGGLE DE ARCHIVADAS ────────────────────────────────────────────────────
class _ArchivadosToggle extends StatelessWidget {
  final bool show;
  final int count;
  final _C c;
  final VoidCallback onToggle;

  const _ArchivadosToggle({
    required this.show, required this.count,
    required this.c, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onToggle();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_C.md, _C.sm, _C.md, _C.sm),
        child: Row(
          children: [
            Icon(
              show ? Iconsax.eye_slash : Iconsax.eye,
              size: 15, color: c.label4,
            ),
            const SizedBox(width: 6),
            Text(
              show
                  ? 'Ocultar archivadas'
                  : '$count cuenta${count != 1 ? 's' : ''} archivada${count != 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500,
                color: c.label3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ESTADOS ─────────────────────────────────────────────────────────────────
class _FilterEmptyState extends StatelessWidget {
  final _C c;
  const _FilterEmptyState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: c.surfaceRaised, shape: BoxShape.circle),
            child: Icon(Iconsax.search_status,
                size: 28, color: c.label4),
          ),
          const SizedBox(height: _C.md),
          Text('Sin cuentas en esta categoría',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600,
                  color: c.label, letterSpacing: -0.2)),
          const SizedBox(height: _C.sm),
          Text('Prueba otro filtro',
              style: TextStyle(fontSize: 14, color: c.label3)),
        ],
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
            Lottie.asset('assets/animations/add_account_animation.json',
                width: 200, height: 200),
            const SizedBox(height: _C.lg),
            Text('Comienza aquí',
                style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w800,
                  color: c.label, letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: _C.sm),
            Text(
              'Añade tu primera cuenta para\norganizar tus finanzas.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15, color: c.label3, height: 1.45),
            ),
            const SizedBox(height: _C.xl),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onAdd();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                    color: _C.accent,
                    borderRadius: BorderRadius.circular(_C.rMD)),
                child: const Text('Añadir primera cuenta',
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
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                  color: _C.expense.withOpacity(c.isDark ? 0.18 : 0.09),
                  shape: BoxShape.circle),
              child: const Icon(Iconsax.danger,
                  size: 28, color: _C.expense),
            ),
            const SizedBox(height: _C.md),
            Text('Algo salió mal',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w700,
                    color: c.label, letterSpacing: -0.3)),
            const SizedBox(height: _C.sm),
            Text(error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: c.label3)),
            const SizedBox(height: _C.lg),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                onRetry();
              },
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
        return CustomScrollView(
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                height: 56, color: c.bg,
                padding: const EdgeInsets.fromLTRB(
                    _C.md, 12, _C.md, _C.sm),
                child: _shimmerBox(shimmer, 140, 28, _C.rSM),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(_C.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _shimmerBox(shimmer, double.infinity, 140, 28),
                  const SizedBox(height: _C.md),
                  Row(children: [
                    Expanded(child: _shimmerBox(shimmer, double.infinity, 48, _C.rLG)),
                    const SizedBox(width: _C.sm),
                    Expanded(child: _shimmerBox(shimmer, double.infinity, 48, _C.rLG)),
                  ]),
                  const SizedBox(height: _C.md),
                  _shimmerBox(shimmer, double.infinity, 160, _C.rXL),
                  const SizedBox(height: _C.md),
                  _shimmerBox(shimmer, double.infinity, 200, _C.rXL),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _shimmerBox(Color color, double w, double h, double r) =>
      Container(
        width: w, height: h,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(r)),
      );
}

// ─── BOTONES UTILITARIOS ─────────────────────────────────────────────────────
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
            color: color, borderRadius: BorderRadius.circular(_C.rMD)),
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
    _slide = Tween<Offset>(
            begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: _C.curveOut));
    Future.delayed(
        Duration(milliseconds: widget.delay),
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

// ── No-op TickerProvider — para controladores estáticos de fallback ───────────
class _NoVsync implements TickerProvider {
  const _NoVsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}