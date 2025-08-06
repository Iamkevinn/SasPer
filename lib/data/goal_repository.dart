// lib/data/goal_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';
import 'package:sasper/models/goal_model.dart';

class GoalRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;
  final _streamController = StreamController<List<Goal>>.broadcast();
  RealtimeChannel? _channel;

  // Constructor privado para forzar el uso del Singleton `instance`.
  GoalRepository._internal();
  static final GoalRepository instance = GoalRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  void _ensureInitialized() {
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _setupRealtimeSubscription();
      _isInitialized = true;
      developer.log('✅ GoalRepository inicializado PEREZOSAMENTE.', name: 'GoalRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para GoalRepository.");
    }
    return _supabase!;
  }

  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de todas las metas del usuario.
  Stream<List<Goal>> getGoalsStream() {
    _fetchAndPushData();
    return _streamController.stream;
  }
  
  // =================================================================
  // NUEVO MÉTODO AÑADIDO
  // =================================================================
  /// Obtiene una lista de todas las metas activas del usuario una sola vez.
  /// Perfecto para cargas iniciales o actualizaciones de widgets.
  Future<List<Goal>> getActiveGoals() async {
    _ensureInitialized(); // Nos aseguramos de que el cliente de Supabase esté listo.
    developer.log('🔄 [Repo] Obteniendo metas activas (una vez)...', name: 'GoalRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        developer.log('⚠️ [Repo] Intento de obtener metas sin usuario autenticado.', name: 'GoalRepository');
        return []; // Retorna lista vacía si no hay usuario
      }
      
      final data = await client
          .from('goals')
          .select()
          .eq('user_id', userId)
          .eq('status', 'active') // Filtramos solo por metas activas
          .order('target_date', ascending: true);
          
      final goals = (data as List).map((map) => Goal.fromMap(map)).toList();
      developer.log('✅ [Repo] ${goals.length} metas activas obtenidas con éxito.', name: 'GoalRepository');
      return goals;

    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo metas activas: $e', name: 'GoalRepository');
      // En lugar de lanzar una excepción que podría romper la UI, 
      // devolvemos una lista vacía y registramos el error.
      return [];
    }
  }
  
  /// Vuelve a cargar los datos de las metas.
  Future<void> refreshData() => _fetchAndPushData();
  
  /// Añade una nueva meta para el usuario actual.
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
      developer.log('✅ [Repo] Meta "$name" añadida con éxito.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error añadiendo meta: $e', name: 'GoalRepository');
      throw Exception('No se pudo crear la meta.');
    }
  }

  /// Actualiza una meta existente.
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
      developer.log('✅ [Repo] Meta actualizada con éxito.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error actualizando meta: $e', name: 'GoalRepository');
      throw Exception('No se pudo actualizar la meta.');
    }
  }
  
  /// Llama a un RPC para eliminar una meta y sus transacciones asociadas.
  Future<void> deleteGoalSafely(String goalId) async {
    try {
      await client.rpc(
        'delete_goal_safely',
        params: {'goal_id_to_delete': goalId},
      );
    } catch (e) {
      developer.log('🔥 [Repo] Error en RPC delete_goal_safely: $e', name: 'GoalRepository');
      throw Exception('No se pudo eliminar la meta.');
    }
  }

  /// Llama a un RPC para registrar una contribución a una meta.
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
      developer.log('✅ [Repo] Aportación a meta registrada con éxito.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error al registrar aportación: $e', name: 'GoalRepository');
      throw Exception('No se pudo realizar la aportación.');
    }
  }

  /// Libera los recursos del repositorio.
  void dispose() {
    developer.log('❌ [Repo] Liberando recursos de GoalRepository.', name: 'GoalRepository');
    if (_channel != null) {
      _supabase?.removeChannel(_channel!);
      _channel = null;
    }
    _streamController.close();
  }

  // --- MÉTODOS PRIVADOS ---

  /// Configura la suscripción de Realtime para la tabla de metas.
  void _setupRealtimeSubscription() {
    if (_channel != null) return;
    final userId = _supabase?.auth.currentUser?.id;
    if (userId == null) return;

    developer.log('📡 [Repo-Lazy] Configurando Realtime para Metas...', name: 'GoalRepository');
    _channel = _supabase!
        .channel('public:goals')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'goals',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) {
            developer.log('🔔 [Repo] Realtime (GOALS). Refrescando...', name: 'GoalRepository');
            _fetchAndPushData();
          },
        )
        .subscribe();
  }
  
  /// Carga todas las metas y las emite en el stream.
  Future<void> _fetchAndPushData() async {
    developer.log('🔄 [Repo] Obteniendo todas las metas...', name: 'GoalRepository');
    try {
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw Exception("Usuario no autenticado");
      
      final data = await client
          .from('goals')
          .select()
          .eq('user_id', userId)
          .order('target_date', ascending: true);
          
      final goals = (data as List).map((map) => Goal.fromMap(map)).toList();
      
      if (!_streamController.isClosed) {
        _streamController.add(goals);
        developer.log('✅ [Repo] ${goals.length} metas enviadas al stream.', name: 'GoalRepository');
      }
    } catch (e) {
      developer.log('🔥 [Repo] Error obteniendo metas: $e', name: 'GoalRepository');
      if (!_streamController.isClosed) {
        _streamController.addError(e);
      }
    }
  }
}