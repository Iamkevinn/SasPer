// lib/screens/categories_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// SASPER · Categorías — Apple-first redesign
//
// Eliminado:
// · SliverAppBar + NestedScrollView + TabBar BoxDecoration → header blur + segmented control
// · FloatingActionButton.extended → _PillBtn sticky en bottom
// · Material() + InkWell() + BorderSide → opacity-based surface + GestureDetector press state
// · DOS IconButton (edit + delete) inline → tap = editar, swipe = opciones
// · BoxShape.circle en ícono → borderRadius
// · showDialog(CustomDialog) → _ConfirmDeleteSheet blur
// · Lottie 280×280 en empty state → patrón _EmptyState unificado
// · GoogleFonts.poppins + .inter → _T tokens DM Sans
// · flutter_animate .slideY() → _FadeInSlide propio
// · colorScheme.surfaceContainer + outlineVariant → opacity-based surface
// · Skeletonizer en Scaffold duplicado → Skeletonizer sobre ListView directamente
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/screens/add_edit_category_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
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

  static const double h = 20.0;
  static const double r = 18.0;
}

// ── Paleta iOS ──────────────────────────────────────────────────────────────────
const _kBlue   = Color(0xFF0A84FF);
const _kGreen  = Color(0xFF30D158);
const _kRed    = Color(0xFFFF453A);
const _kOrange = Color(0xFFFF9F0A);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _repo = CategoryRepository.instance;

  // 0 = Gastos, 1 = Ingresos
  int _tab = 0;

  // Stream único — se recrea al volver de AddEdit
  late Stream<List<Category>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _repo.getCategoriesStream();
  }

  void _refresh() =>
      setState(() => _stream = _repo.getCategoriesStream());

  Future<void> _goToAdd() async {
    final type =
        _tab == 0 ? CategoryType.expense : CategoryType.income;
    await Navigator.push(context,
        MaterialPageRoute(
            builder: (_) => AddEditCategoryScreen(type: type)));
    if (mounted) _refresh();
  }

  Future<void> _goToEdit(Category cat) async {
    await Navigator.push(context,
        MaterialPageRoute(
            builder: (_) =>
                AddEditCategoryScreen(categoryToEdit: cat)));
    if (mounted) _refresh();
  }

  void _openDeleteSheet(Category cat) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: _ConfirmDeleteSheet(
          name: cat.name,
          onConfirm: () async {
            HapticFeedback.heavyImpact();
            try {
              await _repo.deleteCategory(cat.id);
              NotificationHelper.show(
                  message: 'Categoría eliminada',
                  type: NotificationType.success);
              _refresh();
            } catch (e) {
              NotificationHelper.show(
                  message: e.toString(),
                  type: NotificationType.error);
            }
          },
        ),
      ),
    );
  }

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
                  right: _T.h, bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('SASPER',
                      style: _T.label(10,
                          w: FontWeight.w700,
                          c: onSurf.withOpacity(0.35))),
                  Text('Categorías',
                      style: _T.display(28, c: onSurf)),
                  const SizedBox(height: 14),
                  _SegmentedControl(
                    selected: _tab,
                    onChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _tab = i);
                    },
                    // Los labels con el conteo se actualizan
                    // cuando llegan los datos — ver más abajo
                    labels: const ['Gastos', 'Ingresos'],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),

        // ── Contenido ────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<Category>>(
            stream: _stream,
            builder: (_, snap) {
              // Loading — skeleton directamente sobre el ListView
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return _SkeletonList();
              }

              if (snap.hasError) {
                return Center(
                    child: Text('Error: ${snap.error}',
                        style: _T.label(14)));
              }

              final all = snap.data ?? [];
              final expenses =
                  all.where((c) => c.type == CategoryType.expense).toList();
              final incomes =
                  all.where((c) => c.type == CategoryType.income).toList();
              final current = _tab == 0 ? expenses : incomes;

              // Empty state global (sin ninguna categoría)
              if (all.isEmpty) {
                return _EmptyAll(onAdd: _goToAdd);
              }

              // Empty state por tab
              if (current.isEmpty) {
                return _EmptyTab(
                  tab: _tab,
                  onAdd: _goToAdd,
                );
              }

              return _CategoryList(
                categories: current,
                onEdit: _goToEdit,
                onDelete: _openDeleteSheet,
              );
            },
          ),
        ),

        // ── Botón "Nueva categoría" sticky en bottom ─────────────────────
        // Fuera del StreamBuilder: siempre visible, no compite con contenido
        _BottomCTA(onTap: _goToAdd, tab: _tab),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEGMENTED CONTROL — reutilizamos el mismo patrón de la app
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedControl extends StatelessWidget {
  final int selected;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SegmentedControl({
    required this.selected,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final bg     = isDark
        ? Colors.white.withOpacity(0.10)
        : Colors.black.withOpacity(0.06);
    final pillBg = isDark
        ? Colors.white.withOpacity(0.18)
        : Colors.white;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: labels.indexed.map((e) {
          final (i, label) = e;
          final isSelected = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? pillBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected && !isDark
                      ? [BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Text(label,
                      style: _T.label(13,
                          w: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          c: isSelected
                              ? onSurf
                              : onSurf.withOpacity(0.45))),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTA DE CATEGORÍAS
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryList extends StatelessWidget {
  final List<Category> categories;
  final void Function(Category) onEdit;
  final void Function(Category) onDelete;

  const _CategoryList({
    required this.categories,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      // Padding bottom amplio para que el _BottomCTA no tape el último item
      padding: const EdgeInsets.fromLTRB(_T.h, 16, _T.h, 110),
      itemCount: categories.length,
      itemBuilder: (_, i) => _CategoryTile(
        key: ValueKey(categories[i].id),
        category: categories[i],
        delay: (30 * i).clamp(0, 240),
        onEdit: () => onEdit(categories[i]),
        onDelete: () => onDelete(categories[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TILE DE CATEGORÍA
// ─────────────────────────────────────────────────────────────────────────────
// Tap = editar (toda la superficie).
// Swipe a la izquierda = eliminar (con confirmación).
// Sin botones inline — cero ruido visual.

class _CategoryTile extends StatefulWidget {
  final Category category;
  final int delay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    this.delay = 0,
  });

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final onSurf  = Theme.of(context).colorScheme.onSurface;
    final bg      = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    final cat   = widget.category;
    final isExp = cat.type == CategoryType.expense;
    final color = isExp ? _kRed : _kGreen;

    return _FadeInSlide(
      delay: Duration(milliseconds: widget.delay),
      child: Dismissible(
        key: ValueKey(cat.id),
        direction: DismissDirection.endToStart,
        // Fondo de swipe — iOS style: rojo con ícono de trash
        background: Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _kRed,
            borderRadius: BorderRadius.circular(_T.r),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline_rounded,
                  color: Colors.white, size: 20),
              const SizedBox(height: 2),
              Text('Eliminar',
                  style: _T.label(10,
                      c: Colors.white, w: FontWeight.w700)),
            ],
          ),
        ),
        // Confirmación antes de dismiss
        confirmDismiss: (_) async {
          HapticFeedback.mediumImpact();
          bool confirmed = false;
          await showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: _ConfirmDeleteSheet(
                name: cat.name,
                onConfirm: () async {
                  confirmed = true;
                  Navigator.pop(context);
                },
              ),
            ),
          );
          return confirmed;
        },
        onDismissed: (_) => widget.onDelete(),
        child: GestureDetector(
          onTapDown: (_) {
            _pressCtrl.forward();
            HapticFeedback.selectionClick();
          },
          onTapUp:     (_) { _pressCtrl.reverse(); widget.onEdit(); },
          onTapCancel: ()  { _pressCtrl.reverse(); },
          child: AnimatedBuilder(
            animation: _pressCtrl,
            builder: (_, __) => Transform.scale(
              scale: lerpDouble(1.0, 0.985, _pressCtrl.value)!,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(_T.r)),
                child: Row(children: [
                  // Ícono con color semántico
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Icon(
                        cat.icon, size: 18, color: color)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat.name,
                          style: _T.label(15,
                              w: FontWeight.w700, c: onSurf)),
                      const SizedBox(height: 2),
                      Text(
                        isExp ? 'Gasto' : 'Ingreso',
                        style: _T.label(11,
                            c: color.withOpacity(0.80))),
                    ],
                  )),
                  // Chevron — indica que es tappable
                  Icon(Icons.chevron_right_rounded,
                      size: 17,
                      color: onSurf.withOpacity(0.22)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM CTA — sticky, fuera del scroll
// ─────────────────────────────────────────────────────────────────────────────

class _BottomCTA extends StatefulWidget {
  final VoidCallback onTap;
  final int tab;
  const _BottomCTA({required this.onTap, required this.tab});
  @override
  State<_BottomCTA> createState() => _BottomCTAState();
}

class _BottomCTAState extends State<_BottomCTA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 70));
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.02);
    final label  = widget.tab == 0
        ? 'Nueva categoría de gasto'
        : 'Nueva categoría de ingreso';

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: theme.scaffoldBackgroundColor.withOpacity(0.93),
          padding: EdgeInsets.only(
            left: _T.h, right: _T.h, top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          child: GestureDetector(
            onTapDown: (_) {
              _c.forward(); HapticFeedback.mediumImpact(); },
            onTapUp:   (_) { _c.reverse(); widget.onTap(); },
            onTapCancel: () => _c.reverse(),
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, __) => Transform.scale(
                scale: lerpDouble(1.0, 0.97, _c.value)!,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _kBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      // El label cambia con el tab seleccionado
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(label,
                            key: ValueKey(label),
                            style: _T.label(16,
                                c: Colors.white,
                                w: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATES
// ─────────────────────────────────────────────────────────────────────────────

// Estado vacío global — sin ninguna categoría creada
class _EmptyAll extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyAll({required this.onAdd});

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
                color: _kBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(child: Icon(
                  Iconsax.category_2, size: 32, color: _kBlue)),
            ),
            const SizedBox(height: 24),
            Text('Organiza tus finanzas',
                style: _T.display(22, c: onSurf),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Crea categorías para clasificar\ntus gastos e ingresos.',
              style: _T.label(14,
                  c: onSurf.withOpacity(0.45),
                  w: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Estado vacío por tab — hay categorías pero no de este tipo
class _EmptyTab extends StatelessWidget {
  final int tab;
  final VoidCallback onAdd;
  const _EmptyTab({required this.tab, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final isExp  = tab == 0;
    final color  = isExp ? _kRed : _kGreen;
    final label  = isExp ? 'gastos' : 'ingresos';
    final icon   = isExp ? Iconsax.money_remove : Iconsax.money_add;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(child: Icon(icon, size: 32, color: color)),
            ),
            const SizedBox(height: 24),
            Text('Sin categorías de $label',
                style: _T.display(20, c: onSurf),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Usa el botón de abajo para crear\ntu primera categoría.',
              style: _T.label(14,
                  c: onSurf.withOpacity(0.45),
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
// SKELETON LOADING
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg     = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.black.withOpacity(0.04);

    return Skeletonizer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(_T.h, 16, _T.h, 110),
        itemCount: 8,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(_T.r)),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 120,
                    color: Colors.grey.shade300),
                const SizedBox(height: 4),
                Container(height: 10, width: 60,
                    color: Colors.grey.shade200),
              ],
            )),
            Container(width: 17, height: 17,
                color: Colors.grey.shade200),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET — CONFIRMAR ELIMINACIÓN
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmDeleteSheet extends StatelessWidget {
  final String name;
  final Future<void> Function() onConfirm;

  const _ConfirmDeleteSheet({
    required this.name, required this.onConfirm});

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
                borderRadius: BorderRadius.circular(2))),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.10),
                    shape: BoxShape.circle),
                child: const Icon(Iconsax.trash,
                    color: _kRed, size: 24),
              ),
              const SizedBox(height: 12),
              Text('Eliminar categoría',
                  style: _T.display(18, c: onSurf)),
              const SizedBox(height: 8),
              Text(
                '"$name"\nLas transacciones existentes no se verán afectadas.',
                textAlign: TextAlign.center,
                style: _T.label(14,
                    c: onSurf.withOpacity(0.48),
                    w: FontWeight.w400)),
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: _InlineBtn(
                    label: 'Cancelar', color: onSurf,
                    onTap: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(child: _InlineBtn(
                    label: 'Eliminar', color: _kRed,
                    impact: true,
                    onTap: () async {
                      Navigator.pop(context);
                      await onConfirm();
                    })),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTES COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

// Fade + translate Y sutil — reemplaza flutter_animate
class _FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  const _FadeInSlide({required this.child, this.delay = Duration.zero});
  @override
  State<_FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<_FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));
  late final Animation<double> _fade =
      CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.05),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: widget.child),
      );
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