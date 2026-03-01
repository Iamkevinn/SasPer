// lib/screens/transactions_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Movimientos — diseño Apple-first
// Filosofía: máxima densidad de información útil, mínimo ruido visual.
// Búsqueda y escaneo rápido como iOS Messages o Spotlight.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:sasper/config/app_constants.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/main.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
class _T {
  static TextStyle display(double s, {Color? c, FontWeight w = FontWeight.w700}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c, letterSpacing: -0.4);
  static TextStyle label(double s, {Color? c, FontWeight w = FontWeight.w500}) =>
      GoogleFonts.dmSans(fontSize: s, fontWeight: w, color: c);
  static TextStyle mono(double s, {Color? c, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmMono(fontSize: s, fontWeight: w, color: c);

  static const h  = 20.0;
  static const r  = 16.0;
}

const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

// ── Filtros de tiempo ─────────────────────────────────────────────────────────
enum _TimeFilter { today, week, month, all }

extension _TimeFilterX on _TimeFilter {
  String get label {
    switch (this) {
      case _TimeFilter.today: return 'Hoy';
      case _TimeFilter.week:  return 'Semana';
      case _TimeFilter.month: return 'Mes';
      case _TimeFilter.all:   return 'Todos';
    }
  }

  DateTimeRange? get range {
    final now = DateTime.now();
    switch (this) {
      case _TimeFilter.today:
        return DateTimeRange(
            start: DateTime(now.year, now.month, now.day), end: now);
      case _TimeFilter.week:
        final start = now.subtract(Duration(days: now.weekday - 1));
        return DateTimeRange(
            start: DateTime(start.year, start.month, start.day), end: now);
      case _TimeFilter.month:
        return DateTimeRange(
            start: DateTime(now.year, now.month, 1), end: now);
      case _TimeFilter.all:
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _repo = TransactionRepository.instance;

  // Stream inicializado en declaración para evitar LateInitializationError
  late Stream<List<Transaction>> _stream = _repo.getTransactionsStream();

  StreamSubscription<AppEvent>? _eventSub;

  // Estado de búsqueda y filtros
  final _searchCtrl = TextEditingController();
  String _query          = '';
  _TimeFilter _timeFilter = _TimeFilter.all;
  List<String> _categories    = [];
  DateTimeRange? _customRange;
  bool _searchExpanded   = false;

  // Debounce para búsqueda
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onType);
    _eventSub = EventService.instance.eventStream.listen((event) {
      const refreshable = {
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted,
        AppEvent.transactionsChanged,
      };
      if (refreshable.contains(event) && !_hasFilters) {
        _repo.refreshData();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.removeListener(_onType);
    _searchCtrl.dispose();
    _eventSub?.cancel();
    super.dispose();
  }

  // ── Filtros ────────────────────────────────────────────────────────────────

  bool get _hasFilters =>
      _query.isNotEmpty ||
      _categories.isNotEmpty ||
      _customRange != null ||
      _timeFilter != _TimeFilter.all;

  int get _filterCount {
    int n = 0;
    if (_query.isNotEmpty)      n++;
    if (_categories.isNotEmpty) n++;
    if (_customRange != null)   n++;
    if (_timeFilter != _TimeFilter.all) n++;
    return n;
  }

  void _onType() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted && _searchCtrl.text != _query) {
        _query = _searchCtrl.text;
        _applyFilters();
      }
    });
  }

  void _applyFilters() {
    final range = _customRange ?? _timeFilter.range;
    setState(() {
      if (!_hasFilters) {
        _stream = _repo.getTransactionsStream();
      } else {
        _stream = _repo
            .getFilteredTransactions(
              searchQuery: _query,
              categoryFilter: _categories.isNotEmpty ? _categories : null,
              dateRange: range,
            )
            .asStream();
      }
    });
  }

  void _reset() {
    _debounce?.cancel();
    setState(() {
      _query          = '';
      _timeFilter     = _TimeFilter.all;
      _categories     = [];
      _customRange    = null;
      _searchExpanded = false;
      _searchCtrl.clear();
      _stream = _repo.getTransactionsStream();
    });
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _query = '';
        _searchCtrl.clear();
        _applyFilters();
      }
    });
  }

  void _setTimeFilter(_TimeFilter f) {
    HapticFeedback.selectionClick();
    setState(() {
      _timeFilter  = f;
      _customRange = null;
    });
    _applyFilters();
  }

  // ── Navegación ─────────────────────────────────────────────────────────────

  void _goEdit(Transaction t) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditTransactionScreen(transaction: t)),
    );
    if (ok == true && mounted) _repo.refreshData();
  }

  Future<bool> _confirmDelete(Transaction t) async {
    final ok = await showModalBottomSheet<bool>(
      context: navigatorKey.currentContext!,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _DeleteSheet(description: t.description ?? ''),
      ),
    );
    if (ok == true) {
      try {
        await _repo.deleteTransaction(t.id);
        EventService.instance.fire(AppEvent.transactionDeleted);
        if (mounted) {
          NotificationHelper.show(
              message: 'Movimiento eliminado',
              type: NotificationType.success);
        }
        return true;
      } catch (_) {
        if (mounted) {
          NotificationHelper.show(
              message: 'Error al eliminar',
              type: NotificationType.error);
        }
      }
    }
    return false;
  }

  void _openFilterSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _FilterSheet(
          selectedCategories: List.from(_categories),
          selectedDateRange: _customRange,
          onApply: (cats, range) {
            setState(() {
              _categories  = cats;
              _customRange = range;
            });
            _applyFilters();
          },
          onClear: _reset,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme   = Theme.of(context);
    final statusH = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          _Header(
            statusBarHeight: statusH,
            bg: theme.scaffoldBackgroundColor,
            hasFilters: _hasFilters,
            filterCount: _filterCount,
            searchExpanded: _searchExpanded,
            searchCtrl: _searchCtrl,
            onSearch: _toggleSearch,
            onFilter: _openFilterSheet,
          ),

          // ── Segmented control de tiempo ──────────────────────────────
          _TimeSegment(
            selected: _timeFilter,
            onChanged: _setTimeFilter,
          ),

          // ── Chips de filtros activos ─────────────────────────────────
          if (_hasFilters && (_categories.isNotEmpty || _customRange != null || _query.isNotEmpty))
            _ActiveFiltersRow(
              query:      _query,
              categories: _categories,
              dateRange:  _customRange,
              onClear:    _reset,
              onRemoveQuery:      () { setState(() { _query = ''; _searchCtrl.clear(); }); _applyFilters(); },
              onRemoveCategories: () { setState(() => _categories = []); _applyFilters(); },
              onRemoveDate:       () { setState(() => _customRange = null); _applyFilters(); },
            )
                .animate()
                .fadeIn(duration: 200.ms)
                .slideY(begin: -0.08, curve: Curves.easeOutCubic),

          // ── Lista ────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Transaction>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return _SkeletonLoader();
                }
                if (snap.hasError) {
                  return _ErrorState(
                      error: snap.error.toString(),
                      onRetry: _repo.refreshData);
                }
                final txns = snap.data ?? [];
                if (txns.isEmpty) {
                  return _EmptyState(
                      hasFilters: _hasFilters, onClear: _reset);
                }
                return _TransactionList(
                  transactions: txns,
                  onTap: _goEdit,
                  onDelete: _confirmDelete,
                  onRefresh: _repo.refreshData,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER — blur, título compresible, búsqueda inline que se expande
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final double statusBarHeight;
  final Color bg;
  final bool hasFilters, searchExpanded;
  final int filterCount;
  final TextEditingController searchCtrl;
  final VoidCallback onSearch, onFilter;

  const _Header({
    required this.statusBarHeight, required this.bg,
    required this.hasFilters, required this.filterCount,
    required this.searchExpanded, required this.searchCtrl,
    required this.onSearch, required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: bg.withOpacity(0.93),
          padding: EdgeInsets.only(
            top: statusBarHeight + 10,
            left: _T.h + 4, right: _T.h, bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila título ──────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (!searchExpanded) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('MOVIMIENTOS',
                              style: _T.label(10, w: FontWeight.w700,
                                  c: onSurf.withOpacity(0.35))),
                          Text('Historial',
                              style: _T.display(28, c: onSurf)),
                        ],
                      ),
                    ),
                    // Botón de filtro con badge
                    _HeaderBtn(
                      onTap: onFilter,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(Iconsax.setting_4, size: 19,
                              color: onSurf.withOpacity(0.65)),
                          if (hasFilters)
                            Positioned(
                              top: -3, right: -3,
                              child: Container(
                                width: 8, height: 8,
                                decoration: const BoxDecoration(
                                  color: _kBlue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón de búsqueda
                    _HeaderBtn(
                      onTap: onSearch,
                      child: Icon(Iconsax.search_normal_1, size: 19,
                          color: onSurf.withOpacity(0.65)),
                    ),
                  ] else ...[
                    // Campo de búsqueda expandido
                    Expanded(
                      child: _SearchField(
                        controller: searchCtrl,
                        onClose: onSearch,
                      )
                          .animate()
                          .fadeIn(duration: 200.ms)
                          .slideX(begin: 0.05, curve: Curves.easeOutCubic),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBtn extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _HeaderBtn({required this.onTap, required this.child});
  @override State<_HeaderBtn> createState() => _HeaderBtnState();
}
class _HeaderBtnState extends State<_HeaderBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 70));
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
          scale: lerpDouble(1.0, 0.86, _c.value)!,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Campo de búsqueda ─────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  const _SearchField({required this.controller, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final onSurf   = Theme.of(context).colorScheme.onSurface;
    final fieldBg  = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);

    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: fieldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: controller,
              autofocus: true,
              style: _T.label(15, c: onSurf),
              decoration: InputDecoration(
                hintText: 'Buscar movimientos...',
                hintStyle: _T.label(15, c: onSurf.withOpacity(0.35)),
                prefixIcon: Icon(Iconsax.search_normal_1,
                    size: 17, color: onSurf.withOpacity(0.4)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 11),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onClose,
          child: Text('Cancelar',
              style: _T.label(14, w: FontWeight.w600, c: _kBlue)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIME SEGMENT — segmented control iOS-style
// ─────────────────────────────────────────────────────────────────────────────

class _TimeSegment extends StatelessWidget {
  final _TimeFilter selected;
  final ValueChanged<_TimeFilter> onChanged;
  const _TimeSegment({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final trackBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.05);

    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 6, _T.h, 6),
      child: Container(
        height: 36,
        decoration: BoxDecoration(
          color: trackBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: _TimeFilter.values.map((f) {
            final isSelected = f == selected;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark ? Colors.white.withOpacity(0.15) : Colors.white)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      f.label,
                      style: _T.label(13,
                          w: isSelected ? FontWeight.w700 : FontWeight.w400,
                          c: isSelected ? onSurf : onSurf.withOpacity(0.45)),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVE FILTERS ROW — chips removibles discretos
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveFiltersRow extends StatelessWidget {
  final String query;
  final List<String> categories;
  final DateTimeRange? dateRange;
  final VoidCallback onClear, onRemoveQuery, onRemoveCategories, onRemoveDate;

  const _ActiveFiltersRow({
    required this.query, required this.categories, required this.dateRange,
    required this.onClear, required this.onRemoveQuery,
    required this.onRemoveCategories, required this.onRemoveDate,
  });

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 0, _T.h, 6),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  if (query.isNotEmpty)
                    _FilterPill(
                      icon: Iconsax.search_normal_1,
                      label: '"$query"',
                      onRemove: onRemoveQuery,
                    ),
                  if (categories.isNotEmpty)
                    _FilterPill(
                      icon: Iconsax.category,
                      label: '${categories.length} categoría${categories.length > 1 ? "s" : ""}',
                      onRemove: onRemoveCategories,
                    ),
                  if (dateRange != null)
                    _FilterPill(
                      icon: Iconsax.calendar_1,
                      label: '${DateFormat.MMMd('es').format(dateRange!.start)} – ${DateFormat.MMMd('es').format(dateRange!.end)}',
                      onRemove: onRemoveDate,
                    ),
                ],
              ),
            ),
          ),
          // Limpiar todo
          GestureDetector(
            onTap: onClear,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('Limpiar',
                  style: _T.label(12, w: FontWeight.w600, c: _kBlue)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  const _FilterPill({required this.icon, required this.label, required this.onRemove});
  @override State<_FilterPill> createState() => _FilterPillState();
}
class _FilterPillState extends State<_FilterPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 65));
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp:   (_) { _c.reverse(); widget.onRemove(); },
      onTapCancel: () => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Transform.scale(
          scale: lerpDouble(1.0, 0.94, _c.value)!,
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kBlue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, size: 12, color: _kBlue),
              const SizedBox(width: 5),
              Text(widget.label,
                  style: _T.label(11, w: FontWeight.w600, c: _kBlue)),
              const SizedBox(width: 5),
              Icon(Icons.close_rounded, size: 12, color: _kBlue.withOpacity(0.7)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSACTION LIST — agrupada por fecha, header de fecha nativo iOS
// ─────────────────────────────────────────────────────────────────────────────

class _TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final void Function(Transaction) onTap;
  final Future<bool> Function(Transaction) onDelete;
  final Future<void> Function() onRefresh;

  const _TransactionList({
    required this.transactions,
    required this.onTap,
    required this.onDelete,
    required this.onRefresh,
  });

  // Agrupa las transacciones por fecha (día)
  List<(DateTime, List<Transaction>)> _group() {
    final map = <DateTime, List<Transaction>>{};
    for (final t in transactions) {
      final day = DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
      (map[day] ??= []).add(t);
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));
    return sorted.map((e) => (e.key, e.value)).toList();
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (day == today)     return 'Hoy';
    if (day == yesterday) return 'Ayer';
    return DateFormat.yMMMEd('es_CO').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final groups = _group();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kBlue,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          for (int gi = 0; gi < groups.length; gi++) ...[
            // ── Header de fecha ────────────────────────────────────────
            SliverToBoxAdapter(
              child: _DayHeader(
                label: _dayLabel(groups[gi].$1),
                transactions: groups[gi].$2,
                groupIndex: gi,
              ),
            ),

            // ── Tarjeta de grupo ───────────────────────────────────────
            SliverToBoxAdapter(
              child: _DayGroup(
                transactions: groups[gi].$2,
                groupIndex: gi,
                onTap: onTap,
                onDelete: onDelete,
              ),
            ),
          ],

          // Espacio inferior
          const SliverToBoxAdapter(
            child: SizedBox(height: 110),
          ),
        ],
      ),
    );
  }
}

// ── Helper: detecta si un tipo de transacción es ingreso ─────────────────────
// Cubre español, inglés y variantes comunes usadas en Supabase/Flutter apps.
bool _isIncome(String type) {
  switch (type.toLowerCase().trim()) {
    case 'ingreso':
    case 'ingresos':
    case 'income':
    case 'entrada':
    case 'entradas':
    case 'credit':
    case 'crédito':
    case 'credito':
    case 'deposit':
    case 'depósito':
    case 'deposito':
      return true;
    default:
      return false;
  }
}

// ── Header de día con total neto ──────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  final String label;
  final List<Transaction> transactions;
  final int groupIndex;
  const _DayHeader({required this.label, required this.transactions, required this.groupIndex});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;

    // Calcula el neto del día.
    // _isIncome() cubre todos los strings que apps de finanzas usan para ingresos.
    // Todo lo demás (gastos, transferencias, ajustes) resta.
    double income  = 0;
    double expense = 0;
    // Los gastos se almacenan como negativos en la BD, ingresos como positivos.
    // Usamos .abs() para normalizar — el signo lo determina exclusivamente el type.
    for (final t in transactions) {
      if (_isIncome(t.type)) {
        income += t.amount.abs();
      } else {
        expense += t.amount.abs();
      }
    }
    // net > 0 → día positivo (ingresó más de lo que gastó)
    // net < 0 → día negativo (gastó más de lo que ingresó)
    // net = 0 → equilibrado
    final net    = income - expense;
    final absNet = net.abs();
    final fmt    = NumberFormat.compactCurrency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    // Signo y color semántico
    final isPositive = net > 0;
    final isZero     = net == 0;
    final netLabel   = isZero
        ? fmt.format(0)
        : '${isPositive ? "+" : "-"}${fmt.format(absNet)}';
    final netColor   = isPositive
        ? _kGreen.withOpacity(0.85)
        : isZero
            ? onSurf.withOpacity(0.35)
            : _kRed.withOpacity(0.85);

    final delay = Duration(milliseconds: 40 + groupIndex * 30);

    return Padding(
      padding: const EdgeInsets.fromLTRB(_T.h, 16, _T.h, 6),
      child: Row(
        children: [
          Text(label,
              style: _T.label(12, w: FontWeight.w700,
                  c: onSurf.withOpacity(0.42))),
          const Spacer(),
          // Neto del día — verde si ganó, rojo si gastó, neutro si equilibrado
          Text(
            netLabel,
            style: _T.mono(12, c: netColor),
          ),
        ],
      ),
    )
    .animate()
    .fadeIn(delay: delay, duration: const Duration(milliseconds: 280));
  }
}

