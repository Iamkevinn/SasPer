// lib/models/challenge_model.dart
import 'package:equatable/equatable.dart';

// Modelo para la definición de un reto
class Challenge extends Equatable {
  final String id;
  final String title;
  final String description;
  final int durationDays;
  final String targetCategory;
  final String type;
  final int rewardXp;
  final String? lottieAnimationUrl;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.targetCategory,
    required this.type,
    required this.rewardXp,
    this.lottieAnimationUrl,
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
    );
  }
  
  @override
  List<Object?> get props => [id, title, description];
}


// Modelo para el progreso de un reto de un usuario
class UserChallenge extends Equatable {
  final String id;
  final String challengeId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  // Puedes añadir una propiedad `Challenge challengeDetails` y llenarla con un JOIN
  final Challenge challengeDetails; 

  const UserChallenge({
    required this.id,
    required this.challengeId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.challengeDetails,
  });

  factory UserChallenge.fromMap(Map<String, dynamic> map) {
    return UserChallenge(
      id: map['id'],
      challengeId: map['challenge_id'],
      startDate: DateTime.parse(map['start_date']),
      endDate: DateTime.parse(map['end_date']),
      status: map['status'],
      // Asume que el JOIN se hizo en la consulta
      challengeDetails: Challenge.fromMap(map['challenges']), 
    );
  }
  
  @override
  List<Object?> get props => [id, status];
}