// lib/data/goal_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:sasper/models/goal_model.dart';

class GoalRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! GoalRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---

  final _streamController = StreamController<List<Goal>>.broadcast();
  RealtimeChannel? _channel;
  bool _isInitialized = false;

  GoalRepository._privateConstructor();
  static final GoalRepository instance = GoalRepository._privateConstructor();
  
  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] GoalRepository Singleton Initialized and Client Injected.', name: 'GoalRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<Goal>> getGoalsStream() {
    _setupRealtimeSubscription();
    _fetchAndPushData();
    return _streamController.stream;
  }
  
  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo] Setting up realtime subscription for goals...', name: 'GoalRepository');
    _channel = client
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
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("User not authenticated");
      
      final data = await client
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

  Future<void> refreshData() async {
    await _fetchAndPushData();
  }
  
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? iconName,
  }) async {
    try {
      final userId = client.auth.currentUser!.id;
      await client.from('goals').insert({
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
      await client
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
      await client.rpc(
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
      await client.rpc('add_contribution_to_goal', params: {
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
      client.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }
}