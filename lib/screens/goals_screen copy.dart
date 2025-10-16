// lib/screens/goals_screen.dart

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

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> with TickerProviderStateMixin {
  final GoalRepository _repository = GoalRepository.instance;
  late final Stream<List<Goal>> _goalsStream;
  late final TabController _tabController;

  // Filtros separados por pestaña
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

  Future<void> _handleDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar la meta "${goal.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
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
        await _repository.deleteGoalSafely(goal.id);
        _repository.refreshData();
        EventService.instance.fire(AppEvent.goalsChanged);
        NotificationHelper.show(
          message: 'Meta eliminada.',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Mis Metas',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square),
            tooltip: 'Añadir Meta',
            onPressed: _navigateToAddGoal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Activas'),
            Tab(text: 'Completadas'),
          ],
        ),
      ),
      body: StreamBuilder<List<Goal>>(
        stream: _goalsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildSkeletonLoader();
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar metas: ${snapshot.error}'));
          }

          final allGoals = snapshot.data ?? [];
          
          if (allGoals.isEmpty) {
            return _buildEmptyState();
          }

          final activeGoals = _filterGoals(
            allGoals.where((g) => g.status == GoalStatus.active).toList(),
            _activeFilters,
          );

          final completedGoals = _filterGoals(
            allGoals.where((g) => g.status != GoalStatus.active).toList(),
            _completedFilters,
          );

          return TabBarView(
            controller: _tabController,
            children: [
              _GoalsTab(
                goals: activeGoals,
                filters: _activeFilters,
                onRefresh: _handleRefresh,
                onFilterChanged: () => setState(() {}),
                onEdit: _navigateToEditGoal,
                onDelete: _handleDeleteGoal,
                isCompletedTab: false,
              ),
              _GoalsTab(
                goals: completedGoals,
                filters: _completedFilters,
                onRefresh: _handleRefresh,
                onFilterChanged: () => setState(() {}),
                isCompletedTab: true,
              ),
            ],
          );
        },
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: 4,
        itemBuilder: (context, index) => _GoalCard(
          goal: Goal.empty(),
          isCompleted: false,
          onContributeSuccess: () {},
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/trophy_animation.json',
                width: 250,
                height: 250,
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no tienes metas',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '¡Usa el botón (+) para crear tu primera meta y empezar a ahorrar para algo increíble!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// ============================================================================
// CLASE AUXILIAR PARA FILTROS
// ============================================================================
class _GoalFilters {
  GoalTimeframe? timeframe;
  GoalPriority? priority;
}

// ============================================================================
// WIDGET DE PESTAÑA (EXTRAE LÓGICA REPETIDA)
// ============================================================================
class _GoalsTab extends StatelessWidget {
  final List<Goal> goals;
  final _GoalFilters filters;
  final Future<void> Function() onRefresh;
  final VoidCallback onFilterChanged;
  final void Function(Goal)? onEdit;
  final void Function(Goal)? onDelete;
  final bool isCompletedTab;

  const _GoalsTab({
    required this.goals,
    required this.filters,
    required this.onRefresh,
    required this.onFilterChanged,
    required this.isCompletedTab,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _FilterSection(
            filters: filters,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 16),
          if (goals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('No hay metas que coincidan con los filtros.'),
              ),
            )
          else
            ..._buildAnimatedGoalsList(context),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedGoalsList(BuildContext context) {
    return List.generate(goals.length, (index) {
      final goal = goals[index];
      return _GoalCard(
        goal: goal,
        isCompleted: isCompletedTab,
        onEdit: onEdit != null ? () => onEdit!(goal) : null,
        onDelete: onDelete != null ? () => onDelete!(goal) : null,
        onContributeSuccess: onRefresh,
      )
          .animate()
          .fadeIn(duration: 500.ms, delay: (100 * index).ms)
          .slideY(begin: 0.2, curve: Curves.easeOutCubic);
    });
  }
}

// ============================================================================
// SECCIÓN DE FILTROS (WIDGET SEPARADO)
// ============================================================================
class _FilterSection extends StatelessWidget {
  final _GoalFilters filters;
  final VoidCallback onChanged;

  const _FilterSection({required this.filters, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Filtrar por Plazo', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: GoalTimeframe.values.map((timeframe) {
            return FilterChip(
              label: Text(GoalHelpers.getTimeframeText(timeframe)),
              selected: filters.timeframe == timeframe,
              onSelected: (selected) {
                filters.timeframe = selected ? timeframe : null;
                onChanged();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Text('Filtrar por Prioridad', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: GoalPriority.values.map((priority) {
            return FilterChip(
              label: Text(GoalHelpers.getPriorityText(priority)),
              selected: filters.priority == priority,
              onSelected: (selected) {
                filters.priority = selected ? priority : null;
                onChanged();
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================================================
// TARJETA DE META (UNIFICADA PARA ACTIVAS Y COMPLETADAS)
// ============================================================================
class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool isCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onContributeSuccess;

  const _GoalCard({
    required this.goal,
    required this.isCompleted,
    this.onEdit,
    this.onDelete,
    required this.onContributeSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (!isCompleted) ...[
              const SizedBox(height: 12),
              _buildAmountRow(context),
              const SizedBox(height: 12),
              _buildProgressBar(context),
              const SizedBox(height: 8),
              _buildBottomInfo(context),
            ],
            const Divider(height: 24),
            _buildChips(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        if (isCompleted) ...[
          Icon(Iconsax.verify, color: Colors.green.shade600),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            goal.name,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationThickness: 2,
            ),
          ),
        ),
        if (isCompleted)
          Text(
            NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(goal.targetAmount),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          )
        else if (onEdit != null && onDelete != null)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit?.call();
              if (value == 'delete') onDelete?.call();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Iconsax.edit),
                  title: Text('Editar Meta'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  leading: Icon(Iconsax.trash),
                  title: Text('Eliminar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            icon: const Icon(Iconsax.more),
          ),
      ],
    );
  }

  Widget _buildAmountRow(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Flexible(
          child: Text(
            'Ahorrado: ${currencyFormat.format(goal.currentAmount)}',
            style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: () => _showContributeDialog(context),
          icon: const Icon(Iconsax.additem, size: 18),
          label: const Text('Aportar'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Meta: ${currencyFormat.format(goal.targetAmount)}',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: LinearProgressIndicator(
        value: goal.progress,
        minHeight: 10,
        backgroundColor: colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
      ),
    );
  }

  Widget _buildBottomInfo(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (goal.targetDate != null)
          Row(
            children: [
              Icon(Iconsax.calendar_1, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                DateFormat.yMMMd('es_CO').format(goal.targetDate!),
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          )
        else
          const Spacer(),
        Text(
          '${(goal.progress * 100).toStringAsFixed(1)}%',
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onSurface),
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
      ],
    );
  }

  void _showContributeDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ContributeToGoalDialog(
        goal: goal,
        onSuccess: onContributeSuccess,
      ),
    );
  }
}

// ============================================================================
// CHIP DE INFORMACIÓN (WIDGET REUTILIZABLE)
// ============================================================================
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HELPERS (CENTRALIZADOS)
// ============================================================================
class GoalHelpers {
  static String getPriorityText(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low:
        return 'Baja';
      case GoalPriority.medium:
        return 'Media';
      case GoalPriority.high:
        return 'Alta';
    }
  }

  static IconData getPriorityIcon(GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low:
        return Iconsax.arrow_down;
      case GoalPriority.medium:
        return Iconsax.minus;
      case GoalPriority.high:
        return Iconsax.arrow_up_3;
    }
  }

  static Color getPriorityColor(BuildContext context, GoalPriority priority) {
    switch (priority) {
      case GoalPriority.low:
        return Colors.blue;
      case GoalPriority.medium:
        return Colors.orange;
      case GoalPriority.high:
        return Colors.red;
    }
  }

  static String getTimeframeText(GoalTimeframe timeframe) {
    switch (timeframe) {
      case GoalTimeframe.short:
        return 'Corto Plazo';
      case GoalTimeframe.medium:
        return 'Medio Plazo';
      case GoalTimeframe.long:
        return 'Largo Plazo';
    }
  }
}