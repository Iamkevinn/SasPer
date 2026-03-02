// lib/screens/debts_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Deudas — Apple-first redesign
//
// Filosofía: el contacto es el protagonista, no la deuda.
// Como iOS Contacts + Wallet: ves personas y números — sin capas de decoración.
//
// Eliminado:
// • SliverAppBar expandedHeight con gradient → header blur fijo
// • LinearGradient en summary bar → surface sutil
// • AnimatedCrossFade → AnimatedSize (spring nativo)
// • InkWell con ripple → GestureDetector + press state
// • Tabs anidados (Activas/Historial) → un scroll, historial al final
// • Border dinámico 1px→2px + boxShadow condicional al expandir
// • Avatar con gradiente + circle + shadow → inicial sobre fondo plano
// • primaryContainer / surfaceContainerLow / outlineVariant → opacity-based
// • GoogleFonts.poppins + .inter mezclados → DM Sans + DM Mono unificado
// • Loading overlay pantalla completa → card centrado compacto
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/screens/add_debt_screen.dart';
import 'package:sasper/screens/edit_debt_screen.dart';
import 'package:sasper/screens/register_payment_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/debts/debt_card.dart';
import 'package:sasper/widgets/debts/shareable_debt_summary.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

// ── Tokens ─────────────────────────────────────────────────────────────────────
// Coherentes con transactions_screen.dart y add_transaction_screen.dart
class _T {
  static TextStyle display(double s,
          {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(
          fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4, height: 1.1);

  static TextStyle label(double s,
          {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);

  static TextStyle mono(double s,
          {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);

  // Espaciado
  static const double h  = 20.0; // gutter horizontal
  static const double r  = 20.0; // radio tarjeta
  static const double ri = 13.0; // radio ícono
}

// ── Paleta iOS ─────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

// Semántico por tipo de deuda
Color _debtColor(DebtType t) => t == DebtType.debt ? _kRed : _kGreen;

// Formateadores
final _fmt = NumberFormat.compactCurrency(
    locale: 'es_CO', symbol: '\$', decimalDigits: 0);
final _fmtFull =
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

// Color de fecha de vencimiento
Color _dueDateColor(DateTime due) {
  final days = due.difference(DateTime.now()).inDays;
  if (days < 0) return _kRed;
  if (days < 7) return _kOrange;
  return _kBlue.withOpacity(0.7);
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen>
    with TickerProviderStateMixin {
  final _repo = DebtRepository.instance;

  // Stream en declaración — sin riesgo LateInitializationError
  late final Stream<List<Debt>> _stream = _repo.getDebtsStream();
  late final TabController _tabs = TabController(length: 2, vsync: this);

  // Compartir
  final _shareKey  = GlobalKey();
  Debt? _debtToShare;
  bool  _isSharing = false;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // ── Navegación ───────────────────────────────────────────────────────────────

  void _goAdd() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const AddDebtScreen()));

  void _goEdit(Debt d) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => EditDebtScreen(debt: d)));

  void _goPayment(Debt d) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => RegisterPaymentScreen(debt: d)));

  // ── Acciones ─────────────────────────────────────────────────────────────────

  Future<void> _delete(Debt debt) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmDeleteSheet(name: debt.name),
      ),
    );
    if (ok == true && mounted) {
      try {
        await _repo.deleteDebt(debt.id);
        NotificationHelper.show(
            message: 'Deuda eliminada', type: NotificationType.success);
      } catch (_) {
        NotificationHelper.show(
            message: 'Error al eliminar', type: NotificationType.error);
      }
    }
  }

  Future<void> _share(Debt debt) async {
    if (_isSharing) return;
    setState(() { _debtToShare = debt; _isSharing = true; });
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final boundary = _shareKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Boundary no encontrado.');
      final image  = await boundary.toImage(pixelRatio: 2.0);
      final bytes  = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception('Sin bytes.');
      final dir  = await getTemporaryDirectory();
      final file = await File('${dir.path}/debt_summary.png').create();
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)],
          text: 'Progreso con: ${debt.name}');
    } catch (_) {
      if (mounted)
        NotificationHelper.show(
            message: 'No se pudo compartir', type: NotificationType.error);
    } finally {
      if (mounted) setState(() { _isSharing = false; _debtToShare = null; });
    }
  }

  void _onAction(DebtCardAction action, Debt debt) {
    switch (action) {
      case DebtCardAction.registerPayment: _goPayment(debt); break;
      case DebtCardAction.edit:            _goEdit(debt);    break;
      case DebtCardAction.delete:          _delete(debt);    break;
      case DebtCardAction.share:           _share(debt);     break;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(children: [
        // Widget de captura oculto fuera de pantalla
        if (_debtToShare != null)
          Positioned(
            top: -1921, left: 0,
            child: RepaintBoundary(
              key: _shareKey,
              child: Material(
                type: MaterialType.transparency,
                child: ShareableDebtSummary(debt: _debtToShare!),
              ),
            ),
          ),

        // UI principal
        Column(children: [
          _Header(
            statusBarHeight: statusH,
            bg: theme.scaffoldBackgroundColor,
            tabController: _tabs,
            onAdd: _goAdd,
          ),
          Expanded(
            child: StreamBuilder<List<Debt>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return _SkeletonLoader();
                }
                if (snap.hasError) {
                  return _ErrorState(error: snap.error.toString());
                }
                final all = snap.data ?? [];
                if (all.isEmpty) return _EmptyState(onAdd: _goAdd);

                final myDebts = all.where((d) => d.type == DebtType.debt).toList();
                final loans   = all.where((d) => d.type == DebtType.loan).toList();

                return TabBarView(
                  controller: _tabs,
                  children: [
                    _DebtTab(debts: myDebts,  type: DebtType.debt, onAction: _onAction, onAdd: _goAdd),
                    _DebtTab(debts: loans,    type: DebtType.loan, onAction: _onAction, onAdd: _goAdd),
                  ],
                );
              },
            ),
          ),
        ]),

        // Loading overlay — compacto, no pantalla completa
        if (_isSharing)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.30),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 22),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const SizedBox(
                      width: 26, height: 26,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: _kBlue),
                    ),
                    const SizedBox(height: 14),
                    Text('Generando imagen…',
                        style: _T.label(14,
                            c: theme.colorScheme.onSurface)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — blur + título DM Sans + TabBar iOS + botón pill
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double statusBarHeight;
  final Color  bg;
  final TabController tabController;
  final VoidCallback  onAdd;

  const _Header({
    required this.statusBarHeight, required this.bg,
    required this.tabController,  required this.onAdd,
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
                        Text('MIS FINANZAS',
                            style: _T.label(10,
                                w: FontWeight.w700,
                                c: onSurf.withOpacity(0.35))),
                        Text('Deudas',
                            style: _T.display(28, c: onSurf)),
                      ],
                    ),
                  ),
                  _PillBtn(label: 'Nuevo', icon: Iconsax.add, onTap: onAdd),
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
                unselectedLabelColor: onSurf.withOpacity(0.4),
                tabs: const [
                  Tab(text: 'Yo debo'),
                  Tab(text: 'Me deben'),
                ],
              ),
            ],
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
  @override
  State<_PillBtn> createState() => _PillBtnState();
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
// DEBT TAB — un scroll continuo, sin tabs anidados
// Estructura: Summary bar → grupos activos → "HISTORIAL" → pagadas
// Igual que iOS Recordatorios / Reminders
// ─────────────────────────────────────────────────────────────────────────────

