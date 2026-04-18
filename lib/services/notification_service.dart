// lib/services/notification_service.dart

import 'dart:async';
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
import 'package:sasper/services/woop_event_bus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:sasper/main.dart'; 
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sasper/widgets/shared/woop_victory_sheet.dart';
import 'dart:ui';
import 'dart:isolate';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/models/recurring_transaction_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:sasper/services/woop_constants.dart';

// Stream global en el isolate principal — el WoopListenerWidget se suscribe aquí
final _woopTapController = StreamController<Map<String, String>>.broadcast();

const String kWoopIsolatePort = 'woop_victory_port';

 

@pragma('vm:entry-point')
Future<void> globalHandleNotificationTap(NotificationResponse resp) async {
  developer.log('🔔 Notif tapped — actionId: ${resp.actionId}', name: 'WOOP');
  if (resp.payload == null) return;
 
  try {
    final data = jsonDecode(resp.payload!) as Map<String, dynamic>;
    final isWoop = data['type'] == 'woop_victory' || resp.actionId == 'LOG_VICTORY';
 
    if (!isWoop) {
      _routeNonWoopNotification(data);
      return;
    }
 
    final manifestationId = data['manifestationId']?.toString() ?? '';
    final title = data['title']?.toString() ?? 'Tu meta';
    if (manifestationId.isEmpty) return;
 
    final payload = jsonEncode({
      'tapId': DateTime.now().millisecondsSinceEpoch.toString(),
      'manifestationId': manifestationId,
      'title': title,
    });
 
    // ─── SIEMPRE escribir en disco primero.
    // Es la única vía 100% confiable en todos los estados (foreground, background, muerta).
    // El WoopListenerWidget lo detecta en didChangeAppLifecycleState(resumed) o en el polling.
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await prefs.setString(kPendingWoopPayload, payload);
    developer.log('✅ WOOP guardado en disco: $title ($manifestationId)', name: 'WOOP');
 
    // ─── Bonus: si el puerto está disponible (app en foreground puro), enviar también.
    // Si no está disponible, no importa — el disco garantiza la entrega.
    final SendPort? sendPort = IsolateNameServer.lookupPortByName(kWoopIsolatePort);
    if (sendPort != null) {
      developer.log('⚡ Puerto disponible — enviando también via IsolateNameServer', name: 'WOOP');
      sendPort.send(payload);
    }
 
  } catch (e, stack) {
    developer.log('🔥 Error en globalHandleNotificationTap: $e\n$stack', name: 'WOOP');
  }
}

/// Stream que emite cuando el usuario toca "Lo logré" con la app viva
Stream<Map<String, String>> get woopTapStream => _woopTapController.stream;

// ─── Constantes de payload ────────────────────────────────────────────────────
class NotificationPayloadType {
  static const String smartGoalReminder = 'smart_goal_reminder';
  static const String goalReminder = 'goal_reminder';
  static const String sweepSavings = 'sweep_savings_suggestion';
  static const String creditCardAssistant = 'credit_card_assistant';
  static const String smartBudgetInsight = 'smart_budget_insight';
  static const String woopVictory = 'woop_victory';
  NotificationPayloadType._();
}

// ─── ID estable para notificaciones de meta ───────────────────────────────────
int _stableGoalNotifId(String goalId) {
  final hex = goalId.replaceAll('-', '').substring(0, 8);
  return (int.parse(hex, radix: 16) & 0x07FFFFFF) * 10; // FIX: igual al worker
}

// ─── Handlers globales (background) ──────────────────────────────────────────

void _routeNonWoopNotification(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  if (type == 'smart_goal_reminder' || type == 'goal_reminder') {
    navigatorKey.currentState?.pushNamed('/goals');
  } else if (type == 'credit_card_assistant') {
    final id = data['account_id'] as String?;
    if (id != null && id.isNotEmpty) {
      navigatorKey.currentState?.pushNamed('/account_details', arguments: id);
    }
  } else if (type == 'smart_budget_insight') {
    final raw = data['budget_id'];
    final id = raw is int ? raw : int.tryParse('$raw');
    if (id != null && id > 0) {
      navigatorKey.currentState?.pushNamed('/budget_details', arguments: id);
    }
  }
}

// ─── Handlers públicos (Flutter los llama internamente) ───────────────────────

@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse resp) {
  globalHandleNotificationTap(resp);
}

