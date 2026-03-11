// lib/home_widget_callback_handler.dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/services/affirmation_widget_service.dart';
import 'package:sasper/services/manifestation_widget_service.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:sasper/services/widgets/core/widget_config.dart';
import 'package:sasper/services/widgets/core/widget_types.dart';

@pragma('vm:entry-point')
void homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null) {
    developer.log('⚠️ Callback recibido con URI nulo', name: 'WidgetCallback');
    return;
  }

  developer.log(
    '📩 CALLBACK RECIBIDO → URI: $uri | HOST: ${uri.host} | PATH: ${uri.path}',
    name: 'WidgetCallback',
  );

  // ====================================================================
  // INICIALIZACIÓN DE SUPABASE (Crítico para segundo plano)
  // ====================================================================
  try {
    final prefs = await SharedPreferences.getInstance();
    final supabaseUrl = prefs.getString('supabase_url') ?? AppConfig.supabaseUrl;
    final supabaseKey = prefs.getString('supabase_api_key') ?? AppConfig.supabaseAnonKey;

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    GlobalState.supabaseInitialized = true;
    developer.log('✅ Supabase inicializado en background', name: 'WidgetCallback');
  } catch (e) {
    // Si el error es porque ya está inicializado, lo ignoramos y continuamos
    if (e.toString().contains('already been initialized')) {
      developer.log('⚡ Supabase ya estaba inicializado', name: 'WidgetCallback');
      GlobalState.supabaseInitialized = true;
    } else {
      developer.log('🔥 ERROR al inicializar Supabase: $e', name: 'WidgetCallback');
      return;
    }
  }

  // ====================================================================
  // EXTRAER widgetId y action (puede venir en path o en query)
  // ====================================================================
  final widgetIdParam = uri.queryParameters['widgetId'];
  String action;
  if (uri.pathSegments.isNotEmpty) {
    action = uri.pathSegments.first;
  } else {
    // algunos intents (como el botón de recarga) envían la acción como query param
    action = uri.queryParameters['action'] ?? '';
  }

  developer.log(
    '🎯 Procesando → Action: "$action" | WidgetId: ${widgetIdParam ?? "null"}',
    name: 'WidgetCallback',
  );

  // ====================================================================
  // ROUTER DE ACCIONES POR HOST
  // ====================================================================
  try {
    switch (uri.host) {
      case 'affirmation_widget':
        await AffirmationWidgetService.handleWidgetAction(action, widgetIdParam);
        break;

      // ESTE ES EL CASE QUE FALTABA O ESTABA MAL CONFIGURADO
      case 'simple_manifestation_widget':
        await ManifestationWidgetService.handleWidgetAction(action, widgetIdParam);
        break;

      // Este es para el WIDGET VISION
      case 'manifestation_widget':
        await ManifestationWidgetService.handleWidgetAction(action, widgetIdParam);
        break;

      case 'widget': // Dashboard y otros widgets financieros
        if (action == 'refresh_next_payment' || action == 'refresh') {
          // La recarga manual del boton debe actualizar ambos widgets, no sólo el próximo pago
          await widget_service.WidgetService.updateNextPaymentWidget();
          await widget_service.WidgetService.updateUpcomingPaymentsWidget();
          developer.log('✅ Widgets financieros recargados (next + upcoming)', name: 'WidgetCallback');
        } else {
          await widget_service.handleWidgetAction(action);
        }
        break;
        
      default:
        developer.log(
          '❓ Host desconocido: ${uri.host}',
          name: 'WidgetCallback',
        );
    }
    
    developer.log('✅ Acción procesada exitosamente', name: 'WidgetCallback');
  } catch (e, stackTrace) {
    developer.log(
      '🔥 ERROR al procesar acción: $e',
      name: 'WidgetCallback',
      error: e,
      stackTrace: stackTrace,
    );
  }
}

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

    // 2. Inicializar Supabase de forma segura
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    } catch (e) {
      if (e.toString().contains('already been initialized')) {
        developer.log('⚡ Supabase ya estaba inicializado en optimized bg', name: 'BackgroundWidget');
      } else {
        developer.log('🔥 Error init Supabase: $e', name: 'BackgroundWidget');
        return;
      }
    }

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