class _DebtTab extends StatelessWidget {
  final List<Debt> debts;
  final DebtType   type;
  final void Function(DebtCardAction, Debt) onAction;
  final VoidCallback onAdd;

  const _DebtTab({
    required this.debts, required this.type,
    required this.onAction, required this.onAdd,
  });

  Map<String, List<Debt>> _group(List<Debt> list) {
    final m = <String, List<Debt>>{};
    for (final d in list) {
      (m[d.entityName ?? 'Sin contacto'] ??= []).add(d);
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return _TabEmpty(type: type, onAdd: onAdd);

    final active  = debts.where((d) => d.status == DebtStatus.active).toList();
    final paid    = debts.where((d) => d.status == DebtStatus.paid).toList();
    final grouped = _group(active);
    final contacts = grouped.keys.toList()..sort();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        // Barra de resumen
        SliverToBoxAdapter(child: _SummaryBar(debts: active, type: type)),

        // Grupos activos por contacto
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(_T.h, 4, _T.h, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final delay = Duration(milliseconds: 50 + i * 55);
                return _ContactGroup(
                  contactName: contacts[i],
                  debts: grouped[contacts[i]]!,
                  type: type,
                  onAction: onAction,
                )
                    .animate()
                    .fadeIn(delay: delay,
                        duration: const Duration(milliseconds: 300))
                    .slideY(begin: 0.04, delay: delay,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic);
              },
              childCount: contacts.length,
            ),
          ),
        ),

        // Sección historial — discreta, al final
        if (paid.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(_T.h, 28, _T.h, 10),
              child: Text('HISTORIAL',
                  style: _T.label(11,
                      w: FontWeight.w700,
                      c: Theme.of(context)
                          .colorScheme.onSurface.withOpacity(0.35))),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(_T.h, 0, _T.h, 110),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _PaidRow(
                    debt: paid[i], type: type,
                    onAction: onAction, index: i),
                childCount: paid.length,
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
// SUMMARY BAR — número protagonista + dos secundarios + barra progreso
// Una sola superficie, sin gradientes ni bordes de color
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryBar extends StatelessWidget {
  final List<Debt> debts;
  final DebtType   type;
  const _SummaryBar({required this.debts, required this.type});

  @override
  Widget build(BuildContext context) {
    if (debts.isEmpty) return const SizedBox(height: 8);

    final onSurf   = Theme.of(context).colorScheme.onSurface;
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final cardBg   = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final color    = _debtColor(type);

    final total     = debts.fold<double>(0, (s, d) => s + d.initialAmount);
    final paid      = debts.fold<double>(0, (s, d) => s + d.paidAmount);
    final remaining = total - paid;
    final pct       = total > 0 ? (paid / total).clamp(0.0, 1.0) : 0.0;
    final barColor  = pct > 0.7 ? _kGreen : color;

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
            // Pendiente — protagonista
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == DebtType.debt ? 'Pendiente' : 'Por cobrar',
                    style: _T.label(11, c: onSurf.withOpacity(0.42)),
                  ),
                  const SizedBox(height: 3),
                  Text(_fmt.format(remaining),
                      style: _T.display(24, c: color)),
                ],
              ),
            ),
            Container(width: 0.5, height: 38,
                color: onSurf.withOpacity(0.10)),
            // Pagado
            Expanded(
              flex: 3,
              child: Column(children: [
                Text('Pagado',
                    style: _T.label(11, c: onSurf.withOpacity(0.42))),
                const SizedBox(height: 3),
                Text(_fmt.format(paid),
                    style: _T.mono(17, c: _kGreen)),
              ]),
            ),
            Container(width: 0.5, height: 38,
                color: onSurf.withOpacity(0.10)),
            // Total
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

          // Barra de progreso 4px
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Progreso de pago',
                    style: _T.label(11, c: onSurf.withOpacity(0.42))),
                Text('${(pct * 100).toStringAsFixed(1)}%',
                    style: _T.label(11, w: FontWeight.w700, c: barColor)),
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
                      color: barColor,
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
        .fadeIn(delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 320))
        .slideY(begin: 0.04, delay: const Duration(milliseconds: 60),
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONTACT GROUP — el contacto como protagonista
// Expandido por defecto → la información es visible de entrada
// AnimatedSize en lugar de AnimatedCrossFade → spring nativo iOS
// Sin border dinámico, sin boxShadow condicional, sin InkWell
// ─────────────────────────────────────────────────────────────────────────────

class _ContactGroup extends StatefulWidget {
  final String   contactName;
  final List<Debt> debts;
  final DebtType type;
  final void Function(DebtCardAction, Debt) onAction;

  const _ContactGroup({
    required this.contactName, required this.debts,
    required this.type,        required this.onAction,
  });

  @override
  State<_ContactGroup> createState() => _ContactGroupState();
}

class _ContactGroupState extends State<_ContactGroup>
    with SingleTickerProviderStateMixin {
  // Expandido por defecto — el usuario ve sin hacer tap
  bool _expanded = true;

  late final AnimationController _press =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 70));

  @override void dispose() { _press.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final color  = _debtColor(widget.type);

    final pending = widget.debts.fold<double>(
        0, (s, d) => s + (d.initialAmount - d.paidAmount)
            .clamp(0, double.infinity));

    return AnimatedBuilder(
      animation: _press,
      builder: (_, child) => Transform.scale(
          scale: lerpDouble(1.0, 0.99, _press.value)!, child: child),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(_T.r),
          // Sin border dinámico — la forma es siempre la misma
        ),
        child: Column(children: [
          // ── Header del contacto ──────────────────────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) { _press.forward(); HapticFeedback.selectionClick(); },
            onTapUp: (_) {
              _press.reverse();
              setState(() => _expanded = !_expanded);
            },
            onTapCancel: () => _press.reverse(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                // Avatar iOS: inicial + fondo semitransparente plano, sin gradiente
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(_T.ri),
                  ),
                  child: Center(
                    child: Text(widget.contactName[0].toUpperCase(),
                        style: _T.display(18, c: color)),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(widget.contactName,
                              style: _T.display(16,
                                  c: onSurf, w: FontWeight.w700),
                              overflow: TextOverflow.ellipsis),
                        ),
                        // Badge cantidad — sin primaryContainer
                        if (widget.debts.length > 1) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: onSurf.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('${widget.debts.length}',
                                style: _T.label(10,
                                    w: FontWeight.w700,
                                    c: onSurf.withOpacity(0.45))),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        pending > 0
                            ? 'Pendiente ${_fmtFull.format(pending)}'
                            : 'Todo pagado ✓',
                        style: _T.label(12,
                            c: pending > 0 ? color : _kGreen,
                            w: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

                // Chevron que rota — sin sombras que aparecen
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: Icon(Icons.keyboard_arrow_down_rounded,
                      size: 22, color: onSurf.withOpacity(0.30)),
                ),
              ]),
            ),
          ),

          // ── Lista de deudas con AnimatedSize — spring, no crossFade ──
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            child: _expanded
                ? Column(children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Divider(height: 0.5, thickness: 0.5,
                          color: onSurf.withOpacity(0.07)),
                    ),
                    ...widget.debts.asMap().entries.map((e) => _DebtRow(
                          debt: e.value,
                          type: widget.type,
                          isLast: e.key == widget.debts.length - 1,
                          onAction: widget.onAction,
                        )),
                  ])
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEBT ROW — una deuda dentro del grupo de contacto
// Fecha de vencimiento con color semántico (rojo/naranja/azul)
// Barra de progreso solo si hay progreso real (> 1%)
// Tap → action sheet iOS
// ─────────────────────────────────────────────────────────────────────────────

