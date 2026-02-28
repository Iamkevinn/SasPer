import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sasper/data/manifestation_repository.dart';
import 'package:sasper/models/manifestation_model.dart';
import 'package:sasper/screens/add_manifestation_screen.dart';
import 'package:sasper/screens/edit_manifestation_screen.dart';
import 'package:sasper/screens/ManifestationVisionWidgetDebug.dart';
import 'package:sasper/services/widget_service.dart';
import 'dart:math' as math;
import 'package:sasper/services/manifestation_widget_service.dart';

// ─── DESIGN TOKENS ────────────────────────────────────────────────────────────
// Un solo lugar donde viven todos los valores de diseño.
// Modificar aquí cambia todo de forma consistente.
abstract class _Tokens {
  // Paleta de colores — oscura, sofisticada, sin ruido
  static const Color ink = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF12121A);
  static const Color surfaceElevated = Color(0xFF1C1C28);
  static const Color border = Color(0xFF2A2A38);
  static const Color borderSubtle = Color(0xFF1E1E2A);

  static const Color primary = Color(0xFFE8D5B7); // champagne dorado
  static const Color primaryDim = Color(0xFF8A7A62);
  static const Color accent = Color(0xFFC9A96E); // oro cálido

  static const Color textPrimary = Color(0xFFF5F0E8);
  static const Color textSecondary = Color(0xFF8A8699);
  static const Color textTertiary = Color(0xFF4A4858);

  // Espaciado — basado en múltiplos de 4
  static const double spaceXS = 4;
  static const double spaceSM = 8;
  static const double spaceMD = 16;
  static const double spaceLG = 24;
  static const double spaceXL = 32;
  static const double space2XL = 48;

  // Radios de borde
  static const double radiusSM = 10;
  static const double radiusMD = 16;
  static const double radiusLG = 22;
  static const double radiusXL = 28;

  // Tipografía
  static const String fontDisplay = 'Georgia'; // serif elegante
  static const String fontBody = '.SF Pro Display'; // SF en iOS, fallback nativo

  // Duraciones de animación
  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationMedium = Duration(milliseconds: 320);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationXSlow = Duration(milliseconds: 800);

  // Curvas de animación estilo Apple
  static const Curve curveApple = Curves.easeInOutCubic;
  static final Curve curveSpring = Curves.elasticOut;
}

// ─── PANTALLA PRINCIPAL ────────────────────────────────────────────────────────
class ManifestationsScreen extends StatefulWidget {
  const ManifestationsScreen({super.key});

  @override
  State<ManifestationsScreen> createState() => _ManifestationsScreenState();
}