@pragma('vm:entry-point')
void onDidReceiveBackgroundNotificationResponse(NotificationResponse resp) {
  globalHandleNotificationTap(resp);
}


@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('🔔 [FCM-Background] Mensaje: ${message.messageId}',
      name: 'NotificationService-FCM');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  final supabaseUrl = prefs.getString('supabase_url');
  final supabaseKey = prefs.getString('supabase_api_key');
  if (supabaseUrl == null || supabaseKey == null) return;

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  } catch (e) {
    if (!e.toString().contains('already been initialized')) {
      developer.log('🔥 Error Supabase FCM Background: $e',
          name: 'NotificationService-FCM');
      return;
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

// ─── Servicio principal ───────────────────────────────────────────────────────

class NotificationService {
  late final SupabaseClient _supabase;
  late final FirebaseMessaging _firebaseMessaging;
  late final http.Client _httpClient;

  bool _dependenciesInitialized = false;
  bool _isRefreshingRecurring = false;

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
    if (_dependenciesInitialized) return;
    _supabase = supabaseClient;
    _firebaseMessaging = firebaseMessaging;
    _httpClient = httpClient ?? http.Client();
    _dependenciesInitialized = true;
    developer.log('✅ Dependencias inyectadas.', name: 'NotificationService');
  }

  // ── Inicialización rápida ─────────────────────────────────────────────────

  Future<void> initializeQuick() async {
    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      developer.log('🌍 Timezone: ${tzInfo.identifier}',
          name: 'NotificationService');
    } catch (e) {
      developer.log('⚠️ Fallo timezone: $e', name: 'NotificationService');
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _localNotifier.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          onDidReceiveBackgroundNotificationResponse,
    );

    await _createAndroidChannels();
    _setupMessageListeners();
  }

  // ── Inicialización tardía (permisos + token) ──────────────────────────────

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
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
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
      final goalId = msg.data['goal_id'];
      if (goalId != null) {
        navigatorKey.currentState
            ?.pushNamed('/goal_details', arguments: goalId);
      }
    });
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToSupabase);
  }

  Future<void> _createAndroidChannels() async {
    final impl = _localNotifier.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (impl == null) return;

    for (final channel in _kAndroidChannels) {
      await impl.createNotificationChannel(channel);
    }
  }

  static const _kAndroidChannels =[
    AndroidNotificationChannel(
      'recurring_payments_channel',
      'Recordatorios de Pagos',
      description: 'Notificaciones sobre gastos fijos.',
      importance: Importance.max,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'goal_reminders_channel',
      'Recordatorios de Metas',
      description:
          'Notificaciones para ayudarte a cumplir tus metas de ahorro.',
      importance: Importance.max,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'free_trials_channel',
      'Pruebas Gratuitas',
      description: 'Alertas para cancelar suscripciones a tiempo.',
      importance: Importance.max,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'test_channel',
      'Pruebas',
      importance: Importance.max,
    ),
    AndroidNotificationChannel(
      'credit_card_assistant_channel',
      'Asistente de tarjetas',
      description:
          'Alertas inteligentes sobre corte y pago de tus tarjetas de crédito.',
      importance: Importance.max,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'smart_budget_channel',
      'Presupuesto inteligente',
      description:
          'Alertas sobre tu ritmo de gasto frente al avance del período.',
      importance: Importance.high,
      playSound: true,
    ),
    AndroidNotificationChannel(
      'woop_channel',
      'Coaching WOOP',
      description: 'Recordatorios inteligentes y refuerzo positivo.',
      importance: Importance.max,
      playSound: true,
    ),
  ];

  Future<void> _saveTokenToSupabase(String token) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _supabase
          .from('profiles')
          .update({'fcm_token': token}).eq('id', uid);
    } catch (e) {
      developer.log('⚠️ Error guardando token: $e',
          name: 'NotificationService');
    }
  }

  // ── Pagos recurrentes ─────────────────────────────────────────────────────

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
  }

  Future<void> refreshRecurringSchedules() async {
    if (_isRefreshingRecurring) return;
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      return;
    }

    _isRefreshingRecurring = true;
    try {
      final txs = await RecurringRepository.instance.getAll();
      for (final tx in txs) {
        await cancelRecurringReminders(tx.id);
      }
      for (final tx in txs) {
        await _scheduleRemindersForTransaction(tx);
      }
      developer.log('✅ ${txs.length} pagos recurrentes reprogramados.',
          name: 'NotificationService');
    } catch (e) {
      developer.log('🔥 Error refrescando pagos recurrentes: $e',
          name: 'NotificationService');
    } finally {
      _isRefreshingRecurring = false;
    }
  }

  // ── Metas ─────────────────────────────────────────────────────────────────

  Future<void> refreshGoalSchedules() async {
    // 🧠 MIGRADO AL SMART WORKER
    developer.log('🧠 Las alarmas de metas ahora son manejadas por el SmartWorker.', name: 'NotificationService');
    try {
      final goals = await GoalRepository.instance.getActiveGoals();
      for (final goal in goals) {
        await cancelGoalReminder(goal.id);
      }
    } catch (_) {}
  }

