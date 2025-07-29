// lib/data/goal_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:sasper/models/goal_model.dart';

class GoalRepository {
  // 1. Cliente 'late final'.
  late final SupabaseClient _client;

  final _streamController = StreamController<List<Goal>>.broadcast();
  RealtimeChannel? _channel;

  // 2. Constructor privado.
  GoalRepository._privateConstructor();
  
  // 3. Instancia estática.
  static final GoalRepository instance = GoalRepository._privateConstructor();
  
  // 4. Método de inicialización.
  void initialize(SupabaseClient client) {
    _client = client;
    developer.log('✅ [Repo] GoalRepository Singleton Initialized and Client Injected.', name: 'GoalRepository');
  }

  /// Devuelve un stream con la lista de metas del usuario.
  Stream<List<Goal>> getGoalsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushData();
    return _streamController.stream;
  }
  
  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for goals...', name: 'GoalRepository');
    _channel = _client
        .channel('public:goals')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'goals',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime change detected in goals. Refetching...', name: 'GoalRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }
  
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Fetching all goals...', name: 'GoalRepository');
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");
      
      final data = await _client
          .from('goals')
          .select()
          .eq('user_id', userId)
          .order('target_date', ascending: true);
          
      final goals = (data as List).map((map) => Goal.fromMap(map)).toList();
      
      if (!_streamController.isClosed) {
        _streamController.add(goals);
        developer.log('✅ [Repo] Pushed ${goals.length} goals to the stream.', name: 'GoalRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error fetching goals: $e', name: 'GoalRepository');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }

  /// Fuerza una recarga manual de los datos de las metas.
  Future<void> refreshData() async {
    await _fetchAndPushData();
  }
  
  // --- MÉTODOS CRUD (NO NECESITAN CAMBIOS) ---

  Future<void> addGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? iconName,
  }) async {
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('goals').insert({
        'user_id': userId,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': 0,
        'status': 'active',
        'target_date': targetDate?.toIso8601String(),
        'icon_name': iconName,
      });
      developer.log('✅ [Repo] Goal "$name" added successfully.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error adding goal: $e', name: 'GoalRepository');
      throw Exception('No se pudo crear la meta.');
    }
  }

  Future<void> updateGoal(Goal goal) async {
    try {
      await _client
          .from('goals')
          .update({
            'name': goal.name,
            'target_amount': goal.targetAmount,
            'target_date': goal.targetDate?.toIso8601String(),
            'icon_name': goal.iconName,
          })
          .eq('id', goal.id);
      developer.log('✅ [Repo] Goal updated successfully.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error updating goal: $e', name: 'GoalRepository');
      throw Exception('No se pudo actualizar la meta.');
    }
  }
  
  Future<void> deleteGoalSafely(String goalId) async {
    try {
      await _client.rpc(
        'delete_goal_safely',
        params: {'goal_id_to_delete': goalId},
      );
    } catch (e) {
      developer.log('🔥 [Repo] Error in RPC delete_goal_safely: $e', name: 'GoalRepository');
      throw Exception('No se pudo eliminar la meta.');
    }
  }

  Future<void> addContribution({
    required String goalId,
    required String accountId,
    required double amount,
  }) async {
    try {
      await _client.rpc('add_contribution_to_goal', params: {
        'goal_id_input': goalId,
        'account_id_input': accountId,
        'amount_input': amount,
      });
      developer.log('✅ [Repo] Contribution added successfully.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error adding contribution: $e', name: 'GoalRepository');
      throw Exception('No se pudo realizar la aportación.');
    }
  }

  void dispose() {
    developer.log('❌ [Repo] Disposing GoalRepository resources.', name: 'GoalRepository');
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}