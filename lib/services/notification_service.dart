// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
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
    developer.log('🔥 Error en FCM Background: $e', name: 'NotificationService-FCM');
  }
}

// ==============================================================================
// SERVICIO PRINCIPAL
// ==============================================================================

class NotificationService {
  late final SupabaseClient _supabase;
  late final FirebaseMessaging _firebaseMessaging;
  late final http.Client _httpClient;

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
    _supabase = supabaseClient;
    _firebaseMessaging = firebaseMessaging;
    _httpClient = httpClient ?? http.Client();
    developer.log('✅ Dependencias inyectadas.', name: 'NotificationService');
  }

  // --- INICIALIZACIÓN RÁPIDA (Al arrancar la app) ---
  Future<void> initializeQuick() async {
    developer.log('🚀 Iniciando configuración de notificaciones...', name: 'NotificationService');

    // 1. Configurar Zonas Horarias (CRÍTICO para alarmas exactas)
    try {
      tz.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final String timeZoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      developer.log('🌍 Zona horaria detectada: $timeZoneName', name: 'NotificationService');
    } catch (e) {
      developer.log('⚠️ Fallo zona horaria (usando UTC): $e', name: 'NotificationService');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    // 2. Configurar Plugin
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
    // 1. Pedir permisos de sistema (Android 13+ / iOS)
    await _requestSystemPermissions();

    // 2. Configurar FCM
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
      // Android 13+ Notificaciones
      final notifStatus = await Permission.notification.status;
      if (notifStatus.isDenied) await Permission.notification.request();

      // Android 12+ Alarmas Exactas (Vital para zonedSchedule)
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

  // ============================================================================
  // LÓGICA DE RECORDATORIOS RECURRENTES (VERSIÓN CORREGIDA Y LIMPIA)
  // ============================================================================

  /// Programa recordatorios para una transacción recurrente.
  /// Crea DOS notificaciones por mes durante los próximos 12 meses:
  /// - Aviso previo: 3 días antes del vencimiento
  /// - Aviso final: El mismo día del vencimiento
  Future<void> scheduleRecurringReminders(RecurringTransaction tx) async {
    // Validar permisos antes de continuar
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      developer.log('⚠️ Permiso de alarma exacta faltante. Solicitando...', name: 'NotificationService');
      await Permission.scheduleExactAlarm.request();
      
      // Si el usuario rechaza, no podemos continuar
      if (!await Permission.scheduleExactAlarm.isGranted) {
        developer.log('❌ Permiso denegado. No se pueden programar alarmas.', name: 'NotificationService');
        return;
      }
    }
    
    await _scheduleRemindersForTransaction(tx);
  }

  /// Cancela todas las alertas de una transacción específica.
  /// Elimina tanto avisos previos como avisos finales (24 notificaciones total).
  Future<void> cancelRecurringReminders(String txId) async {
    final baseId = txId.hashCode & 0x7FFFFFFF;
    
    // Cancelar avisos previos (12 meses)
    for (var i = 0; i < 12; i++) {
      await _localNotifier.cancel(baseId + i);
    }
    
    // Cancelar avisos finales (12 meses)
    for (var i = 0; i < 12; i++) {
      await _localNotifier.cancel(baseId + i + 10000);
    }
    
    developer.log('🗑️ Alertas canceladas para ID: $txId (24 notificaciones)', name: 'NotificationService');
  }

  /// Refresca todas las alarmas programadas.
  /// Útil al iniciar la app o después de restaurar un backup.
  Future<void> refreshAllSchedules() async {
    if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
      developer.log('⚠️ Sin permiso de alarmas. No se puede refrescar.', name: 'NotificationService');
      return;
    }
    
    developer.log('🔄 Refrescando todas las alarmas...', name: 'NotificationService');
    try {
      final recurringTxs = await RecurringRepository.instance.getAll();
      
      // Limpiar todas las notificaciones existentes
      await _localNotifier.cancelAll();
      
      // Re-programar cada transacción
      for (final tx in recurringTxs) {
        await _scheduleRemindersForTransaction(tx);
      }
      
      developer.log('✅ ${recurringTxs.length} transacciones actualizadas (${recurringTxs.length * 24} notificaciones)', name: 'NotificationService');
    } catch (e) {
      developer.log('🔥 Error refrescando schedules: $e', name: 'NotificationService');
    }
  }

  /// Lógica central para calcular y programar las notificaciones.
  /// ESTRATEGIA: Doble aviso por cada mes (previo + final)
  /// Programa notificaciones para los próximos 12 meses a partir de AHORA
