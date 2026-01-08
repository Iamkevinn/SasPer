// lib/screens/main_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/screens/dashboard_screen.dart';
import 'package:sasper/screens/planning_hub_screen.dart';
import 'package:sasper/screens/settings_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/notification_service.dart';
import 'add_transaction_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late StreamSubscription<AppEvent> _eventSubscription;
  late final AppLinks _appLinks;
  late StreamSubscription<Uri?> _linkSub;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  final List<Widget> _widgetOptions = const <Widget>[
    DashboardScreen(),
    TransactionsScreen(),
    PlanningHubScreen(),
    SettingsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Iconsax.home_2,
      activeIcon: Iconsax.home_25,
      label: 'Inicio',
      color: Colors.blue,
    ),
    _NavItem(
      icon: Iconsax.document_text_1,
      activeIcon: Iconsax.document_text,
      label: 'Movimientos',
      color: Colors.purple,
    ),
    _NavItem(
      icon: Iconsax.discover_1,
      activeIcon: Iconsax.discover,
      label: 'Planificar',
      color: Colors.orange,
    ),
    _NavItem(
      icon: Iconsax.setting_2,
      activeIcon: Iconsax.setting_21,
      label: 'Ajustes',
      color: Colors.teal,
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    
    _initDeepLinks();
    _linkSub = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null && mounted) {
          if (kDebugMode) {
            print('Deep link recibido: $uri');
          }
          _handleIncomingLink(uri);
        }
      },
      onError: (err) {
        debugPrint('Error en deep link stream: $err');
      },
    );
    
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
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

      if (refreshEvents.contains(event)) {
        DashboardRepository.instance.forceRefresh();
      }
    });

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted) {
        if (kDebugMode) {
          print("🚀 Ejecutando tarea de mantenimiento retrasada: refreshAllSchedules");
        }
        NotificationService.instance.refreshAllSchedules();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel();
    _linkSub.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      HapticFeedback.lightImpact();
      setState(() => _selectedIndex = index);
    }
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen(
      (uri) {
        if (mounted) {
          if (kDebugMode) {
            print('Deep link recibido: $uri');
          }
          _handleIncomingLink(uri);
        }
      },
      onError: (err) {
        debugPrint('Error en deep link stream: $err');
      },
    );
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.scheme == 'sasper' && uri.host == 'add_transaction') {
      if (kDebugMode) {
        print('Navegando a Añadir Transacción...');
      }
      _navigateToAddTransaction();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _widgetOptions,
      ),
      extendBody: true,
      bottomNavigationBar: _buildBubbleBottomNavBar(),
      floatingActionButton: _buildModernFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildModernFAB() {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: Container(
        width: 56,
        height: 56,
        margin: const EdgeInsets.only(top: 30),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.8),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              _fabAnimationController.forward().then((_) {
                _fabAnimationController.reverse();
              });
              _navigateToAddTransaction();
            },
            borderRadius: BorderRadius.circular(28),
            child: const Center(
              child: Icon(Iconsax.add, size: 28, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToAddTransaction() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const AddTransactionScreen(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;

              var tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              return SlideTransition(
                position: animation.drive(tween),
                child: FadeTransition(
                  opacity: animation,
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  Widget _buildBubbleBottomNavBar() {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: isDark 
                  ? colorScheme.surfaceContainerHigh.withOpacity(0.7)
                  : colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: isDark 
                      ? Colors.black.withOpacity(0.3)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                  spreadRadius: -5,
                ),
              ],
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.white.withOpacity(0.6),
                width: 1.5,
              ),
              gradient: isDark
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.1),
                        Colors.white.withOpacity(0.05),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.8),
                        Colors.white.withOpacity(0.4),
                      ],
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildNavItemBubble(index: 0),
                _buildNavItemBubble(index: 1),
                const SizedBox(width: 56), // Espacio para el FAB
                _buildNavItemBubble(index: 2),
                _buildNavItemBubble(index: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItemBubble({required int index}) {
    final item = _navItems[index];
    final isSelected = _selectedIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // Indicador de fondo animado
                  if (isSelected)
                    Container(
                      width: 56,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 2000.ms,
                          color: item.color.withOpacity(0.2),
                        ),
                  
                  // Ícono
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: child,
                      );
                    },
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      key: ValueKey<bool>(isSelected),
                      color: isSelected ? item.color : colorScheme.onSurfaceVariant,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              
              // Label con animación
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.inter(
                  fontSize: isSelected ? 11 : 10,
                  color: isSelected ? item.color : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                child: Text(item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MODELO DE DATOS PARA ITEMS DE NAVEGACIÓN
// ============================================================================
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final Color color;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.color,
  });
}