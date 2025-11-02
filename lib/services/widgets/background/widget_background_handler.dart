import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sasper/services/widgets/core/widget_config.dart';
import 'package:sasper/services/widgets/core/widget_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@pragma('vm:entry-point')
Future<void> optimizedBackgroundCallback(Uri? uri) async {
  if (kDebugMode) {
    developer.log('🚀 Background callback iniciado', name: 'BackgroundWidget');
  }

  try {
    // 1. Cargar configuración de Supabase
    final prefs = await SharedPreferences.getInstance();
    final supabaseUrl = prefs.getString(WidgetConfig.supabaseUrlKey);
    final supabaseKey = prefs.getString(WidgetConfig.supabaseApiKeyKey);

    if (supabaseUrl == null || supabaseKey == null) {
      developer.log(
        '🔥 Configuración de Supabase no encontrada',
        name: 'BackgroundWidget',
      );
      return;
    }

    // 2. Inicializar Supabase
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

    // 3. Verificar autenticación
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      developer.log('⚠️ Usuario no autenticado', name: 'BackgroundWidget');
      return;
    }

    // 4. Ejecutar actualizaciones con manejo de errores individual
    final updates = [
      WidgetType.financialHealth,
      WidgetType.monthlyComparison,
      WidgetType.goals,
      WidgetType.upcomingPayments,
      WidgetType.nextPayment,
    ];

    for (final widgetType in updates) {
      try {
        await _updateWidgetBackground(widgetType);
      } catch (e) {
        developer.log(
          '⚠️ Error actualizando ${widgetType.name}: $e',
          name: 'BackgroundWidget',
        );
        // Continuar con el siguiente widget
      }
    }

    if (kDebugMode) {
      developer.log('✅ Background callback completado', name: 'BackgroundWidget');
    }
  } catch (e, st) {
    developer.log(
      '🔥 Error fatal en background callback: $e',
      name: 'BackgroundWidget',
      error: e,
      stackTrace: st,
    );
  }
}

Future<void> _updateWidgetBackground(WidgetType widgetType) async {
  // Placeholder - Se implementará en servicios especializados
  await HomeWidget.updateWidget(
    name: widgetType.providerName,
    androidName: widgetType.providerName,
  );
}
