// lib/screens/main_screen.dart
//
// ┌─────────────────────────────────────────────────────────────────────────────┐
// │  FILOSOFÍA DE DISEÑO — Apple iOS Tab Bar                                   │
// │  • La nav bar es infraestructura, no protagonista.                         │
// │  • El tab activo se comunica con color + peso — no con burbujas ni shimmer.│
// │  • El FAB es el único call-to-action primario. Siempre visible, siempre    │
// │    en el centro. Sin gradientes: color sólido con sombra sutil.            │
// │  • La barra usa blur nativo de iOS — el contenido se lee a través.        │
// │  • Micro-feedback háptico diferenciado: selección en tabs, medio en FAB.   │
// │  • El indicador de tab activo es una línea superior de 2px — igual que    │
// │    la tab bar de Safari, Music y Maps en iOS.                              │
// └─────────────────────────────────────────────────────────────────────────────┘

import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/screens/dashboard_screen.dart';
import 'package:sasper/screens/planning_hub_screen.dart';
import 'package:sasper/screens/settings_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/notification_service.dart';
import 'add_transaction_screen.dart';

// ─── TOKENS ──────────────────────────────────────────────────────────────────
// Solo los que necesita esta pantalla: nav bar y FAB.
class _T {
  // Nav bar — blur + superficie semitransparente iOS
  // Oscuro: la barra mezcla negro con opacidad, no gris
  static Color navBg(bool isDark) => isDark
      ? const Color(0xFF1C1C1E).withOpacity(0.85)
      : Colors.white.withOpacity(0.80);

  static Color navBorder(bool isDark) => isDark
      ? Colors.white.withOpacity(0.08)
      : Colors.black.withOpacity(0.06);

  static Color navShadow(bool isDark) => isDark
      ? Colors.black.withOpacity(0.40)
      : Colors.black.withOpacity(0.08);

  // Tab items
  static Color tabActive(bool isDark, Color itemColor) => itemColor;
  static Color tabInactive(bool isDark) => isDark
      ? const Color(0xFF636366)
      : const Color(0xFFAEAEB2);

  // FAB — iOS blue, sin gradiente
  static const Color fab    = Color(0xFF0A84FF);
  static const Color fabDim = Color(0xFF0060CC); // pressed state

  // Dimensiones de la barra
  static const double barHeight   = 68.0;
  static const double barRadius   = 26.0;
  static const double barPadH     = 20.0;
  static const double barPadB     = 16.0;
  static const double fabSize     = 52.0;
  static const double fabOffset   = 28.0; // cuánto sube sobre la barra
}

// ─── MODELO DE TAB ───────────────────────────────────────────────────────────
class _Tab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const _Tab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}

