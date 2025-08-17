// lib/models/mood_by_day_analysis_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';

class MoodByDayAnalysis extends Equatable {
  final int dayOfWeek; // 1=Lunes, 7=Domingo
  final TransactionMood mood;
  final double totalSpent;

  const MoodByDayAnalysis({
    required this.dayOfWeek,
    required this.mood,
    required this.totalSpent,
  });

  factory MoodByDayAnalysis.fromMap(Map<String, dynamic> map) {
    TransactionMood parsedMood;
    try {
      parsedMood = TransactionMood.values.byName(map['mood']);
    } catch (e) {
      // Fallback seguro
      parsedMood = TransactionMood.necesario;
    }

    return MoodByDayAnalysis(
      dayOfWeek: map['day_of_week'] as int? ?? 1,
      mood: parsedMood,
      totalSpent: (map['total_spent'] as num? ?? 0.0).toDouble(),
    );
  }

  @override
  List<Object?> get props => [dayOfWeek, mood, totalSpent];
}