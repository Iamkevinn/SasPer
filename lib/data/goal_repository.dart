// lib/data/goal_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'dart:async';

import 'package:sasper/models/goal_model.dart'; // Asegúrate de importar tu modelo Goal

class GoalRepository {
  final SupabaseClient _client;
  final _goalsStreamController = StreamController<List<Goal>>.broadcast();
  RealtimeChannel? _goalsChannel;
  // Constructor con inyección de dependencias para facilitar los tests
  GoalRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  
  /// Limpia los recursos (streams y canales) cuando ya no se necesiten.
  void dispose() {
    developer.log('❌ [Repo] Disposing GoalRepository resources.', name: 'GoalRepository');
    if (_goalsChannel != null) {
      _client.removeChannel(_goalsChannel!);
      _goalsChannel = null;
    }
    _goalsStreamController.close();
  }
  /// Devuelve un Stream en tiempo real de la lista de metas del usuario.
  Stream<List<Goal>> getGoalsStream() {
    developer.log('📡 [Repo] Subscribing to goals stream...', name: 'GoalRepository');
    try {
      return _client
          .from('goals')
          .stream(primaryKey: ['id'])
          .order('target_date', ascending: true) // Ordena por fecha objetivo
          .map((listOfMaps) {
            final goals = listOfMaps.map((data) => Goal.fromMap(data)).toList();
            developer.log('✅ [Repo] Goals stream updated with ${goals.length} items.', name: 'GoalRepository');
            return goals;
          })
          .handleError((error, stackTrace) {
            developer.log('🔥 [Repo] Error in goals stream: $error', name: 'GoalRepository', error: error, stackTrace: stackTrace);
          });
    } catch (e) {
      developer.log('🔥 [Repo] Could not subscribe to goals stream: $e', name: 'GoalRepository');
      return Stream.value([]);
    }
  }

  /// Añade una nueva meta a la base de datos.
  /// Lanza una excepción si la operación falla.
  Future<void> addGoal({
    required String name,
    required double targetAmount,
    DateTime? targetDate,
    String? iconName, // Parámetro opcional para un icono
  }) async {
    developer.log('💾 [Repo] Adding new goal: "$name"', name: 'GoalRepository');
    try {
      final userId = _client.auth.currentUser!.id;
      await _client.from('goals').insert({
        'user_id': userId,
        'name': name,
        'target_amount': targetAmount,
        'target_date': targetDate?.toIso8601String(),
        'icon_name': iconName,
      });
      developer.log('✅ [Repo] Goal "$name" added successfully.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error adding goal: $e', name: 'GoalRepository');
      throw Exception('No se pudo crear la meta. Por favor, inténtalo de nuevo.');
    }
  }

  /// Registra una contribución a una meta usando la función RPC.
  /// Lanza una excepción si la operación falla.
  Future<void> addContribution({
    required String goalId,
    required String accountId,
    required double amount,
  }) async {
    developer.log('💸 [Repo] Adding contribution of $amount to goal $goalId', name: 'GoalRepository');
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
  
  /// Elimina una meta de la base de datos.
  Future<void> deleteGoal(String goalId) async {
    developer.log('🗑️ [Repo] Deleting goal with id $goalId', name: 'GoalRepository');
    try {
      await _client.from('goals').delete().eq('id', goalId);
      developer.log('✅ [Repo] Goal deleted successfully.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error deleting goal: $e', name: 'GoalRepository');
      throw Exception('No se pudo eliminar la meta.');
    }
  }
}