class _ManifestationsScreenState extends State<ManifestationsScreen>
    with TickerProviderStateMixin {
  final _repository = ManifestationRepository();
  late Future<List<Manifestation>> _manifestationsFuture;

  // Controladores de animación
  late AnimationController _headerController;
  late AnimationController _pulseController;
  late AnimationController _fabController;

  // Animaciones derivadas
  late Animation<double> _headerOpacity;
  late Animation<Offset> _headerSlide;

  // Estado de scroll para el efecto de AppBar
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _loadManifestations();
    _setupAnimations();

    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  void _setupAnimations() {
    // Header entra suavemente
    _headerController = AnimationController(
      duration: _Tokens.durationXSlow,
      vsync: this,
    );

    _headerOpacity = CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _headerSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerController,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    ));

    _headerController.forward();

    // Pulso sutil para el ícono del FAB
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    // FAB entra con delay
    _fabController = AnimationController(
      duration: _Tokens.durationSlow,
      vsync: this,
    );

    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _pulseController.dispose();
    _fabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadManifestations() async {
    setState(() {
      _manifestationsFuture = _repository.getManifestations();
    });
    final manifestations = await _manifestationsFuture;
    await ManifestationWidgetService.saveManifestationsToWidget(manifestations);
    await saveManifestationsToWidget(manifestations);
  }

  void _navigateToAddScreen() async {
    // Feedback háptico estilo Apple
    HapticFeedback.lightImpact();

    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AddManifestationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: _Tokens.durationSlow,
      ),
    );
    if (result != null) _loadManifestations();
  }

  void _navigateToEditScreen(Manifestation manifestation) async {
    HapticFeedback.selectionClick();

    final result = await Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditManifestationScreen(manifestation: manifestation),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
        transitionDuration: _Tokens.durationSlow,
      ),
    );
    if (result == true) _loadManifestations();
  }

  Future<void> _showDeleteConfirmation(Manifestation manifestation) async {
    HapticFeedback.mediumImpact();

    final bool? confirmed = await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => _PremiumDialog(manifestation: manifestation),
    );

    if (confirmed == true) {
      try {
        await _repository.deleteManifestation(
          manifestationId: manifestation.id,
          imageUrl: manifestation.imageUrl ?? '',
        );
        if (mounted) {
          HapticFeedback.heavyImpact();
          _showToast(
            context,
            icon: Icons.check_circle_outline_rounded,
            message: '"${manifestation.title}" eliminado',
            isError: false,
          );
        }
        _loadManifestations();
      } catch (e) {
        if (mounted) {
          HapticFeedback.vibrate();
          _showToast(
            context,
            icon: Icons.error_outline_rounded,
            message: 'Error al eliminar',
            isError: true,
          );
        }
      }
    }
  }

  void _showToast(
    BuildContext context, {
    required IconData icon,
    required String message,
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _Tokens.textPrimary, size: 18),
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                color: _Tokens.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? const Color(0xFF2C1215)
            : _Tokens.surfaceElevated,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_Tokens.radiusMD),
          side: BorderSide(
            color: isError
                ? const Color(0xFF5C2525)
                : _Tokens.border,
            width: 0.5,
          ),
        ),
        elevation: 0,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDebugModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => _PremiumBottomSheet(
        child: const ManifestationWidgetDebug(widgetId: null),
      ),
    );
  }

  // Opacidad del AppBar según scroll
  double get _appBarOpacity =>
      (_scrollOffset / 80).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _Tokens.ink,
        extendBodyBehindAppBar: true,
        // AppBar translúcido que reacciona al scroll
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: AnimatedBuilder(
            animation: _scrollController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  color: _Tokens.ink.withOpacity(_appBarOpacity * 0.95),
                  border: Border(
                    bottom: BorderSide(
                      color: _Tokens.border
                          .withOpacity(_appBarOpacity),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: _Tokens.spaceMD),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Título que aparece al hacer scroll
                        AnimatedOpacity(
                          opacity: _appBarOpacity,
                          duration: _Tokens.durationFast,
                          child: const Text(
                            'Manifestaciones',
                            style: TextStyle(
                              fontFamily: _Tokens.fontDisplay,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: _Tokens.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        // Botón de debug minimalista
                        _IconBtn(
                          icon: Icons.terminal_rounded,
                          onTap: _showDebugModal,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        body: FutureBuilder<List<Manifestation>>(
          future: _manifestationsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingState();
            }
            if (snapshot.hasError) {
              return _ErrorState(error: '${snapshot.error}');
            }

            final manifestations = snapshot.data!;

            return CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                // ── HEADER ──────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _headerSlide,
                    child: FadeTransition(
                      opacity: _headerOpacity,
                      child: const _Header(),
                    ),
                  ),
                ),

                // ── CONTENIDO ───────────────────────────────────────────────
                if (manifestations.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onAdd: _navigateToAddScreen),
                  )
                else ...[
                  // Contador sutil
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _Tokens.spaceLG,
                        0,
                        _Tokens.spaceLG,
                        _Tokens.spaceSM,
                      ),
                      child: Text(
                        '${manifestations.length} ${manifestations.length == 1 ? 'manifestación' : 'manifestaciones'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: _Tokens.textTertiary,
                          letterSpacing: 0.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Lista de tarjetas
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      _Tokens.spaceMD,
                      0,
                      _Tokens.spaceMD,
                      120, // espacio para el FAB
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = manifestations[index];
                          return _AnimatedEntry(
                            index: index,
                            child: _ManifestationCard(
                              manifestation: m,
                              onEdit: () => _navigateToEditScreen(m),
                              onDelete: () => _showDeleteConfirmation(m),
                            ),
                          );
                        },
                        childCount: manifestations.length,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),

        // ── FAB ─────────────────────────────────────────────────────────────
        floatingActionButton: ScaleTransition(
          scale: CurvedAnimation(
            parent: _fabController,
            curve: Curves.elasticOut,
          ),
          child: _PremiumFAB(
            pulseAnimation: _pulseController,
            onTap: _navigateToAddScreen,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }
}

// ─── HEADER ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _Tokens.spaceLG,
        MediaQuery.of(context).padding.top + 72,
        _Tokens.spaceLG,
        _Tokens.spaceLG,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
          const Text(
            'Tu tablero de',
            style: TextStyle(
              fontSize: 13,
              color: _Tokens.accent,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: _Tokens.spaceXS),
          // Título principal — serif elegante
          const Text(
            'Manifestaciones',
            style: TextStyle(
              fontFamily: _Tokens.fontDisplay,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              color: _Tokens.textPrimary,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: _Tokens.spaceMD),
          // Línea divisoria fina
          Container(
            height: 0.5,
            color: _Tokens.border,
          ),
          const SizedBox(height: _Tokens.spaceMD),
          // Cita — muy sutil
          const Text(
            '"Lo que imaginas, puedes crear"',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: _Tokens.textSecondary,
              letterSpacing: 0.2,
              height: 1.4,
            ),
          ),
          const SizedBox(height: _Tokens.spaceLG),
        ],
      ),
    );
  }
}

