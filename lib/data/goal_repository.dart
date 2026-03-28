// lib/data/goal_repository.dart

import 'package:sasper/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/services/widget_service.dart';

class GoalRepository {
  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<Goal>>.broadcast();
  RealtimeChannel? _channel;

  GoalRepository._internal();
  static final GoalRepository instance = GoalRepository._internal();

  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ GoalRepository inicializado PEREZOSAMENTE.',
          name: 'GoalRepository');
    }
  }

  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception(
          '¡ERROR FATAL! Supabase no está disponible para GoalRepository.');
    }
    return _supabase!;
  }

  // ── Streams y datos ───────────────────────────────────────────────────────

  Stream<List<Goal>> getGoalsStream() {
    _fetchAndPushData();
    return _streamController.stream;
  }

  Future<List<Goal>> getActiveGoals() async {
    _ensureInitialized();
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final data = await client
          .from('goals')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active')
          .order('target_date', ascending: true);

      return (data as List).map((m) => Goal.fromMap(m)).toList();
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo metas activas: $e',
          name: 'GoalRepository');
      return [];
    }
  }

  Future<void> refreshData() => _fetchAndPushData();

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<Goal> addGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? iconName,
    required GoalTimeframe timeframe,
    required GoalPriority priority,
    String? categoryId,
    GoalSavingsFrequency? savingsFrequency,
    int? savingsDayOfWeek,
    int? savingsDayOfMonth,
    double? savingsAmount,
    DateTime? nextReminderDate,
    // ── Nuevos parámetros de hora ──────────────────────────────────────────
    int notificationHour   = 9,
    int notificationMinute = 0,
  }) async {
    try {
      final userId = client.auth.currentUser!.id;

      // Fecha objetivo como string DATE (columna DATE en BD)
      final dateString = targetDate != null
          ? targetDate.toIso8601String().split('T')[0]
          : null;

      // next_reminder_date ahora es TIMESTAMPTZ — mandamos ISO completo en UTC
      final reminderString = nextReminderDate != null
          ? nextReminderDate.toUtc().toIso8601String()
          : null;

      final response = await client
          .from('goals')
          .insert({
            'user_id':             userId,
            'name':                name,
            'target_amount':       targetAmount,
            'current_amount':      0,
            'status':              'active',
            'target_date':         dateString,
            'icon_name':           iconName,
            'timeframe':           timeframe.name,
            'priority':            priority.name,
            'category_id':         categoryId,
            'savings_frequency':   savingsFrequency?.name,
            'savings_day_of_week': savingsDayOfWeek,
            'savings_day_of_month':savingsDayOfMonth,
            'savings_amount':      savingsAmount,
            'next_reminder_date':  reminderString,
            'notification_hour':   notificationHour,
            'notification_minute': notificationMinute,
          })
          .select()
          .single();

      developer.log('✅ [Repo] Meta "$name" añadida.', name: 'GoalRepository');
      return Goal.fromMap(response);
    } catch (e) {
      developer.log('🔥 [Repo] Error añadiendo meta: $e',
          name: 'GoalRepository');
      throw Exception('No se pudo crear la meta.');
    }
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      // next_reminder_date: TIMESTAMPTZ → ISO completo en UTC
      final reminderString = goal.nextReminderDate != null
          ? goal.nextReminderDate!.toUtc().toIso8601String()
          : null;

      await client
          .from('goals')
          .update({
            'name':                goal.name,
            'target_amount':       goal.targetAmount,
            'target_date':         goal.targetDate?.toIso8601String().split('T')[0],
            'icon_name':           goal.iconName,
            'timeframe':           goal.timeframe.name,
            'priority':            goal.priority.name,
            'category_id':         goal.categoryId,
            'notes_content':       goal.notesContent,
            'savings_frequency':   goal.savingsFrequency?.name,
            'savings_day_of_week': goal.savingsDayOfWeek,
            'savings_day_of_month':goal.savingsDayOfMonth,
            'savings_amount':      goal.savingsAmount,
            'next_reminder_date':  reminderString,
            'notification_hour':   goal.notificationHour,
            'notification_minute': goal.notificationMinute,
          })
          .eq('id', goal.id);

      developer.log('✅ [Repo] Meta actualizada.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error actualizando meta: $e',
          name: 'GoalRepository');
      throw Exception('No se pudo actualizar la meta.');
    }
  }

  Future<void> deleteGoalSafely(String goalId) async {
    try {
      await client.rpc(
        'delete_goal_safely',
        params: {'goal_id_to_delete': goalId},
      );
      await NotificationService.instance.cancelGoalReminder(goalId);
    } catch (e) {
      developer.log('🔥 [Repo] Error en delete_goal_safely: $e',
          name: 'GoalRepository');
      throw Exception('No se pudo eliminar la meta.');
    }
  }

  Future<void> addContribution({
    required String goalId,
    required String accountId,
    required double amount,
  }) async {
    try {
      await client.rpc('add_contribution_to_goal', params: {
        'goal_id_input':     goalId,
        'account_id_input':  accountId,
        'amount_input':      amount,
      });
      developer.log('✅ [Repo] Aportación registrada.', name: 'GoalRepository');
      await NotificationService.instance.refreshGoalSchedules();
    } catch (e) {
      developer.log('🔥 [Repo] Error al registrar aportación: $e',
          name: 'GoalRepository');
      throw Exception('No se pudo realizar la aportación.');
    }
  }

  void dispose() {
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // ── Privados ──────────────────────────────────────────────────────────────

  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    _channel = _supabase!
        .channel('public:goals')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'goals',
          filter: PostgresChangeFilter(
              type:   PostgresChangeFilterType.eq,
              column: 'user_id',
              value:  userId),
          callback: (_) => _fetchAndPushData(),
        )
        .subscribe();
  }

  Future<void> _fetchAndPushData() async {
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final data = await client
          .from('goals')
          .select('*, categories(*)')
          .eq('user_id', userId)
          .order('target_date', ascending: true);

      final goals = (data as List).map((m) => Goal.fromMap(m)).toList();

      if (!_streamController.isClosed) {
        _streamController.add(goals);
        WidgetService.updateGoalsWidget();
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo metas: $e',
          name: 'GoalRepository');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }
}