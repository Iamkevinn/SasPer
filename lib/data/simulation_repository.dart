// lib/data/simulation_repository.dart

import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/simulation_models.dart';

class SimulationRepository {
  // --- PATRÓN SINGLETON ---
  SimulationRepository._privateConstructor();
  static final SimulationRepository instance = SimulationRepository._privateConstructor();

  final _supabase = Supabase.instance.client;

  /// Llama a la RPC para simular el impacto de un gasto hipotético.
  ///
  /// Devuelve un objeto [SimulationResult] con todo el análisis.
  Future<SimulationResult> getExpenseSimulation({
    required double amount,
    required String categoryName,
  }) async {
    developer.log(
      '🧠 [Repo] Solicitando simulación para un gasto de $amount en "$categoryName"',
      name: 'SimulationRepository',
    );

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("Usuario no autenticado.");
      }
      
      // Llamamos a la RPC que creamos en Supabase.
      final response = await _supabase.rpc(
        'simulate_expense',
        params: {
          'p_user_id': userId,
          'p_amount': amount,
          'p_category': categoryName,
        },
      );
      
      // `response` ya es un Map<String, dynamic> porque la RPC devuelve un solo JSONB.
      developer.log('✅ [Repo] Simulación recibida: $response', name: 'SimulationRepository');

      // Usamos el factory `fromMap` de nuestro modelo para parsear la respuesta.
      return SimulationResult.fromMap(response);

    } on PostgrestException catch (e) {
      developer.log(
        '🔥 [Repo] Error de Postgrest en la simulación: ${e.message}',
        name: 'SimulationRepository',
        error: e,
      );
      // Creamos un error más amigable para la UI.
      throw Exception("No se pudo completar el análisis. ¿Tienes un presupuesto activo para esta categoría?");
    } catch (e) {
      developer.log(
        '🔥 [Repo] Error inesperado en la simulación: $e',
        name: 'SimulationRepository',
        error: e,
      );
      throw Exception("Ocurrió un error inesperado al realizar el análisis.");
    }
  }
}