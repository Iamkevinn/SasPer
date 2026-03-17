// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/main.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sasper/config/app_config.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/models/recurring_transaction_model.dart';

// ==============================================================================
// HANDLERS GLOBALES (BACKGROUND)
// ==============================================================================

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse resp) {
  developer.log(
    '🔔 [Acción] Notificación tocada (payload: ${resp.payload})',
    name: 'NotificationService',
  );
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse resp) {
  developer.log(
    '🔔 [Background] Acción en segundo plano (payload: ${resp.payload})',
    name: 'NotificationService',
  );
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log(
      '🔔 [FCM-Background] Mensaje recibido: ${message.messageId}',
      name: 'NotificationService-FCM');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final supabaseUrl = prefs.getString('supabase_url');
  final supabaseApiKey = prefs.getString('supabase_api_key');

  if (supabaseUrl == null || supabaseApiKey == null) return;

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseApiKey);
  } catch (e) {
    if (!e.toString().contains('already been initialized')) {
      developer.log('🔥 Error en Supabase FCM Background: $e', name: 'NotificationService-FCM');
    }
  }

  try {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': fcmToken}).eq('id', uid);
      }
    }
  } catch (e) {
    developer.log('🔥 Error guardando token FCM Background: $e', name: 'NotificationService-FCM');
  }
}

// ==============================================================================
// SERVICIO PRINCIPAL
// ==============================================================================

class NotificationService {
  late final SupabaseClient _supabase;
  late final FirebaseMessaging _firebaseMessaging;
  late final http.Client _httpClient;
  
  bool _dependenciesInitialized = false;

  final FlutterLocalNotificationsPlugin _localNotifier =
      FlutterLocalNotificationsPlugin();

  NotificationService._privateConstructor();
  static final NotificationService instance =
      NotificationService._privateConstructor();

  void initializeDependencies({
    required SupabaseClient supabaseClient,
    required FirebaseMessaging firebaseMessaging,
    http.Client? httpClient,
  }) {
    if (_dependenciesInitialized) {
      developer.log('⚡ Dependencias ya estaban inicializadas. Saltando...', name: 'NotificationService');
      return;
    }

    _supabase = supabaseClient;
    _firebaseMessaging = firebaseMessaging;
    _httpClient = httpClient ?? http.Client();
    
    _dependenciesInitialized = true;
    developer.log('✅ Dependencias inyectadas.', name: 'NotificationService');
  }

  // --- INICIALIZACIÓN RÁPIDA (Al arrancar la app) ---
  Future<void> initializeQuick() async {
    developer.log('🚀 Iniciando configuración de notificaciones...', name: 'NotificationService');

    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      developer.log('🌍 Zona horaria detectada: ${timezoneInfo.identifier}', name: 'NotificationService');
    } catch (e) {
      developer.log('⚠️ Fallo zona horaria: $e', name: 'NotificationService');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    final settings = InitializationSettings(android: androidInit, iOS: iosInit);
    
    await _localNotifier.initialize(
      settings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: onDidReceiveBackgroundNotificationResponse,
    );

    await _createAndroidChannels();
    _setupMessageListeners();
  }

