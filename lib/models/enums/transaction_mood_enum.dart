// lib/models/enums/transaction_mood_enum.dart

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

// Enum para la seguridad de tipos en la app
enum TransactionMood {
  necesario,
  planificado,
  impulsivo,
  social,
  emocional,
}

// Extensión útil para obtener nombres legibles, iconos y colores para la UI
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
        return Iconsax.favorite_chart;
    }
  }
}