class _DebtRow extends StatefulWidget {
  final Debt   debt;
  final DebtType type;
  final bool   isLast;
  final void Function(DebtCardAction, Debt) onAction;

  const _DebtRow({
    required this.debt, required this.type,
    required this.isLast, required this.onAction,
  });

  @override
  State<_DebtRow> createState() => _DebtRowState();
}

class _DebtRowState extends State<_DebtRow>
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
          debt: widget.debt, type: widget.type, onAction: widget.onAction),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final color   = _debtColor(widget.type);
    final d       = widget.debt;
    final isPaid  = d.status == DebtStatus.paid;
    final pending = (d.initialAmount - d.paidAmount).clamp(0, double.infinity);
    final pct     = d.initialAmount > 0
        ? (d.paidAmount / d.initialAmount).clamp(0.0, 1.0)
        : 0.0;
    final barColor = pct > 0.7 ? _kGreen : color;

    return AnimatedBuilder(
      animation: _press,
      builder: (_, child) => Transform.scale(
          scale: lerpDouble(1.0, 0.98, _press.value)!, child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) { _press.forward(); HapticFeedback.selectionClick(); },
        onTapUp:   (_) { _press.reverse(); _openActions(); },
        onTapCancel: () => _press.reverse(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // Ícono de estado — sin gradiente
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: isPaid
                        ? _kGreen.withOpacity(0.12)
                        : color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPaid ? Iconsax.verify5 : Iconsax.receipt_item,
                    size: 16,
                    color: isPaid ? _kGreen : color,
                  ),
                ),
                const SizedBox(width: 10),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          style: _T.label(14,
                              w: FontWeight.w600,
                              c: isPaid ? onSurf.withOpacity(0.48) : onSurf)),
                      // Fecha de vencimiento con color semántico urgente
                      if (d.dueDate != null)
                        Row(children: [
                          Icon(Iconsax.calendar_1,
                              size: 10, color: _dueDateColor(d.dueDate!)),
                          const SizedBox(width: 3),
                          Text(
                            'Vence ${DateFormat.yMMMd('es_CO').format(d.dueDate!)}',
                            style: _T.label(10,
                                c: _dueDateColor(d.dueDate!)),
                          ),
                        ]),
                    ],
                  ),
                ),

                // Monto
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    isPaid ? 'Pagado' : _fmtFull.format(pending),
                    style: _T.mono(13, c: isPaid ? _kGreen : color),
                  ),
                  if (!isPaid && d.paidAmount > 0)
                    Text('de ${_fmt.format(d.initialAmount)}',
                        style: _T.label(10, c: onSurf.withOpacity(0.35))),
                ]),

                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: onSurf.withOpacity(0.20)),
              ]),

              // Barra de progreso 3px — solo si hay progreso visible
              if (!isPaid && pct > 0.01) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: Stack(children: [
                    Container(height: 3, color: color.withOpacity(0.12)),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAID ROW — historial: compacto y desaturado
// No compite visualmente con las deudas activas
// ─────────────────────────────────────────────────────────────────────────────

class _PaidRow extends StatelessWidget {
  final Debt   debt;
  final DebtType type;
  final void Function(DebtCardAction, Debt) onAction;
  final int    index;

  const _PaidRow({
    required this.debt, required this.type,
    required this.onAction, required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final delay  = Duration(milliseconds: 30 + index * 40);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: _ActionSheet(
                debt: debt, type: type, onAction: onAction),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          const Icon(Iconsax.verify5, size: 15, color: _kGreen),
          const SizedBox(width: 10),
          Expanded(
            child: Text(debt.name,
                style: _T.label(14,
                    c: onSurf.withOpacity(0.48), w: FontWeight.w400)),
          ),
          Text(_fmt.format(debt.initialAmount),
              style: _T.mono(12, c: onSurf.withOpacity(0.38))),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded,
              size: 15, color: onSurf.withOpacity(0.17)),
        ]),
      ),
    )
        .animate()
        .fadeIn(delay: delay, duration: const Duration(milliseconds: 260));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION SHEET — estilo iOS nativo con blur