// ── Grupo de tarjetas del día ─────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final List<Transaction> transactions;
  final int groupIndex;
  final void Function(Transaction) onTap;
  final Future<bool> Function(Transaction) onDelete;

  const _DayGroup({
    required this.transactions, required this.groupIndex,
    required this.onTap, required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);
    final onSurf    = Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _T.h),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(_T.r),
        ),
        child: Column(
          children: transactions.asMap().entries.map((e) {
            final i    = e.key;
            final t    = e.value;
            final isLast = i == transactions.length - 1;
            final delay  = Duration(milliseconds: 50 + groupIndex * 35 + i * 25);

            return Column(
              children: [
                // Swipe to delete (iOS-style)
                Dismissible(
                  key: Key(t.id.toString()),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => onDelete(t),
                  background: _SwipeDeleteBg(
                    isFirst: i == 0,
                    isLast: isLast,
                    cardColor: cardColor,
                  ),
                  child: TransactionTile(
                    transaction: t,
                    onTap: () => onTap(t),
                    onDeleted: () => onDelete(t),
                  ),
                )
                .animate()
                .fadeIn(delay: delay, duration: const Duration(milliseconds: 300))
                .slideX(begin: 0.04, delay: delay,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic),

                if (!isLast)
                  Padding(
                    padding: const EdgeInsets.only(left: 64),
                    child: Divider(
                      height: 0.5, thickness: 0.5,
                      color: onSurf.withOpacity(0.07),
                    ),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── Fondo de swipe delete ─────────────────────────────────────────────────────

class _SwipeDeleteBg extends StatelessWidget {
  final bool isFirst, isLast;
  final Color cardColor;
  const _SwipeDeleteBg({
    required this.isFirst, required this.isLast,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    final topR    = isFirst ? Radius.circular(_T.r)  : Radius.zero;
    final bottomR = isLast  ? Radius.circular(_T.r)  : Radius.zero;
    return Container(
      decoration: BoxDecoration(
        color: _kRed.withOpacity(0.12),
        borderRadius: BorderRadius.only(
          topLeft: topR, topRight: topR,
          bottomLeft: bottomR, bottomRight: bottomR,
        ),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Iconsax.trash, size: 20, color: _kRed),
          const SizedBox(height: 4),
          Text('Eliminar', style: _T.label(10, w: FontWeight.w700, c: _kRed)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FILTER SHEET — bottom sheet con blur, lista de categorías limpia
// ─────────────────────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final List<String> selectedCategories;
  final DateTimeRange? selectedDateRange;
  final void Function(List<String>, DateTimeRange?) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.selectedCategories, required this.selectedDateRange,
    required this.onApply, required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late List<String> _cats;
  DateTimeRange?    _range;

  @override
  void initState() {
    super.initState();
    _cats  = List.from(widget.selectedCategories);
    _range = widget.selectedDateRange;
  }

  List<String> get _allCategories => ({
    ...AppConstants.expenseCategories.keys,
    ...AppConstants.incomeCategories.keys,
  }.toList()..sort());

  Future<void> _pickDate() async {
    final r = await showDateRangePicker(
      context: context,
      initialDateRange: _range,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es'),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx),
        child: child!,
      ),
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final onSurf   = theme.colorScheme.onSurface;
    final isDark   = theme.brightness == Brightness.dark;
    final sheetBg  = isDark
        ? theme.scaffoldBackgroundColor.withOpacity(0.95)
        : Colors.white.withOpacity(0.96);

    final activeCatsCount = _cats.length;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        builder: (_, scroll) => Column(
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: onSurf.withOpacity(0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header del sheet
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _T.h),
              child: Row(children: [
                Text('Filtros', style: _T.display(22, c: onSurf)),
                const Spacer(),
                if (_cats.isNotEmpty || _range != null)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() { _cats = []; _range = null; });
                    },
                    child: Text('Limpiar',
                        style: _T.label(14, w: FontWeight.w600, c: _kBlue)),
                  ),
              ]),
            ),

            const SizedBox(height: 16),

            // Rango de fechas
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _T.h),
              child: _DateRangeRow(
                dateRange: _range,
                onTap: _pickDate,
                onClear: () => setState(() => _range = null),
              ),
            ),

            const SizedBox(height: 20),

            // Label categorías
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _T.h),
              child: Row(children: [
                Text('CATEGORÍAS',
                    style: _T.label(11, w: FontWeight.w700,
                        c: onSurf.withOpacity(0.38))),
                if (activeCatsCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kBlue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$activeCatsCount',
                        style: _T.label(10, w: FontWeight.w700, c: _kBlue)),
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 10),

            // Lista de categorías
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: _T.h),
                itemCount: _allCategories.length,
                itemBuilder: (_, i) {
                  final cat      = _allCategories[i];
                  final selected = _cats.contains(cat);
                  return _CategoryRow(
                    label: cat,
                    selected: selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        selected ? _cats.remove(cat) : _cats.add(cat);
                      });
                    },
                  );
                },
              ),
            ),

            // Botones de acción
            _SheetActions(
              onApply: () {
                Navigator.pop(context);
                widget.onApply(_cats, _range);
              },
              onCancel: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRangeRow extends StatelessWidget {
  final DateTimeRange? dateRange;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _DateRangeRow({required this.dateRange, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final hasDate = dateRange != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: hasDate ? _kBlue.withOpacity(0.08) : bg,
          borderRadius: BorderRadius.circular(12),
          border: hasDate
              ? Border.all(color: _kBlue.withOpacity(0.25))
              : null,
        ),
        child: Row(children: [
          Icon(Iconsax.calendar_1, size: 18,
              color: hasDate ? _kBlue : onSurf.withOpacity(0.5)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasDate
                  ? '${DateFormat.yMMMd('es').format(dateRange!.start)} – ${DateFormat.yMMMd('es').format(dateRange!.end)}'
                  : 'Rango de fechas',
              style: _T.label(14,
                  c: hasDate ? _kBlue : onSurf.withOpacity(0.55)),
            ),
          ),
          if (hasDate)
            GestureDetector(
              onTap: onClear,
              child: Icon(Icons.close_rounded,
                  size: 17, color: _kBlue.withOpacity(0.7)),
            )
          else
            Icon(Icons.chevron_right_rounded,
                size: 18, color: onSurf.withOpacity(0.3)),
        ]),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryRow({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Row(children: [
          // Checkmark iOS-style
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: selected ? _kBlue : Colors.transparent,
              border: Border.all(
                color: selected ? _kBlue : onSurf.withOpacity(0.22),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: selected
                ? const Icon(Icons.check_rounded,
                    size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 12),
          Text(label,
              style: _T.label(15,
                  w: selected ? FontWeight.w600 : FontWeight.w400,
                  c: onSurf)),
        ]),
        // Padding visual entre filas
      ).pD(vertical: 11),
    );
  }
}

extension on Widget {
  Widget pD({double vertical = 0, double horizontal = 0}) => Padding(
    padding: EdgeInsets.symmetric(vertical: vertical, horizontal: horizontal),
    child: this,
  );
}

class _SheetActions extends StatelessWidget {
  final VoidCallback onApply, onCancel;
  const _SheetActions({required this.onApply, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg     = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.fromLTRB(_T.h, 12, _T.h, 28),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(isDark ? 0.9 : 0.95),
        border: Border(top: BorderSide(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
        )),
      ),
      child: Row(children: [
        Expanded(
          child: _ActionBtn(
            label: 'Cancelar',
            color: theme.colorScheme.onSurface,
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _ActionBtn(
            label: 'Aplicar filtros',
            color: _kBlue,
            filled: true,
            onTap: onApply,
          ),
        ),
      ]),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final Color color;
  final bool filled;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color,
      this.filled = false, required this.onTap});
  @override State<_ActionBtn> createState() => _ActionBtnState();
}
class _ActionBtnState extends State<_ActionBtn>
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
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.filled
                  ? widget.color
                  : widget.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(widget.label,
                  style: _T.label(15, w: FontWeight.w600,
                      c: widget.filled ? Colors.white : widget.color)),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELETE SHEET — confirmar eliminación
// ─────────────────────────────────────────────────────────────────────────────

class _DeleteSheet extends StatelessWidget {
  final String description;
  const _DeleteSheet({required this.description});

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
              Text('Eliminar movimiento',
                  style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '"$description"\nEsta acción no se puede deshacer.',
                textAlign: TextAlign.center,
                style: _T.label(14, c: onSurf.withOpacity(0.48),
                    w: FontWeight.w400),
              ),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _InlineBtn(
                  label: 'Cancelar', color: onSurf,
                  onTap: () => Navigator.pop(context, false),
                )),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                  label: 'Eliminar', color: _kRed, impact: true,
                  onTap: () => Navigator.pop(context, true),
                )),
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
  final Color color;
  final bool impact;
  final VoidCallback onTap;
  const _InlineBtn({required this.label, required this.color,
      required this.onTap, this.impact = false});
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
// ESTADOS
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  const _EmptyState({required this.hasFilters, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Lottie.asset('assets/animations/empty_box.json',
              width: 200, height: 200),
          const SizedBox(height: 20),
          Text(hasFilters ? 'Sin resultados' : 'Sin movimientos',
              style: _T.display(22, c: onSurf)),
          const SizedBox(height: 10),
          Text(
            hasFilters
                ? 'No hay movimientos con estos filtros.\nIntenta ajustarlos.'
                : 'Aún no tienes movimientos.\n¡Agrega tu primera transacción!',
            textAlign: TextAlign.center,
            style: _T.label(15, c: onSurf.withOpacity(0.45),
                w: FontWeight.w400),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: _kBlue.withOpacity(0.11),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text('Limpiar filtros',
                    style: _T.label(14, w: FontWeight.w600, c: _kBlue)),
              ),
            ),
          ],
        ]),
      ),
    )
    .animate()
    .fadeIn(duration: const Duration(milliseconds: 400));
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
              style: _T.label(13, c: onSurf.withOpacity(0.42),
                  w: FontWeight.w400)),
          const SizedBox(height: 22),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 22, vertical: 12),
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
    final bg     = isDark ? Colors.white12 : Colors.black12;
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(_T.h, 8, _T.h, 20),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 64,
          margin: const EdgeInsets.only(bottom: 2),
          color: bg,
        ),
      ),
    );
  }
}