// lib/home_widget_callback_handler.dart
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/services/affirmation_widget_service.dart';
import 'package:sasper/services/manifestation_widget_service.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;

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
    if (!GlobalState.supabaseInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final supabaseUrl = prefs.getString('supabase_url') ?? AppConfig.supabaseUrl;
      final supabaseKey = prefs.getString('supabase_api_key') ?? AppConfig.supabaseAnonKey;

      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
      GlobalState.supabaseInitialized = true;
      developer.log('✅ Supabase inicializado en background', name: 'WidgetCallback');
    }
  } catch (e) {
    developer.log('🔥 ERROR al inicializar Supabase: $e', name: 'WidgetCallback');
    return;
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