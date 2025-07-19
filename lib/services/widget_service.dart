// lib/services/widget_service.dart

import 'dart:developer' as developer;
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  // 1. Constantes centralizadas dentro de la clase para una mejor organización.
  static const String _appGroupId = 'group.com.example.sasper'; // Necesario para iOS
  static const String _androidProviderName = 'HomeWidgetExampleProvider';
  static const String _iOSProviderName = 'HomeWidgetExampleProvider'; // Reemplazar con el nombre de tu widget de iOS

  /// Inicializa el HomeWidget, necesario para iOS.
  static Future<void> initialize() async {
    // Es una buena práctica registrar el app group al inicio.
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Actualiza el widget de la pantalla de inicio con los datos proporcionados.
  /// Este método ya no busca los datos, los recibe como parámetros.
  static Future<void> updateWidgetData({
    required double totalBalance,
    // Podrías pasar más datos en el futuro
    // required String lastTransactionDesc,
  }) async {
    developer.log('🔄 [Service] Updating home widget data...', name: 'WidgetService');
    try {
      // 2. La lógica de formato se mantiene aquí, es parte de la preparación de datos para el widget.
      final formattedBalance = NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(totalBalance);
      
      // Guardamos cada dato con una clave única que el widget nativo pueda leer.
      await HomeWidget.saveWidgetData<String>('balance', formattedBalance);
      // await HomeWidget.saveWidgetData<String>('last_transaction', lastTransactionDesc);
      
      // 3. Solicitamos la actualización de la UI del widget nativo.
      await HomeWidget.updateWidget(
        name: _iOSProviderName,
        androidName: _androidProviderName,
      );
      
      developer.log('✅ [Service] Home widget updated successfully with balance: $formattedBalance', name: 'WidgetService');
    } catch (e, stackTrace) {
      // 4. Logging de errores mejorado.
      developer.log('🔥 [Service] Error updating home widget: $e', name: 'WidgetService', error: e, stackTrace: stackTrace);
    }
  }
}