// ─── PANTALLA PRINCIPAL ──────────────────────────────────────────────────────
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  late StreamSubscription<AppEvent> _eventSub;
  late final AppLinks _appLinks;
  late StreamSubscription<Uri?> _linkSub;

  // Controlador de animación del FAB — rebote en tap
  late AnimationController _fabCtrl;
  late Animation<double> _fabScale;

  // Lista vacía en declaración — se puebla en initState antes del primer build
  List<AnimationController> _tabCtrls = [];

  static const List<_Tab> _tabs = [
    _Tab(
      icon: Iconsax.home_2,
      activeIcon: Iconsax.home_25,
      label: 'Inicio',
      color: Color(0xFF0A84FF),
    ),
    _Tab(
      icon: Iconsax.document_text_1,
      activeIcon: Iconsax.document_text,
      label: 'Movimientos',
      color: Color(0xFFBF5AF2),
    ),
    _Tab(
      icon: Iconsax.discover_1,
      activeIcon: Iconsax.discover,
      label: 'Planificar',
      color: Color(0xFFFF9F0A),
    ),
    _Tab(
      icon: Iconsax.setting_2,
      activeIcon: Iconsax.setting_21,
      label: 'Ajustes',
      color: Color(0xFF636366),
    ),
  ];

  static const List<Widget> _screens = [
    DashboardScreen(),
    TransactionsScreen(),
    PlanningHubScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // FAB: rebote rápido al tocar — elasticOut en reverse
    _fabCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _fabScale = Tween<double>(begin: 1.0, end: 0.91).animate(
      CurvedAnimation(parent: _fabCtrl, curve: Curves.easeIn),
    );

    // Tabs: cada una tiene su propio controlador para animar la entrada del ícono
    _tabCtrls = List.generate(
      _tabs.length,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
        value: i == 0 ? 1.0 : 0.0,
      ),
    );

    _initDeepLinks();

    _eventSub = EventService.instance.eventStream.listen((event) {
      const refreshOn = {
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted,
        AppEvent.accountUpdated,
        AppEvent.budgetsChanged,
        AppEvent.debtsChanged,
        AppEvent.goalUpdated,
        AppEvent.goalsChanged,
        AppEvent.accountCreated,
      };
      if (refreshOn.contains(event)) {
        DashboardRepository.instance.forceRefresh();
      }
    });

    // Mantenimiento diferido de notificaciones
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) NotificationService.instance.refreshAllSchedules();
    });
  }

  @override
  void dispose() {
    _eventSub.cancel();
    _linkSub.cancel();
    _fabCtrl.dispose();
    for (final ctrl in _tabCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Deep links ───────────────────────────────────────────────────────────
  void _initDeepLinks() {
    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null && mounted) {
          if (kDebugMode) print('Deep link: $uri');
          _handleIncomingLink(uri);
        }
      },
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme == 'sasper' && uri.host == 'add_transaction') {
      _openAddTransaction();
    }
  }

  // ── Navegación de tabs ───────────────────────────────────────────────────
  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();

    // Anima la salida del tab anterior y entrada del nuevo
    _tabCtrls[_selectedIndex].reverse();
    _tabCtrls[index].forward();

    setState(() => _selectedIndex = index);
  }

  // ── Abrir pantalla de transacción ────────────────────────────────────────
  void _openAddTransaction() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, animation, __) => const AddTransactionScreen(),
          transitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder: (_, animation, __, child) {
            final curved = CurvedAnimation(
                parent: animation, curve: Curves.easeOutCubic);
            return SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 1), end: Offset.zero)
                  .animate(curved),
              child: FadeTransition(
                opacity:
                    Tween<double>(begin: 0.0, end: 1.0).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Status bar adaptada al tema
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness:
          isDark ? Brightness.dark : Brightness.light,
    ));

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF000000)
          : const Color(0xFFF2F2F7),
      extendBody: true, // el contenido se extiende bajo la nav bar
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _tabCtrls.length == _tabs.length
          ? _NavBar(
        tabs: _tabs,
        selectedIndex: _selectedIndex,
        tabCtrls: _tabCtrls,
        isDark: isDark,
        onTabTapped: _onTabTapped,
        onFabTap: () {
          HapticFeedback.mediumImpact();
          _fabCtrl.forward().then((_) => _fabCtrl.reverse());
          _openAddTransaction();
        },
        fabCtrl: _fabCtrl,
        fabScale: _fabScale,
      )
          : const SizedBox.shrink(),
    );
  }
}

