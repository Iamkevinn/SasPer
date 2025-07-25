// lib/screens/goals_screen.dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sasper/screens/add_goal_screen.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/widgets/goals/contribute_to_goal_dialog.dart';
import 'package:sasper/screens/edit_goal_screen.dart';

class GoalsScreen extends StatefulWidget {
  final GoalRepository repository;
  const GoalsScreen({super.key, required this.repository});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final Stream<List<Goal>> _goalsStream;

  @override
  void initState() {
    super.initState();
    _goalsStream = widget.repository.getGoalsStream();
  }

  Future<void> _handleRefresh() async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void navigateToAddGoal() {
    Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AddGoalScreen(goalRepository: widget.repository),
    ));
  }
  Future<void> _deleteGoal(String goalId, String goalName) async {
    try {
      await widget.repository.deleteGoal(goalId);
      if (mounted) {
        NotificationHelper.show(
            context: context,
            message: 'Meta "$goalName" eliminada.',
            type: NotificationType.success,
          );
      }

    } catch (e) {
      if (mounted) {
        NotificationHelper.show(
            context: context,
            message: 'Error al eliminar la meta: ${e.toString()}',
            type: NotificationType.error,
          );
      }
    }
  }

  // ---- NUEVA FUNCIÓN PARA NAVEGAR A EDITAR ----
  void _navigateToEditGoal(Goal goal) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditGoalScreen(goalRepository: widget.repository, goal: goal),
    ));
  }

  // ---- FUNCIÓN DE BORRADO ACTUALIZADA PARA SER SEGURA ----
  Future<void> _handleDeleteGoal(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar la meta "${goal.name}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Usamos la nueva función segura
        await widget.repository.deleteGoalSafely(goal.id); 
        NotificationHelper.show(
            context: context,
            message: 'Meta eliminada.',
            type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
            context: context,
            message: e.toString(), // El repo ya formatea el error
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
          // --- ¡BOTÓN AÑADIDO AQUÍ! ---
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

  // --- ¡DEFINICIÓN AÑADIDA AQUÍ! ---
  void _navigateToAddGoal() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddGoalScreen(goalRepository: widget.repository),
    ));
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
                // REEMPLAZAMOS EL DISMISSIBLE POR EL _GoalCard con acciones
                child: _GoalCard(
                  goal: goal,
                  isCompleted: isCompleted,
                  onEdit: isCompleted ? null : () => _navigateToEditGoal(goal), // No se puede editar si ya está completada
                  onDelete: () => _handleDeleteGoal(goal),
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
            elevation: 0,
            color: Theme.of(context).scaffoldBackgroundColor,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 24.0,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                      Container(width: 80, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  ),
                ],
              ),
            ),
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

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final bool isCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _GoalCard({
    required this.goal, 
    this.isCompleted = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'ES_CO', symbol: '\$');
    final colorScheme = Theme.of(context).colorScheme;
    final onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final cardColor = isCompleted ? colorScheme.onSurfaceVariant : onSurfaceColor;

    return Opacity(
      opacity: isCompleted ? 0.75 : 1.0,
      child: Card(
        elevation: isCompleted ? 0 : 2,
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
                  // Si no está completada, mostramos el menú de opciones
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
                      style: TextStyle(
                        color: isCompleted ? cardColor : colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
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
                          DateFormat.yMMMd('ES_CO').format(goal.targetDate!),
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    )
                  else
                    const Spacer(),
                  Text(
                    '${(goal.progress * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontWeight: FontWeight.bold, color: cardColor),
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
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: ContributeToGoalDialog(
            goal: goal,
            // --- ¡AQUÍ ESTÁ LA CORRECCIÓN! ---
            // Añadimos el callback `onSuccess` requerido por el constructor.
            // No necesita hacer nada, ya que el stream se encarga de la UI.
            onSuccess: () {
              if (kDebugMode) {
                print('Aportación exitosa. El diálogo se cerrará y el stream refrescará la lista.');
              }
            },
          ),
        );
      },
    );
  }
}