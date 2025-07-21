// lib/config/app_constants.dart
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

class AppConstants {
  static final Map<String, IconData> expenseCategories = {
    'Comida': Iconsax.cup,
    'Transporte': Iconsax.bus,
    'Ocio': Iconsax.gameboy,
    'Salud': Iconsax.health,
    'Hogar': Iconsax.home,
    'Compras': Iconsax.shopping_bag,
    'Servicios': Iconsax.flash_1,
    'Otro': Iconsax.category,
  };

  static final Map<String, IconData> incomeCategories = {
    'Sueldo': Iconsax.money_recive,
    'Inversión': Iconsax.chart,
    'Freelance': Iconsax.briefcase,
    'Regalo': Iconsax.gift,
    'Otro': Iconsax.category_2,
  };
}