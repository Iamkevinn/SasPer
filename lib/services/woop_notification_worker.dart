// lib/services/woop_notification_worker.dart
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;
import 'package:sasper/models/manifestation_model.dart'; // Asegúrate de que esta ruta sea correcta
import 'package:sasper/services/notification_service.dart';

const String woopNotificationTask = 'woop_notification_worker';

class WOOPNotificationService {
  /// CANDADO GLOBAL: ¿Ya enviamos un WOOP hoy?
  static Future<bool> _hasSentAnyWOOPToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return prefs.getBool('global_woop_sent_$today') ?? false;
  }

  static Future<void> _markGlobalWOOPSentToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    await prefs.setBool('global_woop_sent_$today', true);
  }

  /// EVALUADOR INTELIGENTE (Se ejecuta cada hora en segundo plano)
  static Future<bool> executeTriggerEvaluation({
    required SupabaseClient client,
    required String userId,
    bool isTest = false,
  }) async {
    try {
      developer.log('🧠 Iniciando evaluación WOOP...', name: 'WOOPWorker');

      // 1. Candado Anti-Spam (Si no es test, y ya enviamos hoy, abortar)
      if (!isTest && await _hasSentAnyWOOPToday()) {
        developer.log('⏳ Ya se envió un WOOP hoy. Abortando.', name: 'WOOPWorker');
        return true;
      }

      // 2. Ruleta de Tiempo (Solo si no es test)
      final now = DateTime.now();
      if (!isTest) {
        // Solo molestamos al usuario entre las 10:00 AM y las 8:00 PM
        if (now.hour < 10 || now.hour > 20) return true;

        // Si son las 8 PM (20:00) y no ha salido, la forzamos.
        // Si no, lanzamos un dado: 15% de probabilidad de que salga en esta hora.
        final shouldForce = now.hour >= 20;
        final diceRoll = math.Random().nextInt(100) < 15;

        if (!shouldForce && !diceRoll) {
          developer.log('🎲 La ruleta decidió no notificar en esta hora.', name: 'WOOPWorker');
          return true; // No toca ahora, intentará la próxima hora
        }
      }

      // 3. Consultar la FUENTE DE LA VERDAD (Supabase)
      // Buscamos manifestaciones del usuario que SÍ tengan un plan WOOP completo
      final response = await client
          .from('manifestations')
          .select()
          .eq('user_id', userId)
          .not('plan', 'is', null)
          .not('obstacle', 'is', null)
          .not('plan', 'eq', '')
          .not('obstacle', 'eq', '');

      final manifestations = (response as List)
          .map((m) => Manifestation.fromMap(m))
          .toList();

      if (manifestations.isEmpty) {
        if (isTest) {
          await _showTestEmptyNotification();
        }
        return true;
      }

      // 4. Elegir UNA manifestación al azar
      manifestations.shuffle();
      final selectedManifestation = manifestations.first;

      // 5. Mostrar la notificación inteligente
      await _showIntelligentNotification(selectedManifestation, isTest: isTest);
      
      // 6. Marcar el día como completado
      if (!isTest) await _markGlobalWOOPSentToday();

      return true;
    } catch (e) {
      developer.log('🔥 WOOP Worker error: $e', name: 'WOOPWorker');
      return false;
    }
  }

  /// CREADOR DE MENSAJES PSICOLÓGICOS DINÁMICOS
  static String _generateIntelligentMessage(Manifestation m) {
    // Usamos los datos REALES de tu base de datos para armar la frase
    final title = m.title;
    final outcome = m.outcome ?? 'lograr tu meta';
    final obstacle = m.obstacle!;
    final plan = m.plan!;

    final templates = [
      'Tu sueño es "$title". Si surge tu obstáculo ("$obstacle"), recuerda tu plan: "$plan".',
      'Visualiza esa sensación de "$outcome". Para llegar ahí, si enfrentas "$obstacle", entonces: "$plan".',
      'Regla de oro para hoy: Si "$obstacle", entonces "$plan". ¡Avanza hacia "$title"!',
      'No dejes que "$obstacle" te detenga. Aplica tu plan: "$plan" y acércate a "$title".'
    ];

    templates.shuffle();
    return templates.first;
  }

static Future<void> _showIntelligentNotification(Manifestation m, {bool isTest = false}) async {
    
    final localNotifier = FlutterLocalNotificationsPlugin();
    await localNotifier.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));

    final androidPlugin = localNotifier.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'woop_channel', 'Coaching WOOP',
        description: 'Recordatorios inteligentes',
        importance: Importance.max,
      ));
    }

    await localNotifier.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
    
    final title = isTest ? '🧪 Test: ${m.title}' : '✨ Foco en: ${m.title}';
    final body = _generateIntelligentMessage(m);

    // Creamos un payload (datos ocultos) para saber qué manifestación es
    final payloadJson = jsonEncode({
      'type': 'woop_victory',
      'manifestationId': m.id,
      'title': m.title,
    });

    await localNotifier.show(
      m.id.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'woop_channel', 'Coaching WOOP',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
          // 🔥 NUEVO: EL BOTÓN DE VICTORIA
          actions: const [
            AndroidNotificationAction(
              'LOG_VICTORY', 
              '💪 ¡Lo logré!',
              showsUserInterface: true, // Esto obliga a abrir la app
            )
          ]
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: payloadJson, // Le pasamos los datos ocultos
    );
  }
  
  static Future<void> _showTestEmptyNotification() async {
    final localNotifier = FlutterLocalNotificationsPlugin();
    await localNotifier.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await localNotifier.show(
      999, '🧪 Prueba WOOP', 'Tus notificaciones funcionan, pero no tienes ninguna manifestación con Plan WOOP guardada en la base de datos.',
      const NotificationDetails(
        android: AndroidNotificationDetails('woop_channel', 'Coaching WOOP'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}