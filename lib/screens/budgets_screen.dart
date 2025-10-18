// lib/screens/budgets_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/models/budget_models.dart';
import 'package:sasper/screens/edit_budget_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/screens/add_budget_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/budget_card.dart';
import 'package:sasper/main.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/screens/budget_details_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with TickerProviderStateMixin {
  final BudgetRepository _repository = BudgetRepository.instance;
  late final Stream<List<Budget>> _budgetsStream;
  late final TabController _tabController;

  String _selectedPeriod = 'Todos';
  final List<String> _periodFilters = ['Todos', 'Semanal', 'Mensual', 'Anual', 'Personalizado'];

  @override
  void initState() {
    super.initState();
    _budgetsStream = _repository.getBudgetsStream();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAddBudget() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
    );
    if (result == true && mounted) {
      _repository.refreshData();
    }
  }

  void _navigateToBudgetDetails(Budget budget) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BudgetDetailsScreen(budgetId: budget.id),
      ),
    );
  }

  void _navigateToEditBudget(Budget budget) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditBudgetScreen(budget: budget),
      ),
    );
    // Si la edición fue exitosa, refrescamos los datos para asegurar la consistencia.
    if (result == true && mounted) {
      _repository.refreshData();
    }
  }

  Future<void> _handleDeleteBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.trash,
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Eliminar presupuesto'),
            ],
          ),
          content: Text('¿Seguro que quieres eliminar el presupuesto para "${budget.category}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteBudgetSafely(budget.id);
        EventService.instance.fire(AppEvent.budgetsChanged);
        NotificationHelper.show(
          message: 'Presupuesto eliminado',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message: e.toString().replaceFirst("Exception: ", ""),
          type: NotificationType.error,
        );
      }
    }
  }

  List<Budget> _filterByPeriod(List<Budget> budgets) {
    if (_selectedPeriod == 'Todos') return budgets;

    return budgets.where((budget) {
      switch (_selectedPeriod) {
        case 'Semanal':
          return budget.periodicity == 'weekly';
        case 'Mensual':
          return budget.periodicity == 'monthly';
        case 'Anual':
          return budget.periodicity == 'yearly';
        case 'Personalizado':
          return budget.periodicity == 'custom';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mis',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Presupuestos',
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.withOpacity(0.1),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton.tonalIcon(
                onPressed: _navigateToAddBudget,
                icon: const Icon(Iconsax.add, size: 20),
                label: const Text('Nuevo'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 16),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: colorScheme.surface,
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(text: 'Activos'),
                    Tab(text: 'Histórico'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<Budget>>(
          stream: _budgetsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return _buildSkeletonLoader();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final allBudgets = snapshot.data!;
            final activeBudgets = _filterByPeriod(
              allBudgets.where((b) => b.isActive).toList(),
            );
            final inactiveBudgets = _filterByPeriod(
              allBudgets.where((b) => !b.isActive).toList(),
            );

            return TabBarView(
              controller: _tabController,
              children: [
                _buildBudgetsTab(activeBudgets, isActive: true),
                _buildBudgetsTab(inactiveBudgets, isActive: false),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBudgetsTab(List<Budget> budgets, {required bool isActive}) {
    return Column(
      children: [
        // Filtros de período
        _buildPeriodFilters(),

        // Resumen de presupuestos (solo para activos)
        if (isActive && budgets.isNotEmpty) _buildBudgetSummary(budgets),

        // Lista de presupuestos
        Expanded(
          child: budgets.isEmpty
              ? _buildEmptyTabState(isActive)
              : _buildBudgetsList(budgets, isActive: isActive),
        ),
      ],
    );
  }

  Widget _buildPeriodFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _periodFilters.length,
        itemBuilder: (context, index) {
          final period = _periodFilters[index];
          final isSelected = _selectedPeriod == period;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedPeriod = period);
              },
              labelStyle: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetSummary(List<Budget> budgets) {
    final totalBudget = budgets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalSpent = budgets.fold<double>(0, (sum, b) => sum + b.spentAmount);
    final totalRemaining = totalBudget - totalSpent;
    final overallProgress = totalBudget > 0 ? totalSpent / totalBudget : 0.0;

    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: overallProgress > 0.9
              ? [
                  Colors.red.withOpacity(0.15),
                  Colors.orange.withOpacity(0.1),
                ]
              : [
                  Colors.green.withOpacity(0.15),
                  Colors.teal.withOpacity(0.1),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: overallProgress > 0.9
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: overallProgress > 0.9
                      ? Colors.red.withOpacity(0.2)
                      : Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  overallProgress > 0.9 ? Iconsax.danger : Iconsax.wallet_check,
                  color: overallProgress > 0.9 ? Colors.red : Colors.green,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumen General',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${budgets.length} presupuesto${budgets.length != 1 ? 's' : ''} activo${budgets.length != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(overallProgress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: overallProgress > 0.9 ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Gastado',
                  value: currencyFormat.format(totalSpent),
                  color: Colors.red,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
              Expanded(
                child: _SummaryMetric(
                  label: 'Disponible',
                  value: currencyFormat.format(totalRemaining),
                  color: Colors.green,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey.withOpacity(0.3)),
              Expanded(
                child: _SummaryMetric(
                  label: 'Total',
                  value: currencyFormat.format(totalBudget),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: overallProgress.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                overallProgress > 1.0
                    ? Colors.red
                    : overallProgress > 0.9
                        ? Colors.orange
                        : Colors.green,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildBudgetsList(List<Budget> budgets, {required bool isActive}) {
    return RefreshIndicator(
      onRefresh: () => _repository.refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          return Opacity(
            opacity: isActive ? 1.0 : 0.7,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: BudgetCard(
                budget: budget,
                onTap: () => _navigateToBudgetDetails(budget),
                onEdit: () => _navigateToEditBudget(budget), 
                onDelete: () => _handleDeleteBudget(budget),
              ),
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: (80 * index).ms)
              .slideX(begin: -0.1, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildEmptyTabState(bool isActive) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Iconsax.wallet_add : Iconsax.archive_book,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              isActive ? 'Sin presupuestos activos' : 'Sin historial',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isActive
                  ? _selectedPeriod == 'Todos'
                      ? 'Crea tu primer presupuesto para controlar tus gastos'
                      : 'No hay presupuestos de tipo "$_selectedPeriod" activos'
                  : 'Los presupuestos completados aparecerán aquí',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 15,
              ),
            ),
            if (isActive && _selectedPeriod == 'Todos') ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _navigateToAddBudget,
                icon: const Icon(Iconsax.add_circle),
                label: const Text('Crear presupuesto'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: BudgetCard(budget: Budget.empty()),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/piggy_bank_animation.json',
              width: 280,
              height: 280,
            ),
            const SizedBox(height: 24),
            Text(
              '¡Toma el control!',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Crea presupuestos para controlar tus gastos y alcanzar tus metas financieras',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToAddBudget,
              icon: const Icon(Iconsax.add_circle),
              label: const Text('Crear mi primer presupuesto'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.danger,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Algo salió mal',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _repository.refreshData(),
              icon: const Icon(Iconsax.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET PARA MÉTRICA DEL RESUMEN
// ============================================================================
class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}