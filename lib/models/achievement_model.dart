// lib/models/achievement_model.dart
import 'package:equatable/equatable.dart';

// Modelo para la definición de un logro
class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String iconName;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
  });

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      iconName: map['icon_name'],
    );
  }
  
  @override
  List<Object?> get props => [id];
}

// Modelo para registrar un logro desbloqueado por el usuario
class UserAchievement {
  final String userId;
  final String achievementId;
  final DateTime unlockedAt;

  UserAchievement({
    required this.userId,
    required this.achievementId,
    required this.unlockedAt,
  });
}