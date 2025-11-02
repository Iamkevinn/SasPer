// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NOVEDAD: Importar
// NOVEDAD: Importar
// NOVEDAD: Importar

// --- Tus importaciones existentes ---
import 'package:sasper/config/app_config.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/models/recurring_transaction_model.dart';

// --- HANDLERS DE RESPUESTA PARA NOTIFICACIONES LOCALES (Deben ser funciones de nivel superior) ---
void onDidReceiveNotificationResponse(NotificationResponse resp) {
  developer.log(
    '🔔 onDidReceiveNotificationResponse (payload: ${resp.payload})',
    name: 'NotificationService-Callback',
  );
}

void onDidReceiveBackgroundNotificationResponse(NotificationResponse resp) {
  developer.log(
    '🔔 onDidReceiveBackgroundNotificationResponse (payload: ${resp.payload})',
    name: 'NotificationService-Callback',
  );
}

// [CAMBIO CLAVE] La función ahora es PÚBLICA (sin guion bajo)
// para que pueda ser accedida desde SplashScreen.dart.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('🔔 [BACKGROUND] Notificación de Firebase recibida en segundo plano: ${message.messageId}', name: 'NotificationService-FCM');

  // 1. Inicializamos Firebase. Es requerido en el Isolate de FCM.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 2. Leemos las claves de Supabase desde SharedPreferences.
  final prefs = await SharedPreferences.getInstance();
  final supabaseUrl = prefs.getString('supabase_url');
  final supabaseApiKey = prefs.getString('supabase_api_key');

  if (supabaseUrl == null || supabaseApiKey == null) {
    developer.log('🔥 [BACKGROUND-FCM] ERROR: No se encontraron las claves de Supabase. Abortando.', name: 'NotificationService-FCM');
    return; // No podemos continuar sin las claves.
  }

  try {
    // 3. Inicializamos una instancia de Supabase DENTRO de este Isolate.
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseApiKey);
    developer.log('✅ [BACKGROUND-FCM] Supabase inicializado para el manejador de notificaciones.', name: 'NotificationService-FCM');

    // 4. Ahora que Supabase está listo, puedes ejecutar tu lógica de negocio.
    // Por ejemplo, aquí podrías llamar a un método para guardar la notificación
    // o para actualizar el token del usuario si es necesario.
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
       // Ejemplo: Actualizar el token si la notificación lo trae
       final fcmToken = await FirebaseMessaging.instance.getToken();
       if (fcmToken != null) {
          await Supabase.instance.client.from('profiles').update({'fcm_token': fcmToken}).eq('id', uid);
          developer.log('✅ [BACKGROUND-FCM] Token FCM actualizado para el usuario.', name: 'NotificationService-FCM');
       }
    }
  } catch (e) {
    developer.log('🔥 [BACKGROUND-FCM] ERROR FATAL en el manejador de notificaciones: $e', name: 'NotificationService-FCM');
  }
}

class NotificationService {  
  // --- DEPENDENCIAS Y SINGLETON ---
  late final SupabaseClient _supabase;
  late final FirebaseMessaging _firebaseMessaging;
  late final http.Client _httpClient;
  
  final FlutterLocalNotificationsPlugin _localNotifier = FlutterLocalNotificationsPlugin();

  NotificationService._privateConstructor();
  static final NotificationService instance = NotificationService._privateConstructor();
  
  void initializeDependencies({
    required SupabaseClient supabaseClient,
    required FirebaseMessaging firebaseMessaging,
    http.Client? httpClient,
  }) {
    _supabase = supabaseClient;
    _firebaseMessaging = firebaseMessaging;
    _httpClient = httpClient ?? http.Client();
    developer.
    log('✅ [NotificationService] Dependencies Injected.', name: 'NotificationService');
  }

