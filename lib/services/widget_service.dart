// lib/services/widget_service.dart (RESTAURADO Y CORREGIDO)

import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  // --- NOMBRES CORREGIDOS Y CENTRALIZADOS ---
  static const String _appGroupId = 'group.com.example.sasper';
  static const String _providerName = 'com.example.sasper.SasPerWidgetProvider'; // Usamos el mismo nombre para ambos

  /// Inicializa el HomeWidget, necesario para iOS.
  static Future<void> initialize() async {
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Actualiza el widget de la pantalla de inicio con los datos proporcionados.
  static Future<void> updateWidgetData({
    double? totalBalance, // Lo hacemos opcional por si acaso
  }) async {
    developer.log('🔄 [Service] Updating home widget data...', name: 'WidgetService');
    try {
      final formattedBalance = NumberFormat.currency(
        locale: 'es_CO', // O 'es_CO' si lo prefieres
        symbol: '\$',
        decimalDigits: 0,
      ).format(totalBalance ?? 0.0);
      
      await HomeWidget.saveWidgetData<String>('total_balance', formattedBalance);
      
      // Solicitamos la actualización de la UI del widget nativo con el nombre correcto.
      await HomeWidget.updateWidget(
        name: 'SasPerWidgetProvider',
        androidName: 'SasPerWidgetProvider',
      );
      
      developer.log('✅ [Service] Home widget update call sent with balance: $formattedBalance', name: 'WidgetService');
    } catch (e, stackTrace) {
      developer.log('🔥 [Service] Error updating home widget: $e', name: 'WidgetService', error: e, stackTrace: stackTrace);
    }
  }
}