// ─── TARJETA DE MANIFESTACIÓN ─────────────────────────────────────────────────
class _ManifestationCard extends StatefulWidget {
  final Manifestation manifestation;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ManifestationCard({
    required this.manifestation,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_ManifestationCard> createState() => _ManifestationCardState();
}

class _ManifestationCardState extends State<_ManifestationCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;
  bool _isMenuOpen = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.manifestation.imageUrl?.isNotEmpty == true
        ? widget.manifestation.imageUrl!
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: _Tokens.spaceMD),
      child: GestureDetector(
        onTapDown: (_) => _pressController.forward(),
        onTapUp: (_) => _pressController.reverse(),
        onTapCancel: () => _pressController.reverse(),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Container(
            // Relación de aspecto cinematográfica
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_Tokens.radiusLG),
              color: _Tokens.surfaceElevated,
              border: Border.all(
                color: _Tokens.borderSubtle,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // ── IMAGEN ────────────────────────────────────────────
                if (imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(color: _Tokens.surfaceElevated);
                      },
                      errorBuilder: (_, __, ___) =>
                          const _CardPlaceholder(),
                    ),
                  )
                else
                  const Positioned.fill(child: _CardPlaceholder()),

                // ── GRADIENTE CINEMATOGRÁFICO ─────────────────────────
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.15),
                          Colors.black.withOpacity(0.75),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── CONTENIDO INFERIOR ────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(_Tokens.spaceMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.manifestation.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.manifestation.description?.isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.manifestation.description!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                              letterSpacing: 0.1,
                              height: 1.3,
                              shadows: const [
                                Shadow(
                                  color: Colors.black45,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── MENÚ CONTEXTUAL ───────────────────────────────────
                Positioned(
                  top: _Tokens.spaceSM,
                  right: _Tokens.spaceSM,
                  child: _CardMenu(
                    onEdit: widget.onEdit,
                    onDelete: widget.onDelete,
                    onOpenChanged: (open) =>
                        setState(() => _isMenuOpen = open),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── MENÚ DE TARJETA ──────────────────────────────────────────────────────────
class _CardMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onOpenChanged;

  const _CardMenu({
    required this.onEdit,
    required this.onDelete,
    required this.onOpenChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onOpened: () {
        HapticFeedback.selectionClick();
        onOpenChanged(true);
      },
      onCanceled: () => onOpenChanged(false),
      onSelected: (value) {
        onOpenChanged(false);
        if (value == 'edit') onEdit();
        if (value == 'delete') onDelete();
      },
      // Botón del menú — píldora frosted glass
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.12),
              width: 0.5,
            ),
          ),
          child: const Icon(
            Icons.more_horiz_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_Tokens.radiusMD),
        side: const BorderSide(color: _Tokens.border, width: 0.5),
      ),
      color: _Tokens.surfaceElevated,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.5),
      itemBuilder: (_) => [
        _menuItem(
          value: 'edit',
          icon: Icons.edit_outlined,
          label: 'Editar',
          color: _Tokens.accent,
        ),
        const PopupMenuDivider(height: 1),
        _menuItem(
          value: 'delete',
          icon: Icons.delete_outline_rounded,
          label: 'Eliminar',
          color: const Color(0xFFE05555),
        ),
      ],
    );
  }

  PopupMenuEntry<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<String>(
      value: value,
      padding: const EdgeInsets.symmetric(
        horizontal: _Tokens.spaceMD,
        vertical: _Tokens.spaceSM + 2,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: _Tokens.spaceSM + 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PLACEHOLDER DE IMAGEN ────────────────────────────────────────────────────
class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Tokens.surfaceElevated,
      child: const Center(
        child: Icon(
          Icons.image_outlined,
          size: 36,
          color: _Tokens.textTertiary,
        ),
      ),
    );
  }
}

