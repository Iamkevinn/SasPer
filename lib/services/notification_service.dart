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
import 'package:permission_handler/permission_handler.dart'; // <-- AÑADE ESTA DEPENDENCIA

// --- Tus importaciones existentes ---
import 'package:sasper/config/app_config.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/models/recurring_transaction_model.dart';

// --- HANDLERS DE RESPUESTA PARA NOTIFICACIONES LOCALES ---
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

// FUNCION DE BACKGROUND PARA FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log(
    '📥 Handling background FCM message: ${message.messageId}',
    name: 'NotificationService-BackgroundFCM',
  );
}

class NotificationService {
  // Dependencias
  late final SupabaseClient _supabase;
  late final FirebaseMessaging _firebaseMessaging;
  late final http.Client _httpClient;
  
  final FlutterLocalNotificationsPlugin _localNotifier = FlutterLocalNotificationsPlugin();

  // El constructor privado ahora está vacío.
  NotificationService._privateConstructor();

  // La instancia estática se mantiene igual.
  static final NotificationService instance = NotificationService._privateConstructor();
  
  // Se llamará desde SplashScreen para inyectar las dependencias.
  void initializeDependencies({
    required SupabaseClient supabaseClient,
    required FirebaseMessaging firebaseMessaging,
    http.Client? httpClient,
  }) {
    _supabase = supabaseClient;
    _firebaseMessaging = firebaseMessaging;
    _httpClient = httpClient ?? http.Client();
    developer.log('✅ [NotificationService] Dependencies Injected.', name: 'NotificationService');
  }

  /// Inicializa FCM (push) y notific. locales (channels & scheduled).
//  Future<void> initialize() async {
//    developer.log('🚀 [NotificationService] Starting initialize()', name: 'NotificationService');
//
//    // ---- 1. PUSH REMOTAS (FCM) ----
//    try {
//      developer.log('① Configurando background FCM handler...', name: 'NotificationService');
//      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
//
//      developer.log('① Solicitando permisos FCM...', name: 'NotificationService');
//      final settings = await _firebaseMessaging.requestPermission();
//      developer.log(
//        '① Permisos FCM: auth=${settings.authorizationStatus}',
//        name: 'NotificationService',
//      );
//
//      await _updateAndSaveToken();
//      _firebaseMessaging.onTokenRefresh.listen((token) {
//        developer.log('🔄 FCM Token refreshed: $token', name: 'NotificationService');
//        _saveTokenToSupabase(token);
//      });
//
//      _setupMessageListeners();
//      developer.log('✅ FCM initialized.', name: 'NotificationService');
//    } catch (e, st) {
//      developer.log('🔥 Error initializing FCM: $e', name: 'NotificationService', stackTrace: st);
//    }
//
//    // ---- 2. LOCALES PROGRAMADAS ----
//    try {
//      developer.log('② Inicializando TZ & canales...', name: 'NotificationService');
//      await _initializeLocalNotifications();
//
//      // Estado de permisos Android 13+
//      final notifPerm = await Permission.notification.status;
//      developer.log('② Permiso NOTIFICATION: $notifPerm', name: 'NotificationService');
//      if (notifPerm.isDenied) {
//        developer.log('② Solicitando POST_NOTIFICATIONS...', name: 'NotificationService');
//        await Permission.notification.request();
//      }
//
//      final alarmPerm = await Permission.scheduleExactAlarm.status;
//      developer.log('② Permiso SCHEDULE_EXACT_ALARM: $alarmPerm', name: 'NotificationService');
//      if (alarmPerm.isDenied) {
//        developer.log('② Solicitando SCHEDULE_EXACT_ALARM...', name: 'NotificationService');
//        await Permission.scheduleExactAlarm.request();
//      }
//
//      developer.log('✅ Local notifications initialized.', name: 'NotificationService');
//    } catch (e, st) {
//      developer.log('🔥 Error initializing local notifications: $e', name: 'NotificationService', stackTrace: st);
//    }
//  }


  Future<void> initialize() async {
    developer.log('🚀 [NotificationService] Starting QUICK initialize()', name: 'NotificationService');
    
    // Configura FCM, pide permisos y actualiza el token.
    // Estas operaciones son relativamente rápidas.
    await _initializeFcm();
    
    // Configura los canales y permisos de notificaciones locales.
    // Esto también es rápido.
    await _initializeLocalNotifications();
  }