Future<void> _scheduleRemindersForTransaction(RecurringTransaction tx) async {
  final baseId = tx.id.hashCode & 0x7FFFFFFF;
  final now = tz.TZDateTime.now(tz.local);
  final firstDueDate = tz.TZDateTime.from(tx.nextDueDate, tz.local);

  developer.log('📅 Programando [${tx.frequency}]: ${tx.description}', name: 'NotificationService');

  int scheduledCount = 0;
  
  // En lugar de un simple offset de meses, calculamos la próxima fecha 
  // basándonos en la frecuencia real.
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
        dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + i, firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
        break;
      case 'bimestral':
        dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + (i * 2), firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
        break;
      case 'trimestral':
        dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + (i * 3), firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
        break;
      case 'semestral':
        dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + (i * 6), firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
        break;
      case 'anual':
        dueDate = tz.TZDateTime(tz.local, firstDueDate.year + i, firstDueDate.month, firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
        break;
      default: // Default mensual
        dueDate = tz.TZDateTime(tz.local, firstDueDate.year, firstDueDate.month + i, firstDueDate.day, firstDueDate.hour, firstDueDate.minute);
    }

    // Si esta ocurrencia ya pasó, la saltamos
    if (dueDate.isBefore(now)) continue;

    // --- PROGRAMACIÓN DE ALERTAS (IGUAL A TU LÓGICA ANTERIOR) ---
    
    // 1. AVISO PREVIO (3 días antes)
    // Para frecuencias muy cortas (diario/semanal), quizás 3 días es mucho. 
    // Podrías poner un IF aquí si quieres evitarlo.
    final reminderEarly = dueDate.subtract(const Duration(days: 3));
    if (reminderEarly.isAfter(now)) {
      await _localNotifier.zonedSchedule(
        baseId + i,
        '⏰ Recordatorio: ${tx.description}',
        'Tu pago vence en 3 días (${dueDate.day}/${dueDate.month})',
        reminderEarly,
        _notifDetails(tx.description, isFinal: false),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      scheduledCount++;
    }

    // 2. AVISO FINAL (Mismo día)
    await _localNotifier.zonedSchedule(
      baseId + i + 10000,
      '🔴 ¡Hoy vence!: ${tx.description}',
      'Tu pago vence HOY a las ${dueDate.hour}:${dueDate.minute.toString().padLeft(2, '0')}',
      dueDate,
      _notifDetails(tx.description, isFinal: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
    scheduledCount++;
  }

  developer.log('✅ Finalizado: $scheduledCount notificaciones creadas.', name: 'NotificationService');
}

// Función auxiliar para limpiar el código de detalles
NotificationDetails _notifDetails(String desc, {required bool isFinal}) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'recurring_payments_channel',
      'Recordatorios de Pagos',
      importance: Importance.max,
      priority: Priority.high,
      color: isFinal ? const Color(0xFFFF0000) : null,
    ),
    iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );
}
  // ============================================================================
  // MÉTODOS AUXILIARES
  // ============================================================================

  /// Dispara una notificación de prueba en 5 segundos.
  /// Útil para verificar que el sistema de notificaciones funciona.
  Future<void> testImmediateNotification() async {
    _showSnackbar('🔔 Test: iniciando prueba...');
    
    try {
      // Verificar y solicitar permisos
      if (!await Permission.notification.isGranted) {
        await Permission.notification.request();
      }
      
      if (Platform.isAndroid && !await Permission.scheduleExactAlarm.isGranted) {
        await Permission.scheduleExactAlarm.request();
      }

      final when = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5));
      
      await _localNotifier.zonedSchedule(
        99999,
        '🎉 Prueba Exitosa',
        'Si ves esto, tu sistema de notificaciones funciona correctamente. Hora: ${when.hour}:${when.minute}',
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
      
      _showSnackbar('⏳ Notificación de prueba en 5 segundos...');
      developer.log('✅ Test notification programada para: $when', name: 'NotificationService');
    } catch (e) {
      _showSnackbar('🔥 Error en test: $e', isError: true);
      developer.log('🔥 Error test notification: $e', name: 'NotificationService');
    }
  }

  /// Llama al backend para verificar si una transacción excede el presupuesto.
  /// El backend puede enviar notificaciones FCM si se supera el límite.
  Future<void> triggerBudgetNotification({
    required String userId,
    required String categoryName,
  }) async {
    final url = Uri.parse('${AppConfig.renderBackendBaseUrl}/check-budget-on-transaction');
    
    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'category': categoryName,
        }),
      );
      
      if (response.statusCode == 200) {
        developer.log('✅ Budget check enviado para $categoryName', name: 'NotificationService');
      } else {
        developer.log('⚠️ Budget check falló: ${response.statusCode}', name: 'NotificationService');
      }
    } catch (e) {
      developer.log('🔥 Error triggerBudgetNotification: $e', name: 'NotificationService');
    }
  }
}