// ─── ENTRADA ANIMADA DE ELEMENTOS ─────────────────────────────────────────────
class _AnimatedEntry extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedEntry({required this.index, required this.child});

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _Tokens.durationSlow,
      vsync: this,
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Stagger por índice
    Future.delayed(Duration(milliseconds: 80 + widget.index * 60), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// ─── FAB PREMIUM ──────────────────────────────────────────────────────────────
class _PremiumFAB extends StatelessWidget {
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _PremiumFAB({
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final glow =
            0.12 + (math.sin(pulseAnimation.value * math.pi) * 0.06);
        return GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: _Tokens.primary,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: _Tokens.accent.withOpacity(glow),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_rounded,
                  color: _Tokens.ink,
                  size: 22,
                ),
                SizedBox(width: 6),
                Text(
                  'Nueva manifestación',
                  style: TextStyle(
                    color: _Tokens.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── BOTÓN ÍCONO ──────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _Tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _Tokens.border, width: 0.5),
        ),
        child: Icon(icon, size: 16, color: _Tokens.textSecondary),
      ),
    );
  }
}

// ─── ESTADO VACÍO ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_Tokens.spaceXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono central minimalista
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _Tokens.surfaceElevated,
              border: Border.all(color: _Tokens.border, width: 0.5),
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 32,
              color: _Tokens.accent,
            ),
          ),
          const SizedBox(height: _Tokens.spaceLG),
          const Text(
            'Comienza a manifestar',
            style: TextStyle(
              fontFamily: _Tokens.fontDisplay,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _Tokens.textPrimary,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _Tokens.spaceSM),
          const Text(
            'Visualiza tus metas. Conecta tus\ndeseos con tu propósito.',
            style: TextStyle(
              fontSize: 15,
              color: _Tokens.textSecondary,
              height: 1.5,
              letterSpacing: 0.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: _Tokens.spaceXL),
          // CTA
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onAdd();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: _Tokens.spaceLG,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: _Tokens.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Crear primera manifestación',
                style: TextStyle(
                  color: _Tokens.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── ESTADO DE CARGA ──────────────────────────────────────────────────────────
class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: _Tokens.accent,
        ),
      ),
    );
  }
}

// ─── ESTADO DE ERROR ──────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String error;

  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_Tokens.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Color(0xFFE05555),
            ),
            const SizedBox(height: _Tokens.spaceMD),
            const Text(
              'No se pudo cargar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _Tokens.textPrimary,
              ),
            ),
            const SizedBox(height: _Tokens.spaceSM),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: _Tokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DIÁLOGO DE CONFIRMACIÓN PREMIUM ─────────────────────────────────────────
class _PremiumDialog extends StatelessWidget {
  final Manifestation manifestation;

  const _PremiumDialog({required this.manifestation});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(_Tokens.spaceLG),
        decoration: BoxDecoration(
          color: _Tokens.surfaceElevated,
          borderRadius: BorderRadius.circular(_Tokens.radiusXL),
          border: Border.all(color: _Tokens.border, width: 0.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono de advertencia
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2C1215),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFE05555),
                size: 22,
              ),
            ),
            const SizedBox(height: _Tokens.spaceMD),
            const Text(
              'Eliminar manifestación',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _Tokens.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: _Tokens.spaceSM),
            Text(
              'Se eliminará "${manifestation.title}" de forma permanente. Esta acción no se puede deshacer.',
              style: const TextStyle(
                fontSize: 14,
                color: _Tokens.textSecondary,
                height: 1.45,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: _Tokens.spaceLG),
            // Acciones
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _Tokens.surface,
                        borderRadius: BorderRadius.circular(_Tokens.radiusSM),
                        border: Border.all(
                            color: _Tokens.border, width: 0.5),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: _Tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: _Tokens.spaceSM),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(true);
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE05555),
                        borderRadius: BorderRadius.circular(_Tokens.radiusSM),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Eliminar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── BOTTOM SHEET PREMIUM ─────────────────────────────────────────────────────
class _PremiumBottomSheet extends StatelessWidget {
  final Widget child;

  const _PremiumBottomSheet({required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _Tokens.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(_Tokens.radiusXL),
            ),
            border: const Border(
              top: BorderSide(color: _Tokens.border, width: 0.5),
            ),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _Tokens.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header del sheet
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _Tokens.spaceMD,
                  vertical: _Tokens.spaceSM,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _Tokens.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.terminal_rounded,
                        size: 16,
                        color: _Tokens.accent,
                      ),
                    ),
                    const SizedBox(width: _Tokens.spaceSM),
                    const Text(
                      'Panel de Debug',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _Tokens.textPrimary,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const Spacer(),
                    _IconBtn(
                      icon: Icons.close_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Container(height: 0.5, color: _Tokens.border),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(_Tokens.spaceMD),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}