// Todas las acciones desde aquí: pago, editar, compartir, eliminar
// ─────────────────────────────────────────────────────────────────────────────

class _ActionSheet extends StatelessWidget {
  final Debt   debt;
  final DebtType type;
  final void Function(DebtCardAction, Debt) onAction;

  const _ActionSheet({
    required this.debt, required this.type, required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.white.withOpacity(0.92);
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final isPaid  = debt.status == DebtStatus.paid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: onSurf.withOpacity(0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Nombre como subtítulo
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(debt.name,
                style: _T.label(13,
                    c: onSurf.withOpacity(0.42), w: FontWeight.w400)),
          ),
          // Acciones
          Container(
            decoration: BoxDecoration(
              color: sheetBg, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              if (!isPaid)
                _SheetRow(
                  icon: Iconsax.card_add, label: 'Registrar pago',
                  color: _kBlue, isFirst: true,
                  onTap: () { Navigator.pop(context);
                      onAction(DebtCardAction.registerPayment, debt); },
                ),
              _SheetRow(
                icon: Iconsax.edit, label: 'Editar',
                isFirst: isPaid,
                onTap: () { Navigator.pop(context);
                    onAction(DebtCardAction.edit, debt); },
              ),
              _SheetRow(
                icon: Iconsax.share, label: 'Compartir resumen',
                onTap: () { Navigator.pop(context);
                    onAction(DebtCardAction.share, debt); },
              ),
              _SheetRow(
                icon: Iconsax.trash, label: 'Eliminar',
                isLast: true, isDestructive: true,
                onTap: () { Navigator.pop(context);
                    onAction(DebtCardAction.delete, debt); },
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
  final IconData   icon;
  final String     label;
  final Color?     color;
  final bool       isFirst, isLast, isDestructive;
  final VoidCallback onTap;

  const _SheetRow({
    required this.icon, required this.label, required this.onTap,
    this.color, this.isFirst = false, this.isLast = false,
    this.isDestructive = false,
  });

  @override
  State<_SheetRow> createState() => _SheetRowState();
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
              topLeft: topR, topRight: topR,
              bottomLeft: botR, bottomRight: botR,
            ),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
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

// ── Botón cancelar del sheet ──────────────────────────────────────────────────

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
            child: Center(
              child: Text('Cancelar',
                  style: _T.label(16, w: FontWeight.w600, c: _kBlue)),
            ),
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
  final String name;
  const _ConfirmDeleteSheet({required this.name});

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
              Text('Eliminar deuda', style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '"$name"\nEsta acción no se puede deshacer.',
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
  final String     label;
  final Color      color;
  final bool       impact;
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
            child: Center(
              child: Text(widget.label,
                  style: _T.label(15, w: FontWeight.w600, c: widget.color)),
            ),
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
          Lottie.asset('assets/animations/add_item_animation.json',
              width: 200, height: 200),
          const SizedBox(height: 20),
          Text('Todo en orden', style: _T.display(24, c: onSurf)),
          const SizedBox(height: 10),
          Text(
            'No tienes deudas ni préstamos.\nMantén el control de tus finanzas.',
            textAlign: TextAlign.center,
            style: _T.label(15,
                c: onSurf.withOpacity(0.45), w: FontWeight.w400),
          ),
          const SizedBox(height: 28),
          _PillBtn(label: 'Añadir deuda', icon: Iconsax.add_circle, onTap: onAdd),
        ]),
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 400))
        .scale(begin: const Offset(0.96, 0.96),
            delay: const Duration(milliseconds: 80),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
  }
}

class _TabEmpty extends StatelessWidget {
  final DebtType type;
  final VoidCallback onAdd;
  const _TabEmpty({required this.type, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDebt = type == DebtType.debt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(
            isDebt ? Iconsax.shield_tick : Iconsax.money_send,
            size: 56, color: onSurf.withOpacity(0.14),
          ),
          const SizedBox(height: 18),
          Text(isDebt ? '¡Sin deudas!' : '¡Nadie te debe!',
              style: _T.display(22, c: onSurf)),
          const SizedBox(height: 10),
          Text(
            isDebt
                ? 'Aquí aparecerán los préstamos\nque recibas.'
                : 'Cuando le prestes a alguien,\naparecerá aquí.',
            textAlign: TextAlign.center,
            style: _T.label(14,
                c: onSurf.withOpacity(0.45), w: FontWeight.w400),
          ),
          const SizedBox(height: 24),
          _PillBtn(
            label: isDebt ? 'Añadir deuda' : 'Añadir préstamo',
            icon: Iconsax.add_circle,
            onTap: onAdd,
          ),
        ]),
      ),
    ).animate().fadeIn(duration: const Duration(milliseconds: 350));
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

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
          height: 90,
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