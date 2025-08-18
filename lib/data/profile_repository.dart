// lib/data/profile_repository.dart

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/profile_model.dart';

class ProfileRepository {
  ProfileRepository._internal();
  static final ProfileRepository instance = ProfileRepository._internal();
  final _supabase = Supabase.instance.client;

  /// Obtiene los datos del perfil del usuario actual en un stream para actualizaciones en tiempo real.
  Stream<Profile> getUserProfileStream() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return Stream.value(Profile.empty());

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((listOfMaps) {
          if (listOfMaps.isEmpty) return Profile.empty();
          return Profile.fromMap(listOfMaps.first);
        });
  }
}