  // --- INICIALIZACIÓN TARDÍA (Permisos y Token) ---
  Future<void> initializeLate() async {
    await _requestSystemPermissions();

    try {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true, badge: true, sound: true);

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _updateAndSaveToken();
      }
    } catch (e) {
      developer.log('🔥 Error FCM Init: $e', name: 'NotificationService');
    }
  }

  Future<void> _requestSystemPermissions() async {
    if (Platform.isAndroid) {
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) await Permission.notification.request();

      final alarmStatus = await Permission.scheduleExactAlarm.status;
      if (alarmStatus.isDenied) await Permission.scheduleExactAlarm.request();
    } else if (Platform.isIOS) {
      await _localNotifier
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> _updateAndSaveToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) await _saveTokenToSupabase(token);
    } catch (_) {}
  }

  void _setupMessageListeners() {
    FirebaseMessaging.onMessage.listen((msg) {
      developer.log('📲 FCM Foreground: ${msg.messageId}', name: 'NotificationService');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      developer.log('📂 FCM Opened: ${msg.messageId}', name: 'NotificationService');
      // AQUÍ: Lee el 'goal_id' del payload y navega a la meta
      final goalId = msg.data['goal_id'];
      if (goalId != null) {
        navigatorKey.currentState?.pushNamed('/goal_details', arguments: goalId);
      }
    });
    _firebaseMessaging.onTokenRefresh.listen((token) => _saveTokenToSupabase(token));
  }

  Future<void> _createAndroidChannels() async {
    final androidImpl = _localNotifier.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImpl == null) return;

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'recurring_payments_channel',
        'Recordatorios de Pagos',
        description: 'Notificaciones sobre gastos fijos.',
        importance: Importance.max,
        playSound: true,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'goal_reminders_channel', // ID único
        'Recordatorios de Metas', // Nombre visible para el usuario
        description: 'Notificaciones para ayudarte a cumplir tus metas de ahorro.',
        importance: Importance.max,
        playSound: true,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'free_trials_channel',
        'Pruebas Gratuitas',
        description: 'Alertas para cancelar suscripciones a tiempo.',
        importance: Importance.max,
        playSound: true,
      ),
    );

    await androidImpl.createNotificationChannel(
      const AndroidNotificationChannel(
        'test_channel',
        'Pruebas',
        importance: Importance.max,
      ),
    );
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase.from('profiles').update({'fcm_token': token}).eq('id', uid);
      developer.log('✅ Token FCM guardado en Supabase', name: 'NotificationService');
    } catch (e) {
      developer.log('⚠️ Error guardando token: $e', name: 'NotificationService');
    }
  }

  // ============================================================================
  // LÓGICA DE RECORDATORIOS RECURRENTES
  // ============================================================================

  Future<void> scheduleRecurringReminders(RecurringTransaction tx) async {
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) {
        throw Exception('Permiso de alarmas denegado. No se pueden programar recordatorios.');
      }
    }
    await _scheduleRemindersForTransaction(tx);
  }

  Future<void> cancelRecurringReminders(String txId) async {
    for (var i = 0; i < 12; i++) {
      await _localNotifier.cancel(('$txId-early-$i').hashCode & 0x7FFFFFFF);
      await _localNotifier.cancel(('$txId-final-$i').hashCode & 0x7FFFFFFF);
    }
    developer.log('🗑️ Alertas canceladas para ID: $txId (24 notificaciones)', name: 'NotificationService');
  }

  Future<void> refreshAllSchedules() async {
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      developer.log('⚠️ Sin permiso de alarmas. No se puede refrescar.', name: 'NotificationService');
      return;
    }
    
    developer.log('🔄 Refrescando todas las alarmas (Pagos y Metas)...', name: 'NotificationService');
    try {
      // 1. Borramos todo para evitar duplicados
      await _localNotifier.cancelAll();
      
      // 2. Reprogramamos TODOS los pagos recurrentes
      final recurringTxs = await RecurringRepository.instance.getAll();
      for (final tx in recurringTxs) {
        await _scheduleRemindersForTransaction(tx);
      }
      
      // 3. 👈 ¡NUEVO! Reprogramamos TODAS las metas con ritual activo
      final activeGoals = await GoalRepository.instance.getActiveGoals();
      int goalsScheduled = 0;
      for (final goal in activeGoals) {
        if (goal.savingsFrequency != null && goal.savingsAmount != null) {
          await scheduleGoalReminder(
            goalId: goal.id,
            goalName: goal.name,
            savingsAmount: goal.savingsAmount!,
            frequency: goal.savingsFrequency!,
            day: goal.savingsDayOfWeek ?? goal.savingsDayOfMonth,
          );
          goalsScheduled++;
        }
      }

      developer.log('✅ Alarmas restauradas: ${recurringTxs.length} pagos fijos y $goalsScheduled metas.', name: 'NotificationService');
    } catch (e) {
      developer.log('🔥 Error refrescando schedules: $e', name: 'NotificationService');
    }
  }

  // 👈 HERRAMIENTA DE DIAGNÓSTICO
  Future<void> debugCheckPendingNotifications() async {
    final pending = await _localNotifier.pendingNotificationRequests();
    developer.log('🔔 ====== ALARMAS PENDIENTES EN EL TELÉFONO: ${pending.length} ======', name: 'DEBUG_NOTIF');
    
    if (pending.isEmpty) {
      developer.log('❌ No hay ninguna notificación programada. El OS las borró o no se registraron.', name: 'DEBUG_NOTIF');
    } else {
      for (var p in pending) {
        developer.log('✅ ID: ${p.id} | Título: ${p.title} | Payload: ${p.payload}', name: 'DEBUG_NOTIF');
      }
    }
  }

  // 👈 PRUEBA DE 1 MINUTO
  Future<void> testOneMinuteNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    final inOneMinute = now.add(const Duration(minutes: 1));
    
    developer.log('⏰ Programando prueba para: $inOneMinute (Hora actual: $now)', name: 'DEBUG_NOTIF');

    await _localNotifier.zonedSchedule(
      999999,
      'Prueba de 1 Minuto',
      '¡Si ves esto, el sistema operativo SÍ permite alarmas exactas!',
      inOneMinute,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel', 'Recordatorios de Metas',
          importance: Importance.max, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    await debugCheckPendingNotifications();
  }
  
  Future<void> scheduleFreeTrialReminder({
    required String id,
    required String serviceName,
    required DateTime endDate,
    required double price, 
    required TimeOfDay notificationTime,
  }) async {
    final now = DateTime.now();
    final reminderDay = endDate.subtract(const Duration(days: 3));
    
    DateTime reminderDateTime = DateTime(
      reminderDay.year, reminderDay.month, reminderDay.day,
      notificationTime.hour, notificationTime.minute,
    );

    if (reminderDateTime.isBefore(now)) {
      if (endDate.isAfter(now)) {
        reminderDateTime = now.add(const Duration(minutes: 1));
      } else {
        return;
      }
    }

    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    await _localNotifier.zonedSchedule(
      id.hashCode & 0x7FFFFFFF,
      '⏰ ¡Prueba por finalizar!',
      'Tu prueba de $serviceName termina pronto. Cancela hoy para evitar el cobro de ${fmt.format(price)}.',
      tz.TZDateTime.from(reminderDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'free_trials_channel', 'Pruebas Gratuitas',
          importance: Importance.max, priority: Priority.high, playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  // 👈 --- NUEVO MÉTODO PARA NOTIFICACIONES DE METAS ---
  Future<void> showGoalSavingReminder({
    required String goalId,
    required String goalName,
    required double savingsAmount,
  }) async {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final amountString = fmt.format(savingsAmount);

    // El payload es un JSON que enviamos a la notificación.
    // Cuando el usuario interactúe, podremos leer estos datos.
    final payload = jsonEncode({
      'type': 'goal_reminder',
      'goal_id': goalId,
    });

    await _localNotifier.show(
      ('goal-$goalId').hashCode, // ID único para esta notificación
      '✨ Hoy toca ahorrar para tu meta',
      '¡Aporta $amountString para "$goalName"!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel',
          'Recordatorios de Metas',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          // --- ACCIONES INTERACTIVAS (BOTONES) ---
          actions: [
            const AndroidNotificationAction(
              'SAVED_ACTION', // ID de la acción
              'Ya lo guardé',
              showsUserInterface: true, // Abre la app al tocar
            ),
            const AndroidNotificationAction(
              'SNOOZE_ACTION',
              'Posponer',
              cancelNotification: true, // Cierra la notificación al tocar
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          categoryIdentifier: 'GOAL_REMINDER_CATEGORY', // Conectaremos esto en un paso futuro para iOS
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancelTrialReminder(String id) async {
    await _localNotifier.cancel(id.hashCode & 0x7FFFFFFF);
  }

  Future<void> _scheduleRemindersForTransaction(RecurringTransaction tx) async {
    final now = tz.TZDateTime.now(tz.local);
    final firstDueDate = tz.TZDateTime.from(tx.nextDueDate, tz.local);

    int scheduledCount = 0;
    
    for (var i = 0; i < 12; i++) {
      tz.TZDateTime dueDate;

      switch (tx.frequency.toLowerCase()) {
        case 'diario': dueDate = firstDueDate.add(Duration(days: i)); break;
        case 'semanal': dueDate = firstDueDate.add(Duration(days: i * 7)); break;
        case 'cada_2_semanas': dueDate = firstDueDate.add(Duration(days: i * 14)); break;
        case 'quincenal': dueDate = firstDueDate.add(Duration(days: i * 15)); break;
        case 'mensual': dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + i, firstDueDate.day, firstDueDate.hour, firstDueDate.minute); break;
        case 'bimestral': dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + (i * 2), firstDueDate.day, firstDueDate.hour, firstDueDate.minute); break;
        case 'trimestral': dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + (i * 3), firstDueDate.day, firstDueDate.hour, firstDueDate.minute); break;
        case 'semestral': dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + (i * 6), firstDueDate.day, firstDueDate.hour, firstDueDate.minute); break;
        case 'anual': dueDate = tz.TZDateTime(tz.local, firstDueDate.year + i, firstDueDate.month, firstDueDate.day, firstDueDate.hour, firstDueDate.minute); break;
        default: dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + i, firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
      }

      if (dueDate.isBefore(now)) continue;

      // 1. AVISO PREVIO (ID HASH SEGURO)
      final reminderEarly = dueDate.subtract(const Duration(days: 3));
      if (reminderEarly.isAfter(now)) {
        await _localNotifier.zonedSchedule(
          ('${tx.id}-early-$i').hashCode & 0x7FFFFFFF,
          '⏰ Recordatorio: ${tx.description}',
          'Tu pago vence en 3 días (${dueDate.day}/${dueDate.month})',
          reminderEarly,
          _notifDetails(tx.description, isFinal: false),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        scheduledCount++;
      }

      // 2. AVISO FINAL (ID HASH SEGURO)
      await _localNotifier.zonedSchedule(
        ('${tx.id}-final-$i').hashCode & 0x7FFFFFFF,
        '🔴 ¡Hoy vence!: ${tx.description}',
        'Tu pago vence HOY a las ${dueDate.hour}:${dueDate.minute.toString().padLeft(2, '0')}',
        dueDate,
        _notifDetails(tx.description, isFinal: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      scheduledCount++;
    }
  }

 

// 2. Método de programación corregido
// 1. Método auxiliar para calcular la fecha
tz.TZDateTime _nextOccurrence(GoalSavingsFrequency frequency, int? day) {
  final now = tz.TZDateTime.now(tz.local);
  
  // 1. Definimos la hora objetivo (ej: 9:00 AM)
  tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);

  // 2. Si ya pasó la hora de hoy, lo ponemos para mañana como base
  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }

  // 3. Lógica según la frecuencia
  switch (frequency) {
    case GoalSavingsFrequency.daily:
      // Si la hora de hoy ya pasó, ya se añadió 1 día en el paso 2.
      return scheduledDate;

    case GoalSavingsFrequency.weekly:
      // day: 1 (Lunes) a 7 (Domingo)
      if (day != null) {
        // Avanzamos hasta que el día de la semana coincida
        while (scheduledDate.weekday != day) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }
      }
      return scheduledDate;

    case GoalSavingsFrequency.monthly:
      // day: 1 a 31
      if (day != null) {
        // Ajustamos al día del mes solicitado
        scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month, day, 9, 0);
        // Si esa fecha ya pasó este mes, nos vamos al mes siguiente
        if (scheduledDate.isBefore(now)) {
          scheduledDate = tz.TZDateTime(tz.local, scheduledDate.year, scheduledDate.month + 1, day, 9, 0);
        }
      }
      return scheduledDate;
  }
}
// 2. El método de programación (SIN el parámetro problemático)
Future<void> scheduleGoalReminder({
  required String goalId,
  required String goalName,
  required double savingsAmount,
  required GoalSavingsFrequency frequency,
  int? day, 
}) async {
  final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final amountString = fmt.format(savingsAmount);

  final nextDate = _nextOccurrence(frequency, day);
  developer.log('📅 Programando meta $goalId para: $nextDate', name: 'NotificationService');
  
  await _localNotifier.zonedSchedule(
    goalId.hashCode & 0x7FFFFFFF, // Aseguramos un ID válido para Android
    '✨ Hoy toca ahorrar para tu meta',
    '¡Aporta $amountString para "$goalName"!',
    _nextOccurrence(frequency, day),
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'goal_reminders_channel', 
        'Recordatorios de Metas',
        importance: Importance.max, 
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true, 
        presentSound: true,
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    matchDateTimeComponents: _getMatchComponent(frequency), // 👈 Esto hace que se repita
  );
}

// 3. Helper para la repetición automática
DateTimeComponents? _getMatchComponent(GoalSavingsFrequency freq) {
  if (freq == GoalSavingsFrequency.daily) return DateTimeComponents.time;
  if (freq == GoalSavingsFrequency.weekly) return DateTimeComponents.dayOfWeekAndTime;
  if (freq == GoalSavingsFrequency.monthly) return DateTimeComponents.dayOfMonthAndTime;
  return null;
}

  NotificationDetails _notifDetails(String desc, {required bool isFinal}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'recurring_payments_channel', 'Recordatorios de Pagos',
        importance: Importance.max, priority: Priority.high,
        color: isFinal ? const Color(0xFFFF0000) : null,
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  /// Lanza una excepción si falla. La UI que llame a este método debe manejar el Snackbar.
  Future<void> testImmediateNotification() async {
    if (!await Permission.notification.isGranted) {
      final status = await Permission.notification.request();
      if (!status.isGranted) throw Exception('Permiso de notificaciones denegado');
    }
    
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) throw Exception('Permiso de alarmas exactas denegado');
    }

    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    
    await _localNotifier.zonedSchedule(
      99999,
      '🎉 Prueba Exitosa',
      'El sistema funciona correctamente. Hora: ${when.hour}:${when.minute}',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel', 'Pruebas',
          importance: Importance.max, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    developer.log('✅ Test notification programada para: $when', name: 'NotificationService');
  }

  Future<void> triggerBudgetNotification({
    required String userId,
    required String categoryName,
  }) async {
    final url = Uri.parse('${AppConfig.renderBackendBaseUrl}/check-budget-on-transaction');
    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'category': categoryName}),
      );
      if (response.statusCode != 200) {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      developer.log('🔥 Error triggerBudgetNotification: $e', name: 'NotificationService');
      throw Exception('No se pudo verificar el presupuesto.');
    }
  }
}