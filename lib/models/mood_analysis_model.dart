// lib/models/mood_analysis_model.dart

import 'package:equatable/equatable.dart';
import 'package:sasper/models/enums/transaction_mood_enum.dart';

class MoodAnalysis extends Equatable {
  final TransactionMood mood;
  final String category;
  final double totalSpent;
  final int transactionCount;

  const MoodAnalysis({
    required this.mood,
    required this.category,
    required this.totalSpent,
    required this.transactionCount,
  });

  factory MoodAnalysis.fromMap(Map<String, dynamic> map) {
    // Convertimos el texto de la DB de vuelta a nuestro enum
    TransactionMood parsedMood;
    try {
      parsedMood = TransactionMood.values.byName(map['mood']);
    } catch (e) {
      // Si por alguna razón el mood no es válido, lo asignamos a uno por defecto
      // para no romper la app. Esto no debería pasar gracias a nuestro enum en la DB.
      parsedMood = TransactionMood.necesario;
    }

    return MoodAnalysis(
      mood: parsedMood,
      category: map['category'] ?? 'Sin Categoría',
      totalSpent: (map['total_spent'] as num? ?? 0.0).toDouble(),
      transactionCount: map['transaction_count'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [mood, category, totalSpent, transactionCount];
}