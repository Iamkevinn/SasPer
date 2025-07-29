// lib/screens/goals_screen.dart (VERSIÓN FINAL CON SINGLETON)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sasper/screens/add_goal_screen.dart';
import 'package:sasper/widgets/goals/contribute_to_goal_dialog.dart';
import 'package:sasper/screens/edit_goal_screen.dart';
import 'package:sasper/main.dart';

class GoalsScreen extends StatefulWidget {
  // El repositorio ya no se pasa como parámetro en el constructor.
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio.
  final GoalRepository _repository = GoalRepository.instance;
  late final Stream<List<Goal>> _goalsStream;

  @override
  void initState() {
    super.initState();
    // Obtenemos el stream del repositorio singleton.
    _goalsStream = _repository.getGoalsStream();
  }

  // El pull-to-refresh ahora llama al método de refresco del singleton.
  Future<void> _handleRefresh() async {
    await _repository.refreshData();
  }

  void _navigateToAddGoal() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddGoalScreen()),
    );
    // Si se creó una meta, le damos el "empujón" para refrescar.
    if (result == true) {
      _repository.refreshData();
    }
  }

  void _navigateToEditGoal(Goal goal) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditGoalScreen(goal: goal)),
    );
    // Si se editó la meta, refrescamos.
    if (result == true) {
      _repository.refreshData();
    }
  }

  Future<void> _handleDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      // 1. Usamos el context del Navigator global.
      context: navigatorKey.currentContext!,
      
      // 2. Usamos 'dialogContext' para el builder.
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar la meta "${goal.name}"?'),
          actions: [
            // 3. Usamos 'dialogContext' para cerrar el diálogo.
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              // 4. Usamos 'dialogContext' para obtener el tema.
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer),
              // 5. Y para cerrar el diálogo.
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
        
        _repository.refreshData(); // "Nudge" para asegurar inmediatez
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
        title: Text('Mis Metas', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
      ),
      body: StreamBuilder<List<Goal>>(
        stream: _goalsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar metas: ${snapshot.error}'));
          }

          final allGoals = snapshot.data ?? [];
          if (allGoals.isEmpty) {
            return _buildEmptyState();
          }

          final activeGoals = allGoals.where((g) => g.status == GoalStatus.active).toList();
          final completedGoals = allGoals.where((g) => g.status != GoalStatus.active).toList();

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 100.0),
              children: [
                if (activeGoals.isNotEmpty)
                  _buildSectionHeader('Metas Activas'),
                _buildGoalsList(activeGoals),
                
                if (completedGoals.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('Metas Completadas'),
                  _buildGoalsList(completedGoals, isCompleted: true),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGoalsList(List<Goal> goals, {bool isCompleted = false}) {
    return AnimationLimiter(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: goals.length,
        itemBuilder: (context, index) {
          final goal = goals[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: FadeInAnimation(
                child: _GoalCard(
                  goal: goal,
                  isCompleted: isCompleted,
                  onEdit: isCompleted ? null : () => _navigateToEditGoal(goal),
                  onDelete: () => _handleDeleteGoal(goal),
                  onContributeSuccess: () {
                    // "Nudge" para asegurar la actualización del progreso
                    _repository.refreshData(); 
                  },
                ),
              ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const SizedBox(height: 150),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.flag_2, size: 80, color: Theme.of(context).colorScheme.secondary),
            const SizedBox(height: 20),
            Text(
              'Aún no tienes metas',
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              '¡Usa el botón (+) para crear tu primera meta y empezar a ahorrar!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}


// --- WIDGET _GoalCard MODIFICADO ---

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool isCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onContributeSuccess;

  const _GoalCard({
    required this.goal, 
    this.isCompleted = false,
    this.onEdit,
    this.onDelete,
    required this.onContributeSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final colorScheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: isCompleted ? 0.75 : 1.0,
      child: Card(
        elevation: 0,
        color: Theme.of(context).colorScheme.surfaceContainer,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(goal.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  if (!isCompleted)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') onEdit?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Iconsax.edit), title: Text('Editar Meta'))),
                        const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Iconsax.trash), title: Text('Eliminar'))),
                      ],
                      icon: const Icon(Iconsax.more),
                    )
                  else
                    Icon(Iconsax.verify, color: Colors.green, size: 24),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Ahorrado: ${currencyFormat.format(goal.currentAmount)}',
                      style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isCompleted)
                    TextButton.icon(
                      onPressed: () => _showContributeDialog(context, goal),
                      icon: const Icon(Iconsax.additem, size: 18),
                      label: const Text('Aportar'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Meta: ${currencyFormat.format(goal.targetAmount)}',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 10,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? Colors.green : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContributeDialog(BuildContext context, Goal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return ContributeToGoalDialog(
          goal: goal,
          onSuccess: onContributeSuccess,
        );
      },
    );
  }
}