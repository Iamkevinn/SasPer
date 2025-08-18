// lib/data/achievement_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/achievement_model.dart';

class AchievementRepository {
  AchievementRepository._internal();
  static final AchievementRepository instance = AchievementRepository._internal();
  final _supabase = Supabase.instance.client;

  /// Obtiene la lista de TODAS las definiciones de logros (bloqueados y desbloqueados)
  Future<List<Achievement>> getAllAchievements() async {
    final response = await _supabase.from('achievements').select();
    return response.map((data) => Achievement.fromMap(data)).toList();
  }

  /// Obtiene un stream con los IDs de los logros que el usuario YA ha desbloqueado
  Stream<Set<String>> getUnlockedAchievementIdsStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value({});

    return _supabase
        .from('user_achievements')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((listOfMaps) {
          // Devolvemos un Set para búsquedas de 'contains' súper rápidas (O(1))
          return listOfMaps.map((map) => map['achievement_id'] as String).toSet();
        });
  }
}