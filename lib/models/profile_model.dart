// lib/models/profile_model.dart

import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  final String id;
  final String? fullName; // Puede ser nulo si aún no lo ha configurado
  final int xpPoints;
  final String? avatarUrl;

  const Profile({
    required this.id,
    this.fullName,
    required this.xpPoints,
    this.avatarUrl, 
  });

  // Un getter computado para calcular el nivel actual del usuario
  int get level => 1 + (xpPoints / 500).floor();

  // Calcula los XP acumulados en el nivel actual
  int get xpInCurrentLevel => xpPoints % 500;

  // Calcula los XP necesarios para alcanzar el siguiente nivel
  int get xpForNextLevel => 500;

  // Calcula el progreso en el nivel actual como un valor entre 0.0 y 1.0
  double get levelProgress => xpInCurrentLevel / xpForNextLevel;


  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'],
      fullName: map['full_name'],
      xpPoints: map['xp_points'] ?? 0,
      avatarUrl: map['avatar_url'],
    );
  }
  
  // Un estado vacío para usar durante la carga
  factory Profile.empty() {
    return const Profile(id: '', fullName: 'Cargando...', xpPoints: 0);
  }

  @override
  List<Object?> get props => [id, fullName, xpPoints, avatarUrl];
}