  Future<void> initializeQuick() async {
    developer.log('🚀 [NotificationService] Starting QUICK initialize()', name: 'NotificationService');
    
    tz.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));
    developer.log('   Timezone set: $tzName', name: 'NotificationService');
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifier.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
    developer.log('   FlutterLocalNotificationsPlugin initialized', name: 'NotificationService');

    await _createAndroidChannels();
    _setupMessageListeners();
  }

  Future<void> initializeLate() async {
    developer.log('⏳ [NotificationService] Starting LATE initialize() (permissions & token)', name: 'NotificationService');
    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      developer.log('① Permisos FCM: auth=${settings.authorizationStatus}', name: 'NotificationService');

      await _localNotifier
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true, badge: true);
          
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _updateAndSaveToken();
      } else {
        developer.log('⚠️ Permiso FCM no concedido. No se buscará token.', name: 'NotificationService');
      }

    } catch (e, st) {
      developer.log('🔥 Error in initializeLate: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  Future<void> _updateAndSaveToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        developer.log('🔑 FCM token: $token', name: 'NotificationService');
        await _saveTokenToSupabase(token);
      } else {
        developer.log('⚠️ No se obtuvo FCM token.', name: 'NotificationService');
      }
    } catch(e, st) {
      developer.log('🔥 Error en _updateAndSaveToken: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((msg) {
      developer.log('📲 onMessage: ${msg.messageId}', name: 'NotificationService');
      if (msg.notification != null) {
        developer.log('   title=${msg.notification!.title}, body=${msg.notification!.body}', name: 'NotificationService');
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      developer.log('📂 onMessageOpenedApp: ${msg.messageId}', name: 'NotificationService');
    });
    _firebaseMessaging.onTokenRefresh.listen((token) => _saveTokenToSupabase(token));
  }
  
  Future<void> _createAndroidChannels() async {
    final androidImpl = _localNotifier.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl == null) return;
    
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'recurring_payments_channel',
        'Recordatorios de Pagos',
        description: 'Notificaciones sobre pagos recurrentes próximos.',
        importance: Importance.max,
      ),
    );
    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'test_channel',
        'Notificaciones de Prueba',
        description: 'Canal usado para pruebas de desarrollo.',
        importance: Importance.max,
      ),
    );
    developer.log('   Notification channels created', name: 'NotificationService');
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) {
      developer.log('❌ No hay usuario logueado, no guardo token.', name: 'NotificationService');
      return;
    }
    try {
      await _supabase.from('profiles').update({'fcm_token': token}).eq('id', uid);
      developer.log('✅ Token guardado en Supabase', name: 'NotificationService');
    } catch (e, st) {
      developer.log('🔥 Error guardando token Supabase: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    final ctx = navigatorKey.currentState?.context;
    if (ctx != null && ctx.mounted) {
      ScaffoldMessenger.of(ctx)
        ..removeCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
    }
  }
  
  // Métodos públicos (sin cambios)
  Future<void> testImmediateNotification() async {
    _showSnackbar('🔔 Test: iniciando prueba de notificación...');
    try {
      var notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) {
        notifStatus = await Permission.notification.request();
      }
      if (!notifStatus.isGranted) {
        _showSnackbar('❌ NOTIFICATION no concedido.', isError: true);
        return;
      }

      var alarmStatus = await Permission.scheduleExactAlarm.status;
      if (!alarmStatus.isGranted) {
        alarmStatus = await Permission.scheduleExactAlarm.request();
      }
      if (!alarmStatus.isGranted) {
        _showSnackbar('❌ ALARM no concedido.', isError: true);
        return;
      }
      
      final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      _showSnackbar('✅ Programando para ${when.toLocal()}...');
      await _localNotifier.zonedSchedule(
        999,
        '🎉 Prueba Exitosa',
        'Si ves esto, tu sistema de notificaciones funciona.',
        when,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Notificaciones de Prueba',
            channelDescription: 'Canal para pruebas de desarrollo.',
            importance: Importance.max,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(presentSound: true),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      _showSnackbar('⏳ Notificación agendada. Revisa en 10s.');
    } catch (e, st) {
      _showSnackbar('🔥 Error en testImmediate: $e', isError: true);
      developer.log('🔥 Exception in testImmediateNotification: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  Future<void> scheduleRecurringReminders(RecurringTransaction tx) async {
    if (!await Permission.scheduleExactAlarm.isGranted) {
      developer.log(
        '⚠️ scheduleRecurringReminders: permiso ALARM no concedido para ${tx.description}',
        name: 'NotificationService',
      );
      return;
    }
    final baseId = tx.id.hashCode & 0x7FFFFFFF;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < 12; i++) {
      final due = tz.TZDateTime(tz.local, tx.nextDueDate.year, tx.nextDueDate.month + i, tx.nextDueDate.day);
      final remindAt = due.subtract(const Duration(days: 3));
      if (remindAt.isAfter(now)) {
        final nid = baseId + i;
        await _localNotifier.zonedSchedule(
          nid,
          'Recordatorio: ${tx.description}',
          'Tu pago vence en 3 días.',
          remindAt,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'recurring_payments_channel',
              'Recordatorios de Pagos',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        developer.log('⏰ Scheduled notification #$nid at $remindAt', name: 'NotificationService');
      }
    }
  }

  Future<void> cancelRecurringReminders(String txId) async {
    final baseId = txId.hashCode & 0x7FFFFFFF;
    for (var i = 0; i < 12; i++) {
      await _localNotifier.cancel(baseId + i);
    }
    developer.log('🗑️ Cancelled recurring reminders for ID $txId', name: 'NotificationService');
  }

  Future<void> refreshAllSchedules() async {
    developer.log('🔄 [NotificationService] Starting HEAVY task: refreshAllSchedules()', name: 'NotificationService');
    try {
      if (!await Permission.scheduleExactAlarm.isGranted) {
        developer.log('⚠️ No hay permiso para programar alarmas. Abortando refresh.', name: 'NotificationService');
        return;
      }
      final recurringTxs = await RecurringRepository.instance.getAll();
      await _localNotifier.cancelAll();
      developer.log('🗑️ Cancelled all notifications to refresh', name: 'NotificationService');
      for (final tx in recurringTxs) {
        await _scheduleRemindersForTransaction(tx);
      }
      developer.log('✅ Refreshed and rescheduled ${recurringTxs.length} reminders', name: 'NotificationService');
    } catch (e, st) {
      developer.log('🔥 Error during refreshAllSchedules: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  Future<void> _scheduleRemindersForTransaction(RecurringTransaction tx) async {
    final baseId = tx.id.hashCode & 0x7FFFFFFF;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < 12; i++) {
      final dueDate = tz.TZDateTime(tz.local, tx.nextDueDate.year, tx.nextDueDate.month + i, tx.nextDueDate.day);
      final remindAt = dueDate.subtract(const Duration(days: 3));
      if (remindAt.isAfter(now)) {
        final notificationId = baseId + i;
        await _localNotifier.zonedSchedule(
          notificationId,
          'Recordatorio: ${tx.description}',
          'Tu pago/cobro vence en 3 días.',
          remindAt,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'recurring_payments_channel',
              'Recordatorios de Pagos',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        developer.log('⏰ Scheduled notification #$notificationId at $remindAt', name: 'NotificationService');
      }
    }
  }

  Future<void> triggerBudgetNotification({
    required String userId,
    required String categoryName,
  }) async {
    developer.log('📲 triggerBudgetNotification for $categoryName (user $userId)', name: 'NotificationService');
    final url = Uri.parse('${AppConfig.renderBackendBaseUrl}/check-budget-on-transaction');
    try {
      final res = await _httpClient.post(url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': userId, 'category': categoryName}));
      if (res.statusCode == 200) {
        developer.log('✅ Budget trigger successful', name: 'NotificationService');
      } else {
        developer.log('🔥 Budget trigger error ${res.statusCode}: ${res.body}', name: 'NotificationService');
      }
    } catch (e, st) {
      developer.log('🔥 Error triggering budget notification: $e', name: 'NotificationService', stackTrace: st);
    }
  }
}
//Future<void> _initializeTimezonesInIsolate() async {
//  // Estas dos líneas se ejecutarán en un hilo separado.
//  tz.initializeTimeZones();
//  final String localTimezone = await FlutterTimezone.getLocalTimezone();
//  tz.setLocalLocation(tz.getLocation(localTimezone));
//}