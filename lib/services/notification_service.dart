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
    '🔔 [Acción] Notificación tocada (payload: ${resp.payload}, botón: ${resp.actionId})',
    name: 'NotificationService',
  );

  if (resp.payload != null) {
    try {
      final data = jsonDecode(resp.payload!);
      if (data['type'] == 'smart_goal_reminder') {
        navigatorKey.currentState?.pushNamed('/goals');
      }
    } catch (e) {
      developer.log('🔥 Error leyendo payload: $e', name: 'NotificationService');
    }
  }
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
  developer.log('🔔 [FCM-Background] Mensaje recibido: ${message.messageId}',
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
      developer.log('🔥 Error en Supabase FCM Background: $e',
          name: 'NotificationService-FCM');
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
    developer.log('🔥 Error guardando token FCM Background: $e',
        name: 'NotificationService-FCM');
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
  bool _isRefreshingRecurring = false;
  bool _isRefreshingGoals = false;

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
      developer.log('⚡ Dependencias ya estaban inicializadas. Saltando...',
          name: 'NotificationService');
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
    developer.log('🚀 Iniciando configuración de notificaciones...',
        name: 'NotificationService');

    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      developer.log('🌍 Zona horaria detectada: ${timezoneInfo.identifier}',
          name: 'NotificationService');
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

    await _localNotifier.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
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
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
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
      developer.log('📲 FCM Foreground: ${msg.messageId}',
          name: 'NotificationService');
    });
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      developer.log('📂 FCM Opened: ${msg.messageId}',
          name: 'NotificationService');
      final goalId = msg.data['goal_id'];
      if (goalId != null) {
        navigatorKey.currentState
            ?.pushNamed('/goal_details', arguments: goalId);
      }
    });
    _firebaseMessaging.onTokenRefresh
        .listen((token) => _saveTokenToSupabase(token));
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
        'goal_reminders_channel',
        'Recordatorios de Metas',
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
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', uid);
      developer.log('✅ Token FCM guardado en Supabase',
          name: 'NotificationService');
    } catch (e) {
      developer.log('⚠️ Error guardando token: $e', name: 'NotificationService');
    }
  }

  // ============================================================================
  // PAGOS RECURRENTES
  // ============================================================================

  Future<void> scheduleRecurringReminders(RecurringTransaction tx) async {
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted) {
        throw Exception(
            'Permiso de alarmas denegado. No se pueden programar recordatorios.');
      }
    }
    await _scheduleRemindersForTransaction(tx);
  }

  Future<void> cancelRecurringReminders(String txId) async {
    for (var i = 0; i < 12; i++) {
      await _localNotifier.cancel(('$txId-early-$i').hashCode & 0x7FFFFFFF);
      await _localNotifier.cancel(('$txId-final-$i').hashCode & 0x7FFFFFFF);
    }
    developer.log('🗑️ Alertas canceladas para ID: $txId',
        name: 'NotificationService');
  }

  // ============================================================================
  // ✅ MÉTODO 1: Solo pagos recurrentes.
  // Llamar desde: main_screen.dart y al guardar/editar un pago recurrente.
  // NO reprograma metas — eso lo hace el worker inteligente.
  // ============================================================================
  Future<void> refreshRecurringSchedules() async {
    if (_isRefreshingRecurring) {
      developer.log('⚠️ refreshRecurringSchedules ya está corriendo. Saltando.',
          name: 'NotificationService');
      return;
    }

    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      developer.log('⚠️ Sin permiso de alarmas. No se puede refrescar.',
          name: 'NotificationService');
      return;
    }

    _isRefreshingRecurring = true;
    developer.log('🔄 Refrescando alarmas de pagos recurrentes...',
        name: 'NotificationService');

    try {
      // Cancelar solo las alarmas de pagos recurrentes
      // (no cancelamos metas para no pisar al worker inteligente)
      final recurringTxs = await RecurringRepository.instance.getAll();

      for (final tx in recurringTxs) {
        // Cancelar las 24 posibles alarmas de esta transacción antes de reprogramar
        await cancelRecurringReminders(tx.id);
      }

      for (final tx in recurringTxs) {
        await _scheduleRemindersForTransaction(tx);
      }

      developer.log(
          '✅ ${recurringTxs.length} pagos recurrentes reprogramados.',
          name: 'NotificationService');
    } catch (e) {
      developer.log('🔥 Error refrescando pagos recurrentes: $e',
          name: 'NotificationService');
    } finally {
      _isRefreshingRecurring = false;
    }
  }

  // ============================================================================
  // ✅ MÉTODO 2: Solo metas.
  // Llamar desde: al guardar/editar una meta.
  // El worker inteligente (Workmanager) ya maneja la notificación diaria real.
  // Este método programa el recordatorio estático de "hoy toca ahorrar"
  // que sirve como respaldo si el worker no corrió ese día.
  // ============================================================================
  Future<void> refreshGoalSchedules() async {
    if (_isRefreshingGoals) {
      developer.log('⚠️ refreshGoalSchedules ya está corriendo. Saltando.',
          name: 'NotificationService');
      return;
    }

    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      developer.log('⚠️ Sin permiso de alarmas. No se puede refrescar.',
          name: 'NotificationService');
      return;
    }

    _isRefreshingGoals = true;
    developer.log('🔄 Refrescando alarmas de metas...',
        name: 'NotificationService');

    try {
      final activeGoals = await GoalRepository.instance.getActiveGoals();
      int goalsScheduled = 0;

      for (final goal in activeGoals) {
        if (goal.savingsFrequency == null) continue;

        // ✅ FIX TIMEZONE: Normalizar fechas a medianoche para daysLeft exacto
        double cuotaReal = 0;
        if (goal.targetDate != null && goal.targetAmount > goal.currentAmount) {
          final today = DateTime.now();
          final todayMidnight = DateTime(today.year, today.month, today.day);
          final targetMidnight = DateTime(
            goal.targetDate!.year,
            goal.targetDate!.month,
            goal.targetDate!.day,
          );
          final daysLeft = targetMidnight.difference(todayMidnight).inDays;

          if (daysLeft > 0) {
            final remaining = goal.targetAmount - goal.currentAmount;
            final dailyNeeded = remaining / daysLeft;

            if (goal.savingsFrequency == GoalSavingsFrequency.daily) {
              cuotaReal = dailyNeeded;
            } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
              cuotaReal = dailyNeeded * 7;
            } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly) {
              cuotaReal = dailyNeeded * 30.4;
            }
            if (cuotaReal > remaining) cuotaReal = remaining;
          }
        }

        if (cuotaReal > 0) {
          // Cancelar la alarma anterior de esta meta antes de reprogramar
          await cancelGoalReminder(goal.id);

          await scheduleGoalReminder(
            goalId: goal.id,
            goalName: goal.name,
            savingsAmount: cuotaReal,
            frequency: goal.savingsFrequency!,
            day: goal.savingsDayOfWeek ?? goal.savingsDayOfMonth,
          );
          goalsScheduled++;
        }
      }

      developer.log('✅ $goalsScheduled metas reprogramadas.',
          name: 'NotificationService');
    } catch (e) {
      developer.log('🔥 Error refrescando metas: $e',
          name: 'NotificationService');
    } finally {
      _isRefreshingGoals = false;
    }
  }

  // ============================================================================
  // ⚠️ DEPRECADO — Mantener solo para compatibilidad temporal.
  // Reemplazar todas las llamadas por refreshRecurringSchedules() o
  // refreshGoalSchedules() según el contexto.
  // ============================================================================
  @Deprecated('Usar refreshRecurringSchedules() o refreshGoalSchedules()')
  Future<void> refreshAllSchedules() async {
    await refreshRecurringSchedules();
    await refreshGoalSchedules();
  }

  // ============================================================================
  // HERRAMIENTAS DE DIAGNÓSTICO
  // ============================================================================

  Future<void> debugCheckPendingNotifications() async {
    final pending = await _localNotifier.pendingNotificationRequests();
    developer.log(
        '🔔 ====== ALARMAS PENDIENTES: ${pending.length} ======',
        name: 'DEBUG_NOTIF');
    if (pending.isEmpty) {
      developer.log('❌ No hay notificaciones programadas.',
          name: 'DEBUG_NOTIF');
    } else {
      for (var p in pending) {
        developer.log(
            '✅ ID: ${p.id} | Título: ${p.title} | Payload: ${p.payload}',
            name: 'DEBUG_NOTIF');
      }
    }
  }

  Future<void> testOneMinuteNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    final inOneMinute = now.add(const Duration(minutes: 1));

    await _localNotifier.zonedSchedule(
      999999,
      'Prueba de 1 Minuto',
      '¡Si ves esto, el sistema operativo SÍ permite alarmas exactas!',
      inOneMinute,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel',
          'Recordatorios de Metas',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    await debugCheckPendingNotifications();
  }

  // ============================================================================
  // PRUEBAS GRATUITAS
  // ============================================================================

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
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      notificationTime.hour,
      notificationTime.minute,
    );

    if (reminderDateTime.isBefore(now)) {
      if (endDate.isAfter(now)) {
        reminderDateTime = now.add(const Duration(minutes: 1));
      } else {
        return;
      }
    }

    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    await _localNotifier.zonedSchedule(
      id.hashCode & 0x7FFFFFFF,
      '⏰ ¡Prueba por finalizar!',
      'Tu prueba de $serviceName termina pronto. Cancela hoy para evitar el cobro de ${fmt.format(price)}.',
      tz.TZDateTime.from(reminderDateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'free_trials_channel',
          'Pruebas Gratuitas',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelTrialReminder(String id) async {
    await _localNotifier.cancel(id.hashCode & 0x7FFFFFFF);
  }

  // ============================================================================
  // METAS — Notificación inmediata (usada puntualmente, no en el flujo normal)
  // ============================================================================

  Future<void> showGoalSavingReminder({
    required String goalId,
    required String goalName,
    required double savingsAmount,
  }) async {
    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final amountString = fmt.format(savingsAmount);
    final payload = jsonEncode({'type': 'goal_reminder', 'goal_id': goalId});

    await _localNotifier.show(
      ('goal-$goalId').hashCode,
      '✨ Hoy toca ahorrar para tu meta',
      '¡Aporta $amountString para "$goalName"!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel',
          'Recordatorios de Metas',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          actions: [
            const AndroidNotificationAction(
              'SAVED_ACTION',
              'Ya lo guardé',
              showsUserInterface: true,
            ),
            const AndroidNotificationAction(
              'SNOOZE_ACTION',
              'Posponer',
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
          categoryIdentifier: 'GOAL_REMINDER_CATEGORY',
        ),
      ),
      payload: payload,
    );
  }

  // ============================================================================
  // METAS — Programación periódica
  // ============================================================================

  Future<void> cancelGoalReminder(String goalId) async {
    await _localNotifier.cancel(('sched-$goalId').hashCode & 0x7FFFFFFF);
    developer.log('🗑️ Alarma cancelada para meta: $goalId',
        name: 'NotificationService');
  }

  Future<void> scheduleGoalReminder({
    required String goalId,
    required String goalName,
    required double savingsAmount,
    required GoalSavingsFrequency frequency,
    int? day,
  }) async {
    final schedId = ('sched-$goalId').hashCode & 0x7FFFFFFF;

    final fmt = NumberFormat.currency(
        locale: 'es_CO', symbol: r'$', decimalDigits: 0);
    final amountString = fmt.format(savingsAmount);
    final nextDate = _nextOccurrence(frequency, day);

    developer.log('📅 Programando meta $goalId para: $nextDate',
        name: 'NotificationService');

    await _localNotifier.zonedSchedule(
      schedId,
      '✨ Hoy toca ahorrar para tu meta',
      '¡Aporta $amountString para "$goalName"!',
      nextDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel',
          'Recordatorios de Metas',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: _getMatchComponent(frequency),
    );
  }

  // ✅ FIX HORA: Producción usa 9:00 AM fija, no "ahora + X segundos"
  tz.TZDateTime _nextOccurrence(GoalSavingsFrequency frequency, int? day) {
    final now = tz.TZDateTime.now(tz.local);

    // Hora objetivo: 9:00 AM del día de hoy
    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      9, // ✅ 9:00 AM fija — no "ahora + segundos"
      0,
    );

    // Si las 9 AM de hoy ya pasaron, mañana como base
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    switch (frequency) {
      case GoalSavingsFrequency.daily:
        return scheduledDate;

      case GoalSavingsFrequency.weekly:
        // day: 1=Lunes ... 5=Viernes ... 7=Domingo
        if (day != null) {
          while (scheduledDate.weekday != day) {
            scheduledDate = scheduledDate.add(const Duration(days: 1));
          }
        }
        return scheduledDate;

      case GoalSavingsFrequency.monthly:
        // day: 1-31
        if (day != null) {
          scheduledDate = tz.TZDateTime(
              tz.local, scheduledDate.year, scheduledDate.month, day, 9, 0);
          if (scheduledDate.isBefore(now)) {
            scheduledDate = tz.TZDateTime(
                tz.local, scheduledDate.year, scheduledDate.month + 1, day, 9, 0);
          }
        }
        return scheduledDate;
    }
  }

  DateTimeComponents? _getMatchComponent(GoalSavingsFrequency freq) {
    if (freq == GoalSavingsFrequency.daily) return DateTimeComponents.time;
    if (freq == GoalSavingsFrequency.weekly) return DateTimeComponents.dayOfWeekAndTime;
    if (freq == GoalSavingsFrequency.monthly) return DateTimeComponents.dayOfMonthAndTime;
    return null;
  }

  // ============================================================================
  // PAGOS RECURRENTES — Lógica interna
  // ============================================================================

  Future<void> _scheduleRemindersForTransaction(RecurringTransaction tx) async {
    final now = tz.TZDateTime.now(tz.local);
    final firstDueDate = tz.TZDateTime.from(tx.nextDueDate, tz.local);

    int scheduledCount = 0;

    for (var i = 0; i < 12; i++) {
      tz.TZDateTime dueDate;

      switch (tx.frequency.toLowerCase()) {
        case 'diario':
          dueDate = firstDueDate.add(Duration(days: i));
          break;
        case 'semanal':
          dueDate = firstDueDate.add(Duration(days: i * 7));
          break;
        case 'cada_2_semanas':
          dueDate = firstDueDate.add(Duration(days: i * 14));
          break;
        case 'quincenal':
          dueDate = firstDueDate.add(Duration(days: i * 15));
          break;
        case 'mensual':
          dueDate = tz.TZDateTime(tz.local, firstDueDate.year,
              firstDueDate.month + i, firstDueDate.day,
              firstDueDate.hour, firstDueDate.minute);
          break;
        case 'bimestral':
          dueDate = tz.TZDateTime(tz.local, firstDueDate.year,
              firstDueDate.month + (i * 2), firstDueDate.day,
              firstDueDate.hour, firstDueDate.minute);
          break;
        case 'trimestral':
          dueDate = tz.TZDateTime(tz.local, firstDueDate.year,
              firstDueDate.month + (i * 3), firstDueDate.day,
              firstDueDate.hour, firstDueDate.minute);
          break;
        case 'semestral':
          dueDate = tz.TZDateTime(tz.local, firstDueDate.year,
              firstDueDate.month + (i * 6), firstDueDate.day,
              firstDueDate.hour, firstDueDate.minute);
          break;
        case 'anual':
          dueDate = tz.TZDateTime(tz.local, firstDueDate.year + i,
              firstDueDate.month, firstDueDate.day,
              firstDueDate.hour, firstDueDate.minute);
          break;
        default:
          dueDate = tz.TZDateTime(tz.local, firstDueDate.year,
              firstDueDate.month + i, firstDueDate.day,
              firstDueDate.hour, firstDueDate.minute);
      }

      if (dueDate.isBefore(now)) continue;

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

  NotificationDetails _notifDetails(String desc, {required bool isFinal}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'recurring_payments_channel',
        'Recordatorios de Pagos',
        importance: Importance.max,
        priority: Priority.high,
        color: isFinal ? const Color(0xFFFF0000) : null,
      ),
      iOS: const DarwinNotificationDetails(
          presentAlert: true, presentSound: true),
    );
  }

  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  Future<void> testImmediateNotification() async {
    if (!await Permission.notification.isGranted) {
      final status = await Permission.notification.request();
      if (!status.isGranted)
        throw Exception('Permiso de notificaciones denegado');
    }
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      final status = await Permission.scheduleExactAlarm.request();
      if (!status.isGranted)
        throw Exception('Permiso de alarmas exactas denegado');
    }

    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));

    await _localNotifier.zonedSchedule(
      99999,
      '🎉 Prueba Exitosa',
      'El sistema funciona correctamente. Hora: ${when.hour}:${when.minute}',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Pruebas',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    developer.log('✅ Test notification programada para: $when',
        name: 'NotificationService');
  }

  Future<void> triggerBudgetNotification({
    required String userId,
    required String categoryName,
  }) async {
    final url = Uri.parse(
        '${AppConfig.renderBackendBaseUrl}/check-budget-on-transaction');
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
      developer.log('🔥 Error triggerBudgetNotification: $e',
          name: 'NotificationService');
      throw Exception('No se pudo verificar el presupuesto.');
    }
  }
}