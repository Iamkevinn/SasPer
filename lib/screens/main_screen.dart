// lib/screens/main_screen.dart (VERSIÓN FINAL CON UX MEJORADA)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/screens/planning_hub_screen.dart';
import 'package:sasper/screens/transactions_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

// Repositorios
import '../data/auth_repository.dart';
import '../data/dashboard_repository.dart';
import '../data/goal_repository.dart';
import '../data/debt_repository.dart';
import '../data/account_repository.dart';
import '../data/budget_repository.dart';

// Servicios
import '../services/event_service.dart';

// Pantallas
import 'accounts_screen.dart';
import 'add_budget_screen.dart';
import 'add_debt_screen.dart';
import 'add_goal_screen.dart';
import 'add_transaction_screen.dart';
import 'analysis_screen.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'debts_screen.dart';
import 'goals_screen.dart';
import 'settings_screen.dart';

// Utilidades
import '../utils/custom_page_route.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  late final DashboardRepository _dashboardRepository;
  late final GoalRepository _goalRepository;
  late final AuthRepository _authRepository;
  late final DebtRepository _debtRepository;
  late final AccountRepository _accountRepository;
  late final TransactionRepository _transactionRepository;
  late final BudgetRepository _budgetRepository;
  late StreamSubscription<AppEvent> _eventSubscription;

  late final List<Widget> _widgetOptions;

  @override
  void initState() {
    super.initState();
    
    _dashboardRepository = DashboardRepository(Supabase.instance.client);
    _goalRepository = GoalRepository();
    _authRepository = AuthRepository();
    _debtRepository = DebtRepository();
    _accountRepository = AccountRepository();
    _transactionRepository = TransactionRepository();
    _budgetRepository = BudgetRepository();

    _widgetOptions = <Widget>[
      DashboardScreen(
        repository: _dashboardRepository,
        accountRepository: _accountRepository,
        transactionRepository: _transactionRepository,
        budgetRepository: _budgetRepository,
      ),
      TransactionsScreen(transactionRepository: _transactionRepository, accountRepository: _accountRepository,),
      PlanningHubScreen(
        budgetRepository: _budgetRepository,
        goalRepository: _goalRepository,
        debtRepository: _debtRepository,
        accountRepository: _accountRepository, transactionRepository: _transactionRepository,
      ),
      SettingsScreen(authRepository: _authRepository),
    ];

    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
        AppEvent.transactionsChanged, AppEvent.transactionUpdated, AppEvent.transactionDeleted,
        AppEvent.accountUpdated, AppEvent.budgetsChanged, AppEvent.debtsChanged, AppEvent.goalUpdated,
      };
      if (refreshEvents.contains(event)) {
        _dashboardRepository.forceRefresh();
      }
    });
  }

  @override
  void dispose() {
    _dashboardRepository.dispose();
    _goalRepository.dispose();
    _debtRepository.dispose();
    _accountRepository.dispose();
    _budgetRepository.dispose();
    _eventSubscription.cancel();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
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
    Navigator.of(context).push(FadePageRoute(child: AddTransactionScreen(transactionRepository: _transactionRepository, accountRepository: _accountRepository)));
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