// lib/models/enums/transaction_mood_enum.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

enum TransactionMood {
  necesario,
  planificado,
  impulsivo,
  social,
  emocional,
  happy,
  neutral,
  sad,
  stressed, 
  angry,
}

extension TransactionMoodExtension on TransactionMood {
  String get displayName {
    switch (this) {
      case TransactionMood.necesario:
        return 'Necesario';
      case TransactionMood.planificado:
        return 'Planificado';
      case TransactionMood.impulsivo:
        return 'Impulsivo';
      case TransactionMood.social:
        return 'Social';
      case TransactionMood.emocional:
        return 'Emocional';
      case TransactionMood.happy:
        return 'Feliz';
      case TransactionMood.neutral:
        return 'Neutral';
      case TransactionMood.sad:
        return 'Triste';
      case TransactionMood.stressed:
        return 'Estresado';
      case TransactionMood.angry:
        return 'Enojado';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionMood.necesario:
        return Iconsax.shield_tick;
      case TransactionMood.planificado:
        return Iconsax.calendar_tick;
      case TransactionMood.impulsivo:
        return Iconsax.flash_1;
      case TransactionMood.social:
        return Iconsax.people;
      case TransactionMood.emocional:
        return Iconsax.heart;
      case TransactionMood.happy:
        return Iconsax.emoji_happy;
      case TransactionMood.neutral:
        return Iconsax.emoji_normal;
      case TransactionMood.sad:
        return Iconsax.emoji_sad;
      case TransactionMood.stressed:
        return Iconsax.danger;
      case TransactionMood.angry:
        return Iconsax.info_circle;
    }
  }

  // Añadimos color para que las tarjetas de IA se vean mejor en la UI
  Color get color {
    switch (this) {
      case TransactionMood.happy:
      case TransactionMood.necesario:
      case TransactionMood.planificado:
        return Colors.green;
      case TransactionMood.social:
      case TransactionMood.neutral:
        return Colors.blue;
      case TransactionMood.impulsivo:
      case TransactionMood.emocional:
      case TransactionMood.stressed:
        return Colors.orange;
      case TransactionMood.sad:
      case TransactionMood.angry:
        return Colors.red;
    }
  }
}