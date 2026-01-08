import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/screens/add_goal_screen.dart';
import 'package:sasper/widgets/goals/contribute_to_goal_dialog.dart';
import 'package:sasper/screens/edit_goal_screen.dart';
import 'package:sasper/main.dart';
// --- 1. AÑADIR IMPORTACIÓN DE LA PANTALLA DE NOTAS ---
import 'package:sasper/screens/goal_notes_editor_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with TickerProviderStateMixin {
  final GoalRepository _repository = GoalRepository.instance;
  late final Stream<List<Goal>> _goalsStream;
  late final TabController _tabController;
  bool _showFilters = false;

  final _activeFilters = _GoalFilters();
  final _completedFilters = _GoalFilters();

  @override
  void initState() {
    super.initState();
    _goalsStream = _repository.getGoalsStream();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await _repository.refreshData();
  }

  void _navigateToAddGoal() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddGoalScreen()),
    );
    if (result == true) _repository.refreshData();
  }

  void _navigateToEditGoal(Goal goal) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditGoalScreen(goal: goal)),
    );
    if (result == true) _repository.refreshData();
  }

  // --- 2. CREAR NUEVA FUNCIÓN DE NAVEGACIÓN PARA NOTAS ---
  void _navigateToNotes(Goal goal) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GoalNotesEditorScreen(goal: goal)),
    );
  }
  
  Future<void> _handleDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Iconsax.trash, color: Theme.of(dialogContext).colorScheme.error),
            ),
            const SizedBox(width: 12),
            const Text('Eliminar meta'),
          ]),
          content: Text('¿Estás seguro de eliminar "${goal.name}"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repository.deleteGoalSafely(goal.id);
        _repository.refreshData();
        EventService.instance.fire(AppEvent.goalsChanged);
        NotificationHelper.show(message: 'Meta eliminada exitosamente', type: NotificationType.success);
      } catch (e) {
        NotificationHelper.show(message: e.toString().replaceFirst("Exception: ", ""), type: NotificationType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 160,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
              title: Text(
                'Mis Metas',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 28, color: colorScheme.onSurface),
              ),
              expandedTitleScale: 1.05,
            ),
            actions: [
              IconButton(
                icon: Icon(_showFilters ? Iconsax.filter_remove : Iconsax.filter),
                tooltip: _showFilters ? 'Ocultar filtros' : 'Mostrar filtros',
                onPressed: () => setState(() => _showFilters = !_showFilters),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _navigateToAddGoal,
                icon: const Icon(Iconsax.add, size: 20),
                label: const Text('Nueva'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
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
                  labelStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
                  tabs: const [Tab(text: 'Activas'), Tab(text: 'Completadas')],
                ),
              ),
            ),
          ),
        ],
        body: StreamBuilder<List<Goal>>(
          stream: _goalsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return _buildSkeletonLoader();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final allGoals = snapshot.data ?? [];
            if (allGoals.isEmpty) {
              return _buildEmptyState();
            }

            final activeGoals = _filterGoals(allGoals.where((g) => g.status == GoalStatus.active).toList(), _activeFilters);
            final completedGoals = _filterGoals(allGoals.where((g) => g.status != GoalStatus.active).toList(), _completedFilters);

            return TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: _buildSliversForTab(
                      context: context,
                      goals: activeGoals,
                      filters: _activeFilters,
                      isCompletedTab: false,
                    ),
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: _buildSliversForTab(
                      context: context,
                      goals: completedGoals,
                      filters: _completedFilters,
                      isCompletedTab: true,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildSliversForTab({
    required BuildContext context,
    required List<Goal> goals,
    required _GoalFilters filters,
    required bool isCompletedTab,
  }) {
    if (goals.isEmpty) {
      return [
        SliverFillRemaining(
          child: _buildEmptyFilterState(context, filters),
        )
      ];
    }
    
    return [
      if (_showFilters)
        SliverToBoxAdapter(
          child: _FilterSection(
            filters: filters,
            onChanged: () => setState(() {}),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2),
        ),
      
      if (!isCompletedTab)
        SliverToBoxAdapter(
          child: _QuickStats(goals: goals),
        ),
      
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final goal = goals[index];
              return _GoalCard(
                goal: goal,
                isCompleted: isCompletedTab,
                onEdit: isCompletedTab ? null : () => _navigateToEditGoal(goal),
                onDelete: isCompletedTab ? null : () => _handleDeleteGoal(goal),
                // --- 4. CONECTAR LA FUNCIÓN AL WIDGET DE LA TARJETA ---
                onNotesTap: isCompletedTab ? null : () => _navigateToNotes(goal),
                onContributeSuccess: _handleRefresh,
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: (80 * index).ms)
                  .slideX(begin: -0.1, curve: Curves.easeOutCubic);
            },
            childCount: goals.length,
          ),
        ),
      ),
    ];
  }

  Widget _buildEmptyFilterState(BuildContext context, _GoalFilters filters) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.search_status, size: 80, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 24),
            Text('Sin resultados', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('No hay metas que coincidan con los filtros seleccionados', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 15)),
            if (filters.hasActiveFilters) ...[
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  filters.clear();
                  setState(() {});
                },
                icon: const Icon(Iconsax.refresh),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Goal> _filterGoals(List<Goal> goals, _GoalFilters filters) {
    if (filters.timeframe == null && filters.priority == null) return goals;
    return goals.where((goal) {
      final timeframeMatch = filters.timeframe == null || goal.timeframe == filters.timeframe;
      final priorityMatch = filters.priority == null || goal.priority == filters.priority;
      return timeframeMatch && priorityMatch;
    }).toList();
  }

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        itemBuilder: (context, index) => _GoalCard(goal: Goal.empty(), isCompleted: false, onContributeSuccess: () {}),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Lottie.asset('assets/animations/trophy_animation.json', width: 280, height: 280),
          const SizedBox(height: 24),
          Text('¡Comienza tu viaje!', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text('Crea tu primera meta y empieza a ahorrar para alcanzar tus sueños', textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _navigateToAddGoal,
            icon: const Icon(Iconsax.add_circle),
            label: const Text('Crear mi primera meta'),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), textStyle: const TextStyle(fontSize: 16)),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Iconsax.danger, size: 80, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 24),
          Text('Algo salió mal', style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(error, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _handleRefresh, icon: const Icon(Iconsax.refresh), label: const Text('Reintentar')),
        ]),
      ),
    );
  }
}