// ─── NAV BAR ─────────────────────────────────────────────────────────────────
// Componente separado para mayor legibilidad.
// El FAB vive DENTRO de la barra, centrado, elevado.
class _NavBar extends StatelessWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final List<AnimationController> tabCtrls;
  final bool isDark;
  final Function(int) onTabTapped;
  final VoidCallback onFabTap;
  final AnimationController fabCtrl;
  final Animation<double> fabScale;

  const _NavBar({
    required this.tabs,
    required this.selectedIndex,
    required this.tabCtrls,
    required this.isDark,
    required this.onTabTapped,
    required this.onFabTap,
    required this.fabCtrl,
    required this.fabScale,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: _T.barPadH,
        right: _T.barPadH,
        bottom: _T.barPadB + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: _T.barHeight + _T.fabOffset,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            // ── La barra en sí ──────────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_T.barRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    height: _T.barHeight,
                    decoration: BoxDecoration(
                      color: _T.navBg(isDark),
                      borderRadius:
                          BorderRadius.circular(_T.barRadius),
                      border: Border.all(
                        color: _T.navBorder(isDark),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _T.navShadow(isDark),
                          blurRadius: 32,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Tabs izquierdas (0 y 1)
                        Expanded(
                          child: Row(
                            children: [
                              _TabItem(
                                tab: tabs[0],
                                isSelected: selectedIndex == 0,
                                ctrl: tabCtrls[0],
                                isDark: isDark,
                                onTap: () => onTabTapped(0),
                              ),
                              _TabItem(
                                tab: tabs[1],
                                isSelected: selectedIndex == 1,
                                ctrl: tabCtrls[1],
                                isDark: isDark,
                                onTap: () => onTabTapped(1),
                              ),
                            ],
                          ),
                        ),

                        // Espacio central para el FAB
                        const SizedBox(width: _T.fabSize + 16),

                        // Tabs derechas (2 y 3)
                        Expanded(
                          child: Row(
                            children: [
                              _TabItem(
                                tab: tabs[2],
                                isSelected: selectedIndex == 2,
                                ctrl: tabCtrls[2],
                                isDark: isDark,
                                onTap: () => onTabTapped(2),
                              ),
                              _TabItem(
                                tab: tabs[3],
                                isSelected: selectedIndex == 3,
                                ctrl: tabCtrls[3],
                                isDark: isDark,
                                onTap: () => onTabTapped(3),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── FAB — elevado sobre la barra ────────────────────────────
            Positioned(
              bottom: _T.barHeight - _T.fabSize / 2 - 2,
              child: ScaleTransition(
                scale: fabScale,
                child: _FAB(
                  isDark: isDark,
                  onTap: onFabTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ITEM DE TAB ─────────────────────────────────────────────────────────────
// Ícono + label. El indicador activo es la coloración del ícono y el texto —
// no una burbuja, no un fondo. Limpio como iOS.
class _TabItem extends StatelessWidget {
  final _Tab tab;
  final bool isSelected;
  final AnimationController ctrl;
  final bool isDark;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.isSelected,
    required this.ctrl,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor  = _T.tabActive(isDark, tab.color);
    final inactiveColor = _T.tabInactive(isDark);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _T.barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícono — AnimatedSwitcher entre activo/inactivo
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: Tween<double>(begin: 0.75, end: 1.0)
                      .animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Icon(
                  isSelected ? tab.activeIcon : tab.icon,
                  key: ValueKey<bool>(isSelected),
                  color: isSelected ? activeColor : inactiveColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),

              // Label — tamaño y peso animados
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: 0.1,
                ),
                child: Text(tab.label),
              ),

              // Indicador: punto minimalista bajo el label
              // Invisible cuando no está seleccionado, visible cuando sí.
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: isSelected ? 4 : 0,
                height: isSelected ? 4 : 0,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── FAB ─────────────────────────────────────────────────────────────────────
// Un solo propósito: añadir transacción.
// Color sólido, sombra coherente, sin gradiente.
// La sombra es del color del botón — igual que el botón de iOS App Store.
class _FAB extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _FAB({required this.isDark, required this.onTap});

  @override
  State<_FAB> createState() => _FABState();
}

class _FABState extends State<_FAB> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: _T.fabSize,
        height: _T.fabSize,
        decoration: BoxDecoration(
          color: _pressing ? _T.fabDim : _T.fab,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _T.fab.withOpacity(_pressing ? 0.2 : 0.35),
              blurRadius: _pressing ? 10 : 20,
              offset: Offset(0, _pressing ? 2 : 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}