Future<void> cancelGoalReminder(String goalId) async {
  final base = _stableGoalNotifId(goalId);
  // FIX: cancela los 4 IDs que el worker puede haber programado
  for (int i = 0; i < 3; i++) {
    await _localNotifier.cancel(base + i);
  }
  await _localNotifier.cancel(base + 999);
  // Limpieza legacy — IDs que versiones anteriores pudieron haber programado
  await _localNotifier.cancel(goalId.hashCode & 0x7FFFFFFF);
  developer.log('🗑️ Alarmas canceladas para meta: $goalId', name: 'NotificationService');
}

  Future<void> scheduleGoalReminder({
    required String goalId,
    required String goalName,
    required double savingsAmount,
    required GoalSavingsFrequency frequency,
    required int notificationHour,
    required int notificationMinute,
    int? day,
  }) async {
    // 🧠 MIGRADO AL SMART WORKER
  }

  // ── Pruebas gratuitas ─────────────────────────────────────────────────────

  Future<void> scheduleFreeTrialReminder({
    required String id,
    required String serviceName,
    required DateTime endDate,
    required double price,
    required TimeOfDay notificationTime,
  }) async {
    final now = DateTime.now();
    final reminderDay = endDate.subtract(const Duration(days: 3));
    DateTime reminderDT = DateTime(
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      notificationTime.hour,
      notificationTime.minute,
    );

    if (reminderDT.isBefore(now)) {
      if (endDate.isAfter(now)) {
        reminderDT = now.add(const Duration(minutes: 1));
      } else {
        return;
      }
    }

    final fmt =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    await _localNotifier.zonedSchedule(
      id.hashCode & 0x7FFFFFFF,
      '⏰ ¡Prueba por finalizar!',
      'Tu prueba de $serviceName termina pronto. Cancela para evitar el cobro de ${fmt.format(price)}.',
      tz.TZDateTime.from(reminderDT, tz.local),
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

  // ── Diagnóstico ───────────────────────────────────────────────────────────

  Future<void> debugCheckPendingNotifications() async {
    final pending = await _localNotifier.pendingNotificationRequests();
    developer.log('🔔 ALARMAS PENDIENTES: ${pending.length}',
        name: 'DEBUG_NOTIF');
    for (final p in pending) {
      developer.log('  ID: ${p.id} | ${p.title} | payload: ${p.payload}',
          name: 'DEBUG_NOTIF');
    }
  }

  Future<void> testOneMinuteNotification() async {
    final inOneMinute =
        tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    await _localNotifier.zonedSchedule(
      999999,
      'Prueba de 1 Minuto',
      '¡Si ves esto, las alarmas exactas funcionan!',
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

  Future<void> testImmediateNotification() async {
    if (!await Permission.notification.isGranted) {
      if (!await Permission.notification.request().then((s) => s.isGranted)) {
        throw Exception('Permiso de notificaciones denegado');
      }
    }
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      if (!await Permission.scheduleExactAlarm
          .request()
          .then((s) => s.isGranted)) {
        throw Exception('Permiso de alarmas exactas denegado');
      }
    }

    final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
    await _localNotifier.zonedSchedule(
      99999,
      '🎉 Prueba Exitosa',
      'El sistema funciona. Hora: ${when.hour}:${when.minute.toString().padLeft(2, '0')}',
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
  }

  Future<void> triggerBudgetNotification({
    required String userId,
    required String categoryName,
  }) async {
    final url = Uri.parse(
        '${AppConfig.renderBackendBaseUrl}/check-budget-on-transaction');
    try {
      final resp = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'category': categoryName}),
      );
      if (resp.statusCode != 200) {
        throw Exception('Error del servidor: ${resp.statusCode}');
      }
    } catch (e) {
      developer.log('🔥 Error triggerBudgetNotification: $e',
          name: 'NotificationService');
      throw Exception('No se pudo verificar el presupuesto.');
    }
  }

  // ── Helpers internos ──────────────────────────────────────────────────────

  tz.TZDateTime _nextOccurrence(
    GoalSavingsFrequency frequency,
    int? day, {
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    switch (frequency) {
      case GoalSavingsFrequency.daily:
        return scheduled;

      case GoalSavingsFrequency.weekly:
        if (day != null) {
          while (scheduled.weekday != day) {
            scheduled = scheduled.add(const Duration(days: 1));
          }
        }
        return scheduled;

      case GoalSavingsFrequency.monthly:
        if (day != null) {
          scheduled = tz.TZDateTime(
              tz.local, scheduled.year, scheduled.month, day, hour, minute);
          if (scheduled.isBefore(now)) {
            scheduled = tz.TZDateTime(tz.local, scheduled.year,
                scheduled.month + 1, day, hour, minute);
          }
        }
        return scheduled;
    }
  }

  DateTimeComponents? _matchComponent(GoalSavingsFrequency freq) =>
      switch (freq) {
        GoalSavingsFrequency.daily => DateTimeComponents.time,
        GoalSavingsFrequency.weekly => DateTimeComponents.dayOfWeekAndTime,
        GoalSavingsFrequency.monthly => DateTimeComponents.dayOfMonthAndTime,
      };

  // ── Pagos recurrentes — lógica interna ───────────────────────────────────

  Future<void> _scheduleRemindersForTransaction(RecurringTransaction tx) async {
    final now = tz.TZDateTime.now(tz.local);
    final firstDueDate = tz.TZDateTime.from(tx.nextDueDate, tz.local);

    for (var i = 0; i < 12; i++) {
      final dueDate = _computeDueDate(tx.frequency, firstDueDate, i);
      if (dueDate == null || dueDate.isBefore(now)) continue;

      final earlyDate = dueDate.subtract(const Duration(days: 3));
      if (earlyDate.isAfter(now)) {
        await _localNotifier.zonedSchedule(
          ('${tx.id}-early-$i').hashCode & 0x7FFFFFFF,
          '⏰ Recordatorio: ${tx.description}',
          'Tu pago vence en 3 días (${dueDate.day}/${dueDate.month})',
          earlyDate,
          _recurringNotifDetails(isFinal: false),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
      }

      await _localNotifier.zonedSchedule(
        ('${tx.id}-final-$i').hashCode & 0x7FFFFFFF,
        '🔴 ¡Hoy vence!: ${tx.description}',
        'Tu pago vence HOY a las ${dueDate.hour}:'
            '${dueDate.minute.toString().padLeft(2, '0')}',
        dueDate,
        _recurringNotifDetails(isFinal: true),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  tz.TZDateTime? _computeDueDate(
    String frequency,
    tz.TZDateTime first,
    int index,
  ) {
    try {
      return switch (frequency.toLowerCase()) {
        'diario' => first.add(Duration(days: index)),
        'semanal' => first.add(Duration(days: index * 7)),
        'cada_2_semanas' => first.add(Duration(days: index * 14)),
        'quincenal' => first.add(Duration(days: index * 15)),
        'mensual' => tz.TZDateTime(tz.local, first.year, first.month + index,
            first.day, first.hour, first.minute),
        'bimestral' => tz.TZDateTime(tz.local, first.year,
            first.month + (index * 2), first.day, first.hour, first.minute),
        'trimestral' => tz.TZDateTime(tz.local, first.year,
            first.month + (index * 3), first.day, first.hour, first.minute),
        'semestral' => tz.TZDateTime(tz.local, first.year,
            first.month + (index * 6), first.day, first.hour, first.minute),
        'anual' => tz.TZDateTime(tz.local, first.year + index, first.month,
            first.day, first.hour, first.minute),
        _ => tz.TZDateTime(tz.local, first.year, first.month + index, first.day,
            first.hour, first.minute),
      };
    } catch (_) {
      return null;
    }
  }

  NotificationDetails _recurringNotifDetails({required bool isFinal}) {
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

  @Deprecated('Usar refreshRecurringSchedules() o refreshGoalSchedules()')
  Future<void> refreshAllSchedules() async {
    await refreshRecurringSchedules();
    await refreshGoalSchedules();
  }
}

