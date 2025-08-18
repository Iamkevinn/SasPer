// lib/data/challenge_repository.dart
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/challenge_model.dart';

class ChallengeRepository {
  ChallengeRepository._internal();
  static final ChallengeRepository instance = ChallengeRepository._internal();
  final _supabase = Supabase.instance.client;

  // Obtiene los retos que el usuario aún no ha iniciado
  /// Obtiene la lista de retos disponibles, excluyendo aquellos que el usuario ya tiene activos.
  Future<List<Challenge>> getAvailableChallenges() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return []; // Si no hay usuario, no hay retos.

    try {
      // Paso 1: Obtener los IDs de los retos que el usuario ya tiene ACTIVOS.
      final userChallengesResponse = await _supabase
          .from('user_challenges')
          .select('challenge_id') // Solo necesitamos la columna del ID del reto
          .eq('user_id', userId)
          .eq('status', 'active');

      // Creamos una lista de los IDs de los retos que queremos excluir.
      final activeChallengeIds = userChallengesResponse
          .map((challenge) => challenge['challenge_id'] as String)
          .toList();

      /// --- CORRECCIÓN CLAVE AQUÍ ---
    // Paso 2: Construir la consulta de forma encadenada y condicional.

    // Empezamos con la base de la consulta.
    var query = _supabase.from('challenges').select();

    // Si hay retos activos que excluir, añadimos el filtro A LA MISMA VARIABLE.
    // El método 'not' devuelve una nueva instancia del query builder, por lo que
    // debemos reasignarla a nuestra variable 'query'.
    if (activeChallengeIds.isNotEmpty) {
      query = query.not('id', 'in', activeChallengeIds);
    }


      // Paso 3: Ejecutar la consulta final, que ahora sí contiene el filtro si era necesario.
    final availableChallengesResponse = await query;
    
    // Mapeamos el resultado a nuestros modelos de Dart.
    return availableChallengesResponse
        .map((data) => Challenge.fromMap(data))
        .toList();

    } catch (e) {
      print('Error al obtener retos disponibles: $e');
      // Devolvemos una lista vacía en caso de error para no romper la UI.
      return [];
    }
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