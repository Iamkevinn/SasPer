// lib/data/challenge_repository.dart
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/challenge_model.dart';

class ChallengeRepository {
  ChallengeRepository._internal();
  static final ChallengeRepository instance = ChallengeRepository._internal();
  final _supabase = Supabase.instance.client;

  // Obtiene los retos que el usuario aún no ha iniciado
  Future<List<Challenge>> getAvailableChallenges() async {
    // --- CORRECCIÓN AQUÍ ---
    // Se eliminó el <List<Map<String, dynamic>>> de la llamada a select()
    final response = await _supabase
        .from('challenges')
        .select();
    
    // Aquí podrías añadir lógica para filtrar retos ya completados por el usuario
    return response.map((data) => Challenge.fromMap(data)).toList();
  }

  // Obtiene los retos activos y completados del usuario
  Stream<List<UserChallenge>> getUserChallengesStream() {
    // Usamos un JOIN implícito mediante una segunda consulta para obtener los detalles del reto maestro
    // Esto es más fácil de manejar en Dart que un RPC complejo con Joins.
    final stream = _supabase
        .from('user_challenges')
        .stream(primaryKey: ['id'])
        .eq('user_id', _supabase.auth.currentUser!.id)
        .order('created_at', ascending: false);

    // Mapeamos el stream de listas de mapas
    return stream.asyncMap((listOfUserChallengeMaps) async {
        // Para cada lista que llega del stream, esperamos a que todas las sub-consultas de detalles se completen
        return Future.wait(listOfUserChallengeMaps.map((userChallengeData) async {
          try {
            // Hacemos la sub-consulta para obtener los detalles del 'challenge' maestro
            final challengeDetailsData = await _supabase
                .from('challenges')
                .select()
                .eq('id', userChallengeData['challenge_id'])
                .single();
            
            // Inyectamos los detalles del reto en el mapa del reto del usuario
            userChallengeData['challenges'] = challengeDetailsData; 
            return UserChallenge.fromMap(userChallengeData);
          } catch (e) {
            // Si un reto se borra o hay un error, lo omitimos para no romper el stream
            print('Error al obtener detalles del reto ${userChallengeData['challenge_id']}: $e');
            // Devolvemos un UserChallenge nulo o manejamos el error
            // En este caso, lo mejor es filtrar los resultados nulos después
            return null;
          }
        }))
        // Filtramos cualquier resultado nulo que haya ocurrido por un error
        .then((list) => list.whereType<UserChallenge>().toList());
    });
  }

  // El usuario acepta un nuevo reto
  Future<void> startChallenge(Challenge challenge) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: challenge.durationDays));

    await _supabase.from('user_challenges').insert({
      'user_id': _supabase.auth.currentUser!.id,
      'challenge_id': challenge.id,
      'start_date': now.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'active',
    });
  }

  // Llama a la función de Supabase para actualizar el estado de los retos
  // Modifica la función para que devuelva los retos que acaban de cambiar
  Future<List<UserChallenge>> checkUserChallengesStatus() async {
    // Primero, obtenemos los retos activos ANTES de la actualización
    final activeChallengesBefore = await _supabase
      .from('user_challenges')
      .select('id')
      .eq('user_id', _supabase.auth.currentUser!.id)
      .eq('status', 'active');
    
    final activeIdsBefore = activeChallengesBefore.map((e) => e['id'] as String).toSet();

    // Ejecutamos la actualización
    await _supabase.rpc('update_user_challenges_status');

    // Ahora, obtenemos los retos completados DESPUÉS de la actualización
    final completedChallengesAfter = await _supabase
      .from('user_challenges')
      .select('*, challenges(*)') // Usamos JOIN para obtener todos los datos
      .eq('user_id', _supabase.auth.currentUser!.id)
      .eq('status', 'completed');

    // Filtramos para encontrar solo los que ANTES estaban activos y AHORA están completados
    final newlyCompleted = completedChallengesAfter
      .where((c) => activeIdsBefore.contains(c['id']))
      .map((data) => UserChallenge.fromMap(data))
      .toList();

    return newlyCompleted;
  }
}