class _GoalFilters {
  GoalTimeframe? timeframe;
  GoalPriority? priority;
  
  bool get hasActiveFilters => timeframe != null || priority != null;
  
  void clear() {
    timeframe = null;
    priority = null;
  }
}

class _QuickStats extends StatelessWidget {
  final List<Goal> goals;

  const _QuickStats({required this.goals});

  @override
  Widget build(BuildContext context) {
    final totalSaved = goals.fold<double>(0, (sum, g) => sum + g.currentAmount);
    final avgProgress = goals.isNotEmpty ? goals.fold<double>(0, (sum, g) => sum + g.progress) / goals.length : 0;

    return Container(
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Iconsax.chart_21,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Text(
                'Resumen General',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Total Ahorrado',
                  value: NumberFormat.compactCurrency(
                    locale: 'es_CO',
                    symbol: '\$',
                    decimalDigits: 0,
                  ).format(totalSaved),
                  icon: Iconsax.wallet_money,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.2),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Progreso Promedio',
                  value: '${(avgProgress * 100).toStringAsFixed(0)}%',
                  icon: Iconsax.chart_success,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _FilterSection extends StatelessWidget {
  final _GoalFilters filters;
  final VoidCallback onChanged;

  const _FilterSection({required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Iconsax.filter, size: 20, color: colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Filtros',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (filters.hasActiveFilters)
                TextButton.icon(
                  onPressed: () {
                    filters.clear();
                    onChanged();
                  },
                  icon: const Icon(Iconsax.refresh, size: 16),
                  label: const Text('Limpiar'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Plazo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GoalTimeframe.values.where((tf) => tf != GoalTimeframe.custom).map((timeframe) {
              final isSelected = filters.timeframe == timeframe;
              return ChoiceChip(
                label: Text(GoalHelpers.getTimeframeText(timeframe)),
                selected: isSelected,
                onSelected: (selected) {
                  filters.timeframe = selected ? timeframe : null;
                  onChanged();
                },
                avatar: isSelected
                    ? const Icon(Iconsax.tick_circle, size: 18)
                    : null,
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Prioridad',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GoalPriority.values.map((priority) {
              final isSelected = filters.priority == priority;
              return ChoiceChip(
                label: Text(GoalHelpers.getPriorityText(priority)),
                selected: isSelected,
                onSelected: (selected) {
                  filters.priority = selected ? priority : null;
                  onChanged();
                },
                avatar: Icon(
                  GoalHelpers.getPriorityIcon(priority),
                  size: 16,
                  color: isSelected
                      ? GoalHelpers.getPriorityColor(context, priority)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool isCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onNotesTap; // --- 3.A. AÑADIR NUEVO CALLBACK
  final VoidCallback onContributeSuccess;

  const _GoalCard({
    required this.goal,
    required this.isCompleted,
    this.onEdit,
    this.onDelete,
    this.onNotesTap, // --- 3.B. AÑADIR AL CONSTRUCTOR
    required this.onContributeSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final priorityColor = GoalHelpers.getPriorityColor(context, goal.priority);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCompleted
              ? Colors.green.withOpacity(0.3)
              : colorScheme.outlineVariant,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCompleted
                ? Colors.green.withOpacity(0.1)
                : colorScheme.shadow.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      priorityColor,
                      priorityColor.withOpacity(0.5),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 16),
                  _buildChips(context),
                  if (!isCompleted) ...[
                    const SizedBox(height: 20),
                    _buildAmountSection(context),
                    const SizedBox(height: 16),
                    _buildProgressBar(context),
                    const SizedBox(height: 12),
                    _buildBottomInfo(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isCompleted)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Iconsax.verify5, color: Colors.green, size: 24),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              goal.category?.icon ?? Iconsax.flag,
              color: colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                goal.name,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationThickness: 2,
                ),
              ),
              if (isCompleted) ...[
                const SizedBox(height: 4),
                Text(
                  'Meta alcanzada',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (!isCompleted && onEdit != null && onDelete != null)
          // --- 3.C. MODIFICAR EL MENÚ POP-UP ---
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'notes') onNotesTap?.call(); // Llamar a la nueva función
              if (value == 'delete') onDelete?.call();
            },
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(children: [Icon(Iconsax.edit, size: 20), SizedBox(width: 12), Text('Editar')]),
              ),
              // Añadir la nueva opción de "Notas"
              const PopupMenuItem(
                value: 'notes',
                child: Row(children: [Icon(Iconsax.document_text_1, size: 20), SizedBox(width: 12), Text('Notas')]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [Icon(Iconsax.trash, size: 20), SizedBox(width: 12), Text('Eliminar')]),
              ),
            ],
            icon: const Icon(Iconsax.more),
          ),
      ],
    );
  }

  Widget _buildChips(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _InfoChip(
          icon: GoalHelpers.getPriorityIcon(goal.priority),
          label: GoalHelpers.getPriorityText(goal.priority),
          color: GoalHelpers.getPriorityColor(context, goal.priority),
        ),
        _InfoChip(
          icon: Iconsax.clock,
          label: GoalHelpers.getTimeframeText(goal.timeframe),
          color: Theme.of(context).colorScheme.tertiary,
        ),
        if (goal.category != null)
          _InfoChip(
            icon: goal.category!.icon ?? Iconsax.folder_2,
            label: goal.category!.name,
            color: goal.category!.colorAsObject,
          ),
        if (isCompleted)
          _InfoChip(
            icon: Iconsax.wallet_money,
            label: NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(goal.targetAmount),
            color: Theme.of(context).colorScheme.primary,
          ),
      ],
    );
  }

  Widget _buildAmountSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final remaining = goal.targetAmount - goal.currentAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ahorrado', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(currencyFormat.format(goal.currentAmount), style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Column(children: [
                Text('Falta', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(currencyFormat.format(remaining), style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: colorScheme.primary)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _showContributeDialog(context),
                icon: const Icon(Iconsax.add_circle, size: 18),
                label: const Text('Aportar'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Iconsax.tag, size: 16),
                const SizedBox(width: 6),
                Text(currencyFormat.format(goal.targetAmount), style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Progreso', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant)),
          Text('${(goal.progress * 100).toStringAsFixed(1)}%', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary)),
        ]),
        const SizedBox(height: 8),
        Stack(children: [
          Container(height: 12, decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(6))),
          FractionallySizedBox(
            widthFactor: goal.progress.clamp(0.0, 1.0),
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.7)]),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [BoxShadow(color: colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
              ),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildBottomInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      children: [
        if (goal.targetDate != null)
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Iconsax.calendar_1, size: 16, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    DateFormat.yMMMd('es_CO').format(goal.targetDate!),
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  void _showContributeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
          child: ContributeToGoalDialog(goal: goal, onSuccess: onContributeSuccess),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

class GoalHelpers {
  static String getPriorityText(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low: return 'Baja';
      case GoalPriority.medium: return 'Media';
      case GoalPriority.high: return 'Alta';
    }
  }

  static IconData getPriorityIcon(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low: return Iconsax.arrow_down;
      case GoalPriority.medium: return Iconsax.minus;
      case GoalPriority.high: return Iconsax.arrow_up_3;
    }
  }

  static Color getPriorityColor(BuildContext context, GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low: return Colors.blue;
      case GoalPriority.medium: return Colors.orange;
      case GoalPriority.high: return Colors.red;
    }
  }

  static String getTimeframeText(GoalTimeframe timeframe) {
    switch (timeframe) {
      case GoalTimeframe.short: return 'Corto Plazo';
      case GoalTimeframe.medium: return 'Medio Plazo';
      case GoalTimeframe.long: return 'Largo Plazo';
      case GoalTimeframe.custom: return 'Personalizado';
    }
  }
}