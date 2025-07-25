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

  // ---- NUEVO MÉTODO PARA ACTUALIZAR ----
  Future<void> updateGoal(Goal goal) async {
    developer.log('🔄 [Repo] Updating goal ${goal.id}', name: 'GoalRepository');
    try {
      await _client
          .from('goals')
          // Creamos un mapa solo con los campos que se pueden editar
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

  // ---- MÉTODO DE BORRADO REEMPLAZADO POR LA VERSIÓN SEGURA ----
  Future<void> deleteGoalSafely(String goalId) async {
    developer.log('🗑️ [Repo] Safely deleting goal with id $goalId', name: 'GoalRepository');
    try {
      final result = await _client.rpc(
        'delete_goal_safely',
        params: {'goal_id_to_delete': goalId}, // Pasamos el UUID como String
      ) as String;

      if (result.startsWith('Error:')) {
        throw Exception(result.replaceFirst('Error: ', ''));
      }
      
      developer.log('✅ [Repo] Goal safely deleted successfully.', name: 'GoalRepository');
    } catch (e) {
      developer.log('🔥 [Repo] Error in RPC delete_goal_safely: $e', name: 'GoalRepository');
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // Mantenemos el deleteGoal original por si lo usas en otro sitio, 
  // pero lo marcamos como obsoleto para fomentar el uso de la versión segura.
  @Deprecated('Use deleteGoalSafely instead for business logic validation')
  Future<void> deleteGoal(String goalId) async {
    // ... tu código de deleteGoal original ...
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
      // Somos explícitos sobre los valores iniciales.
      await _client.from('goals').insert({
        'user_id': userId,
        'name': name,
        'target_amount': targetAmount,
        'current_amount': 0, // Aseguramos que el monto actual siempre empiece en 0.
        'status': 'active',  // Aseguramos que el estado inicial siempre sea 'active'.
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

}