  /// Prueba inmediata: programa una notificación a 10s y muestra SnackBars.
  Future<void> testImmediateNotification() async {
    _showSnackbar('🔔 Test: iniciando prueba de notificación...');

    try {
      // Verifica permisos otra vez
      var notifStatus = await Permission.notification.status;
      developer.log('🔍 testImmediate notifStatus: $notifStatus', name: 'NotificationService');
      if (!notifStatus.isGranted) {
        _showSnackbar('Solicitando permiso NOTIFICATION...');
        notifStatus = await Permission.notification.request();
      }
      if (!notifStatus.isGranted) {
        _showSnackbar('❌ NOTIFICATION no concedido.', isError: true);
        return;
      }

      var alarmStatus = await Permission.scheduleExactAlarm.status;
      developer.log('🔍 testImmediate alarmStatus: $alarmStatus', name: 'NotificationService');
      if (!alarmStatus.isGranted) {
        _showSnackbar('Solicitando permiso ALARM...');
        alarmStatus = await Permission.scheduleExactAlarm.request();
      }
      if (!alarmStatus.isGranted) {
        _showSnackbar('❌ ALARM no concedido.', isError: true);
        return;
      }

      // Todo OK: programamos
      final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
      _showSnackbar('✅ Programando para ${when.toLocal()}...');
      await _localNotifier.zonedSchedule(
        999,
        '🎉 Prueba Exitosa',
        'Si ves esto, tu sistema de notificaciones funciona.',
        when,
        NotificationDetails(
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
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      _showSnackbar('⏳ Notificación agendada. Revisa en 10s.');
      developer.log('✅ testImmediateNotification zonedSchedule called', name: 'NotificationService');
    } catch (e, st) {
      _showSnackbar('🔥 Error en testImmediate: $e', isError: true);
      developer.log('🔥 Exception in testImmediateNotification: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  // ------------------------------------------------------------
  //  Helpers privados
  // ------------------------------------------------------------

  Future<void> _initializeFcm() async {
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
      final settings = await _firebaseMessaging.requestPermission();
      developer.log('① Permisos FCM: auth=${settings.authorizationStatus}', name: 'NotificationService');
      await _updateAndSaveToken();
      _firebaseMessaging.onTokenRefresh.listen((token) => _saveTokenToSupabase(token));
      _setupMessageListeners();
      developer.log('✅ FCM initialized.', name: 'NotificationService');
    } catch (e, st) {
      developer.log('🔥 Error initializing FCM: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  Future<void> _updateAndSaveToken() async {
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      developer.log('🔑 FCM token: $token', name: 'NotificationService');
      await _saveTokenToSupabase(token);
    } else {
      developer.log('⚠️ No se obtuvo FCM token.', name: 'NotificationService');
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
  }

  Future<void> _initializeLocalNotifications() async {
    // Timezones
    tz.initializeTimeZones();
    final tzName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzName));
    developer.log('   Timezone set: $tzName', name: 'NotificationService');

    // Init plugin
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifier.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );
    developer.log('   FlutterLocalNotificationsPlugin initialized', name: 'NotificationService');

    // Crear canales Android
    final androidImpl = _localNotifier
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'recurring_payments_channel',
        'Recordatorios de Pagos',
        description: 'Notificaciones sobre pagos recurrentes próximos.',
        importance: Importance.max,
      ),
    );
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        'test_channel',
        'Notificaciones de Prueba',
        description: 'Canal usado para pruebas de desarrollo.',
        importance: Importance.max,
      ),
    );
    developer.log('   Notification channels created', name: 'NotificationService');

    // iOS permissions
    await _localNotifier
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true, badge: true);
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

  // ------------------------------------------------------------
  //  Métodos públicos de notificaciones programadas
  // ------------------------------------------------------------

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
          NotificationDetails(
            android: AndroidNotificationDetails(
              'recurring_payments_channel',
              'Recordatorios de Pagos',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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

      // 1. Obtenemos las transacciones recurrentes.
      final recurringTxs = await RecurringRepository.instance.getAll();
      
      // 2. Limpiamos todas las notificaciones antiguas.
      await _localNotifier.cancelAll();
      developer.log('🗑️ Cancelled all notifications to refresh', name: 'NotificationService');
      
      // 3. Programamos las nuevas notificaciones.
      for (final tx in recurringTxs) {
        await _scheduleRemindersForTransaction(tx);
      }
      developer.log('✅ Refreshed and rescheduled ${recurringTxs.length} reminders', name: 'NotificationService');

    } catch (e, st) {
      developer.log('🔥 Error during refreshAllSchedules: $e', name: 'NotificationService', stackTrace: st);
    }
  }

  /// Prograna recordatorios para UNA SOLA transacción recurrente.
  Future<void> _scheduleRemindersForTransaction(RecurringTransaction tx) async {
    // Usamos el ID de la transacción (que es un UUID string) para generar un ID base único.
    final baseId = tx.id.hashCode & 0x7FFFFFFF; // Asegura que sea un entero de 31 bits positivo
    final now = tz.TZDateTime.now(tz.local);

    // Programamos recordatorios para los próximos 12 meses.
    for (var i = 0; i < 12; i++) {
      // Calcula la fecha de vencimiento futura
      final dueDate = tz.TZDateTime(tz.local, tx.nextDueDate.year, tx.nextDueDate.month + i, tx.nextDueDate.day);
      
      // El recordatorio es 3 días antes de la fecha de vencimiento
      final remindAt = dueDate.subtract(const Duration(days: 3));

      // Solo programamos si la fecha del recordatorio es en el futuro
      if (remindAt.isAfter(now)) {
        final notificationId = baseId + i; // Creamos un ID único para cada notificación futura
        
        await _localNotifier.zonedSchedule(
          notificationId,
          'Recordatorio: ${tx.description}',
          'Tu pago/cobro vence en 3 días.',
          remindAt,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'recurring_payments_channel', // ID del canal
              'Recordatorios de Pagos',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
