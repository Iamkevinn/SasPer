// lib/screens/main_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// Repositorios
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/account_repository.dart';

// Servicios
import 'package:sasper/services/event_service.dart';

// Pantallas
import 'accounts_screen.dart';
import 'add_debt_screen.dart';
import 'add_goal_screen.dart';
import 'add_transaction_screen.dart';
import 'analysis_screen.dart';
import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';

// Utilidades
import 'package:sasper/utils/custom_page_route.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Declaramos todos los repositorios que la app necesitará.
  late final DashboardRepository _dashboardRepository;
  late final GoalRepository _goalRepository;
  late final AuthRepository _authRepository;
  late final DebtRepository _debtRepository;
  late final AccountRepository _accountRepository;
  late final TransactionRepository _transactionRepository;
  late StreamSubscription<AppEvent> _eventSubscription;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    
    // Inicializamos TODOS los repositorios.
    _dashboardRepository = DashboardRepository(Supabase.instance.client);
    _goalRepository = GoalRepository();
    _authRepository = AuthRepository();
    _debtRepository = DebtRepository();
    _accountRepository = AccountRepository();
    _transactionRepository = TransactionRepository();
    // Inicializamos la lista de widgets aquí, ahora que los repositorios existen.
    _widgetOptions = <Widget>[
      DashboardScreen(
        repository: _dashboardRepository,
        accountRepository: _accountRepository,
        transactionRepository: _transactionRepository,
      ),
      AccountsScreen(
        repository: _accountRepository,
        transactionRepository: _transactionRepository, // Pasamos la dependencia que faltaba
      ),
      DebtsScreen(repository: _debtRepository, accountRepository: _accountRepository),
      GoalsScreen(repository: _goalRepository),
      const AnalysisScreen(),
      SettingsScreen(authRepository: _authRepository),
    ];

    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
        AppEvent.transactionsChanged,
        AppEvent.accountUpdated,
        AppEvent.budgetsChanged,
        AppEvent.debtsChanged,
        AppEvent.goalUpdated,
      };
      if (refreshEvents.contains(event)) {
        _dashboardRepository.forceRefresh();
      }
    });
  }

  @override
  void dispose() {
    // Liberamos los recursos de todos los repositorios que lo requieran.
    _dashboardRepository.dispose();
    _goalRepository.dispose();
    _debtRepository.dispose();
    _accountRepository.dispose();
    _eventSubscription.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
    // El FAB solo aparece en las pantallas donde tiene sentido añadir algo.
    // Usamos un switch para determinar la acción correcta.
    final bool showFab = [0, 1, 2, 3].contains(_selectedIndex);
    if (!showFab) return null;

    VoidCallback? onPressed;
    String heroTag = 'fab_main_$_selectedIndex';

    switch (_selectedIndex) {
      case 0: // Dashboard -> Añadir Transacción
      case 1: // Cuentas -> Añadir Transacción (o Transferencia, etc.)
        onPressed = _navigateToAddTransaction;
        heroTag = 'fab_add_transaction';
        break;
      case 2: // Deudas -> Añadir Deuda
        onPressed = () => _navigateToAddDebt(context);
        heroTag = 'fab_add_debt';
        break;
      case 3: // Metas -> Añadir Meta
        onPressed = () => _navigateToAddGoal(context);
        heroTag = 'fab_add_goal';
        break;
    }

    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      child: const Icon(Iconsax.add),
    );
  }

  void _navigateToAddTransaction() {
    Navigator.of(context).push(FadePageRoute(child: const AddTransactionScreen()));
  }

  void _navigateToAddGoal(BuildContext navContext) {
    Navigator.push(navContext, FadePageRoute(child: AddGoalScreen(goalRepository: _goalRepository)));
  }

  void _navigateToAddDebt(BuildContext navContext) {
    Navigator.push(navContext, MaterialPageRoute(builder: (context) => AddDebtScreen(debtRepository: _debtRepository, accountRepository: _accountRepository)));
  }

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Theme.of(context).colorScheme.surface.withAlpha(240),
      elevation: 0,
      child: ClipRRect(
        // El blur solo se aplica si es necesario, si no, se ve el color sólido.
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              _buildNavItem(index: 0, icon: Iconsax.home_2, label: 'Inicio'),
              _buildNavItem(index: 1, icon: Iconsax.wallet_3, label: 'Cuentas'),
              const SizedBox(width: 48), // Espacio para el FAB
              _buildNavItem(index: 2, icon: Iconsax.receipt_2_1, label: 'Deudas'),
              _buildNavItem(index: 3, icon: Iconsax.flag, label: 'Metas'),
            ],
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: isSelected ? 28 : 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}