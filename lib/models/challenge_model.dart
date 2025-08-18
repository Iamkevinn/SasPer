// lib/models/challenge_model.dart
import 'package:equatable/equatable.dart';

// ------------------- MODELO CHALLENGE (LA DEFINICIÓN DEL RETO) -------------------
class Challenge extends Equatable {
  final String id;
  final String title;
  final String description;
  final int durationDays;
  final String targetCategory;
  final String type;
  final int rewardXp;
  final String? lottieAnimationUrl;
  final bool resetsDaily; // <--- Es importante tener este campo que viene de la DB

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.targetCategory,
    required this.type,
    required this.rewardXp,
    this.lottieAnimationUrl,
    required this.resetsDaily, // <--- Añadido al constructor
  });

  factory Challenge.fromMap(Map<String, dynamic> map) {
    return Challenge(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      durationDays: map['duration_days'],
      targetCategory: map['target_category'],
      type: map['type'],
      rewardXp: map['reward_xp'],
      lottieAnimationUrl: map['lottie_animation_url'],
      resetsDaily: map['resets_daily'] ?? false, // <--- Añadido el mapeo
    );
  }
  
  // Lista de props correcta para Equatable
  @override
  List<Object?> get props => [id, title, description, resetsDaily];
}



// ------------------- MODELO USER_CHALLENGE (EL PROGRESO DEL USUARIO) -------------------
class UserChallenge extends Equatable {
  final String id;
  final String challengeId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final int currentStreak; // <-- Lugar correcto para la racha
  final Challenge challengeDetails; 

  const UserChallenge({
    required this.id,
    required this.challengeId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.currentStreak, // <-- Añadido al constructor
    required this.challengeDetails,
  });

  factory UserChallenge.fromMap(Map<String, dynamic> map) {
    return UserChallenge(
      id: map['id'],
      challengeId: map['challenge_id'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      status: map['status'],
      currentStreak: map['current_streak'] ?? 0, // <-- Añadido el mapeo
      challengeDetails: Challenge.fromMap(map['challenges']), 
    );
  }
  
  // Lista de props correcta para Equatable
  @override
  List<Object?> get props => [id, status, currentStreak];
}