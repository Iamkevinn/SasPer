// lib/screens/main_screen.dart (VERSIÓN FINAL CON UX MEJORADA)
// lib/screens/main_screen.dart

import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/dashboard_repository.dart'; // Importante para la suscripción
import 'package:sasper/screens/dashboard_screen.dart';
import 'package:sasper/screens/planning_hub_screen.dart';
import 'package:sasper/screens/settings_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/utils/custom_page_route.dart';

// Pantallas
import 'add_transaction_screen.dart';
//import 'dashboard_screen.dart';
//import 'planning_hub_screen.dart';
//import 'settings_screen.dart';
//import 'transactions_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  //late final GoalRepository _goalRepository;
  late StreamSubscription<AppEvent> _eventSubscription;
  late final AppLinks _appLinks;
  late final StreamSubscription<Uri?> _linkSub;
  // Inicializamos la lista de widgets. Como son constantes,
  // la podemos definir directamente como una variable de instancia.
  final List<Widget> _widgetOptions = const <Widget>[
    DashboardScreen(),
    TransactionsScreen(),
    PlanningHubScreen(),
    SettingsScreen(),
  ];
  
  @override
  void initState() {
    super.initState();
    
    //_dashboardRepository = DashboardRepository(Supabase.instance.client);
    //_authRepository = AuthRepository();
    //_debtRepository = DebtRepository();

    
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
      
      // RESTAURADO Y CORREGIDO: Llama al Singleton para refrescar.
      if (refreshEvents.contains(event)) {
        DashboardRepository.instance.forceRefresh();
      }
    });

     Future.delayed(const Duration(seconds: 15), () {
      if (mounted) { // Comprueba si el widget todavía está en el árbol
        if (kDebugMode) {
          print("🚀 Ejecutando tarea de mantenimiento retrasada: refreshAllSchedules");
        }
        NotificationService.instance.refreshAllSchedules();
      }
    });
    
  }

  @override
  void dispose() {
    //_dashboardRepository.dispose();
    //_goalRepository.dispose();
    //_debtRepository.dispose();
    _eventSubscription.cancel();
    _linkSub.cancel(); 
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }

  /// Revisa si la app fue abierta desde un estado "terminado" con un enlace.
  void _initDeepLinks() {
  _appLinks = AppLinks();
  
  // 1) Nos suscribimos al mismo stream para el enlace inicial y todos los siguientes
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


  // Este método no cambia, ya estaba bien.
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
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget? _buildFloatingActionButton() {
    return FloatingActionButton(
      heroTag: 'fab_main', // Un solo FAB, un solo Tag
      onPressed: _navigateToAddTransaction, // El FAB siempre añade una transacción
      child: const Icon(Iconsax.add),
    );
}

    void _navigateToAddTransaction() {
    // El Future.delayed ya no es estrictamente necesario, pero no hace daño.
    // Es una buena práctica para asegurar que la UI esté lista.
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        Navigator.of(context).push(FadePageRoute(
          child: const AddTransactionScreen(),
        ));
      }
    });
  }

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          _buildNavItem(index: 0, icon: Iconsax.home_2, label: 'Inicio'),
          _buildNavItem(index: 1, icon: Iconsax.document_text_1, label: 'Movimientos'),
          const SizedBox(width: 48),
          _buildNavItem(index: 2, icon: Iconsax.discover_1, label: 'Planificar'),
          _buildNavItem(index: 3, icon: Iconsax.setting_2, label: 'Ajustes'),
        ],
      ),
    );
  }

  Widget _buildNavItem({required int index, required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _onItemTapped(index);
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant, size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}