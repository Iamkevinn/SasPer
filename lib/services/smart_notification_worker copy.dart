// lib/services/smart_notification_worker.dart
//
// ─── POR QUÉ alarmClock EN LUGAR DE zonedSchedule ────────────────────────────
//
//  Existe un bug confirmado (#2243 en flutter_local_notifications):
//  zonedSchedule NO funciona en release mode cuando workmanager está instalado.
//  En debug funciona bien — por eso las pruebas engañan.
//
//  La causa raíz es que ProGuard/R8 (activado solo en release) ofusca las
//  clases internas de flutter_local_notifications que workmanager necesita
//  para reprogramar alarmas tras un reboot. Las clases quedan renombradas
//  y la reprogramación falla silenciosamente.
//
//  La solución probada por la comunidad: usar AndroidScheduleMode.alarmClock
//  en lugar de exactAllowWhileIdle. AlarmClock tiene tratamiento especial
//  en Android — aparece en el reloj del sistema, no puede ser bloqueado por
//  batería ni por Doze mode, y sobrevive al ProGuard.
//
// ─── ARQUITECTURA ────────────────────────────────────────────────────────────
//
//  El Worker corre a las 5:00 AM diariamente.
//  Para cada meta activa:
//
//  1. ¿Es hoy el día de ahorro? → NO: silencio. SÍ: continuar.
//  2. Dedup por goalId + fecha + hora (editar hora = nueva clave = nueva notif)
//  3. Calcular cuota reajustada con eventos reales (RPC)
//  4. Detectar incumplimiento por monto ahorrado en el período (RPC)
//  5A. Hora futura → zonedSchedule con AndroidScheduleMode.alarmClock
//  5B. Hora pasada → show() inmediato (worker retrasado por Android)

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/services/notification_service.dart'
    show NotificationPayloadType;

const String smartGoalTask = 'smart_goal_worker';

// ID estable: primeros 8 hex chars del UUID → reproducible entre ejecuciones
int _stableId(String goalId) =>
    int.parse(goalId.replaceAll('-', '').substring(0, 8), radix: 16) &
    0x7FFFFFFF;

// Clave dedup incluye hora → editar la hora ese mismo día genera notif nueva
String _dedupKey(String goalId, int hour, int minute) {
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  return 'notified_${goalId}_${today}_${hour}h${minute}m';
}

@pragma('vm:entry-point')
void smartGoalDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('🧠 [SmartWorker] Iniciando — tarea: $task',
        name: 'SmartWorker');

    // 1. Timezone con fallback
    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
      developer.log('🌍 Timezone: ${tzInfo.identifier}',
          name: 'SmartWorker');
    } catch (e) {
      developer.log('⚠️ Error timezone ($e). Fallback → America/Bogota',
          name: 'SmartWorker');
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    // 2. Notificador — inicializar por primera y única vez en este isolate
    final localNotifier = FlutterLocalNotificationsPlugin();
    await localNotifier.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    await initializeDateFormatting('es_CO', null);

    // 3. Credenciales
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('supabase_url');
    final anonKey = prefs.getString('supabase_api_key');
    final userId = prefs.getString('user_id');

    if (url == null || anonKey == null || userId == null) {
      developer.log('❌ Faltan credenciales. Abortando.', name: 'SmartWorker');
      return true;
    }

    // 4. Supabase idempotente
    SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (_) {
      try {
        await Supabase.initialize(url: url, anonKey: anonKey);
        client = Supabase.instance.client;
      } catch (e) {
        if (e.toString().contains('already been initialized')) {
          client = Supabase.instance.client;
        } else {
          developer.log('🔥 Error Supabase: $e', name: 'SmartWorker');
          return false;
        }
      }
    }

    developer.log('✅ Listo. userId: $userId', name: 'SmartWorker');

    try {
      await _runGoalIntelligence(client, localNotifier, userId, prefs);
      await _runEndOfMonthIntelligence(client, localNotifier, userId);
      return true;
    } catch (e, stack) {
      developer.log('🔥 Fallo inesperado: $e',
          name: 'SmartWorker', stackTrace: stack);
      return false;
    }
  });
}

bool _isSavingDayToday(
    GoalSavingsFrequency frequency, int? dayOfWeek, int? dayOfMonth) {
  final now = tz.TZDateTime.now(tz.local);
  return switch (frequency) {
    GoalSavingsFrequency.daily => true,
    GoalSavingsFrequency.weekly =>
      dayOfWeek != null && now.weekday == dayOfWeek,
    GoalSavingsFrequency.monthly =>
      dayOfMonth != null && now.day == dayOfMonth,
  };
}

String _fmtCOP(double amount) =>
    '\$${NumberFormat('#,##0', 'es_CO').format(amount)}';

// =============================================================================
//  TAREA 1: INTELIGENCIA DE METAS
// =============================================================================
Future<void> _runGoalIntelligence(
  SupabaseClient client,
  FlutterLocalNotificationsPlugin localNotifier,
  String userId,
  SharedPreferences prefs,
) async {
  developer.log('🎯 Evaluando metas...', name: 'SmartWorker');

  final goalsRaw = await client
      .from('goals')
      .select()
      .eq('user_id', userId)
      .eq('status', 'active');

  final goals = (goalsRaw as List)
      .map((e) => Goal.fromMap(e as Map<String, dynamic>))
      .toList();

  developer.log('📋 ${goals.length} metas activas.', name: 'SmartWorker');

  String? topCategory;
  try {
    final catResp = await client.rpc('get_expense_summary_by_category',
        params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        });
    if (catResp is List && catResp.isNotEmpty) {
      topCategory = catResp.first['category'] as String?;
    }
  } catch (_) {}

  final nowTz = tz.TZDateTime.now(tz.local);
  final todayMid = tz.TZDateTime(tz.local, nowTz.year, nowTz.month, nowTz.day);

  for (final goal in goals) {
    developer.log('─── "${goal.name}" ───', name: 'SmartWorker');

    if (goal.savingsFrequency == null) continue;
    if (goal.isCompleted) continue;
    if (goal.targetDate == null) continue;

    final targetMid = tz.TZDateTime(
        tz.local, goal.targetDate!.year, goal.targetDate!.month,
        goal.targetDate!.day);
    if (targetMid.isBefore(todayMid)) continue;

    // ¿Es hoy el día configurado?
    if (!_isSavingDayToday(
        goal.savingsFrequency!, goal.savingsDayOfWeek, goal.savingsDayOfMonth)) {
      developer.log('⏭️ No es el día configurado. Silencio.', name: 'SmartWorker');
      continue;
    }

    // Dedup: clave incluye hora → cambiar hora no queda bloqueado
    final dedupKey = _dedupKey(goal.id, goal.notificationHour, goal.notificationMinute);
    if (prefs.getBool(dedupKey) == true) {
      developer.log('⏭️ Ya notificada con esta hora hoy.', name: 'SmartWorker');
      continue;
    }

    // Calcular cuota con eventos reales del calendario
    final daysLeft = targetMid.difference(todayMid).inDays;
    int savingEvents = daysLeft;
    try {
      final eventsResult = await client.rpc('get_remaining_saving_events',
          params: {
            'p_goal_id': goal.id,
            'p_frequency': goal.savingsFrequency!.name,
            'p_day_of_week': goal.savingsDayOfWeek,
            'p_day_of_month': goal.savingsDayOfMonth,
            'p_target_date': goal.targetDate!.toIso8601String().split('T')[0],
          });
      savingEvents = (eventsResult as int?) ?? daysLeft;
    } catch (e) {
      developer.log('⚠️ RPC saving_events falló: $e', name: 'SmartWorker');
    }

    final remaining = goal.remainingAmount;
    double quota = daysLeft <= 1
        ? remaining
        : (savingEvents > 0 ? remaining / savingEvents : remaining);
    if (quota > remaining) quota = remaining;

    // Detección de incumplimiento por monto (no por días)
    double savedThisPeriod = 0;
    try {
      final savedResult = await client.rpc('get_savings_in_current_period',
          params: {
            'p_goal_id': goal.id,
            'p_frequency': goal.savingsFrequency!.name,
            'p_day_of_week': goal.savingsDayOfWeek,
            'p_day_of_month': goal.savingsDayOfMonth,
          });
      savedThisPeriod = (savedResult as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      developer.log('⚠️ RPC savings_period falló: $e', name: 'SmartWorker');
    }

    final expected = goal.savingsAmount ?? quota;
    final missing = expected - savedThisPeriod;
    final isBehind = missing > 0.01;

    developer.log(
        '📊 expected: ${_fmtCOP(expected)} | saved: ${_fmtCOP(savedThisPeriod)} | '
        'missing: ${_fmtCOP(missing)} | isBehind: $isBehind | daysLeft: $daysLeft',
        name: 'SmartWorker');

    // Actualizar cuota en BD si hay reajuste
    if (isBehind) {
      try {
        await client.from('goals').update({'savings_amount': quota}).eq('id', goal.id);
        developer.log('📝 savings_amount → ${_fmtCOP(quota)}', name: 'SmartWorker');
      } catch (e) {
        developer.log('⚠️ No pudo actualizar savings_amount: $e', name: 'SmartWorker');
      }
    }

    // Construir mensaje
    final amountStr = _fmtCOP(quota);
    final hint = topCategory != null
        ? ' Guárdalo antes de gastártelo en $topCategory.' : '';

    final String title;
    final String body;
    if (isBehind) {
      title = '⚠️ Reajuste: ${goal.name}';
      body = goal.savingsFrequency == GoalSavingsFrequency.daily
          ? 'Ayer no ahorraste. Tu nueva cuota diaria es $amountStr.$hint'
          : 'Faltaron ${_fmtCOP(missing)} el período pasado. '
              'Tu nueva cuota es $amountStr.$hint';
    } else {
      title = '✨ Hoy toca ahorrar: ${goal.name}';
      body = '¡Vas excelente! Tu cuota de hoy es $amountStr.$hint';
    }

    // Detalles de notificación
    final notifId = _stableId(goal.id);
    final payload = jsonEncode({
      'type': NotificationPayloadType.smartGoalReminder,
      'goal_id': goal.id,
    });
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'goal_reminders_channel',
        'Recordatorios de Metas',
        importance: Importance.max,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
        actions: const [
          AndroidNotificationAction(
            'AHORRAR_AHORA', 'Ahorrar ahora 💰',
            showsUserInterface: true,
          ),
        ],
      ),
      iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );

    // ── DECISIÓN: show() inmediato vs zonedSchedule con alarmClock ──────────
    //
    // Si la hora del usuario ya pasó (worker retrasado por Android):
    //   → show() inmediato. Llega tarde pero NUNCA se pierde.
    //
    // Si la hora aún no llegó (caso normal: worker a 5 AM, hora = 9:20 AM):
    //   → zonedSchedule con AndroidScheduleMode.alarmClock
    //   → AlarmClock aparece en el reloj del sistema, Android no lo bloquea
    //   → Funciona en release mode con workmanager (a diferencia de exactAllowWhileIdle)

    final scheduledTime = tz.TZDateTime(
        tz.local, nowTz.year, nowTz.month, nowTz.day,
        goal.notificationHour, goal.notificationMinute);

    developer.log(
        '⏱️ Ahora: $nowTz | Programada: $scheduledTime | '
        'HoraPasada: ${scheduledTime.isBefore(nowTz)}',
        name: 'SmartWorker');

    if (scheduledTime.isBefore(nowTz)) {
      developer.log('🚀 Hora pasada → show() INMEDIATO', name: 'SmartWorker');
      await localNotifier.show(notifId, title, body, details, payload: payload);
    } else {
      developer.log(
          '⏰ Hora futura → zonedSchedule (alarmClock) para '
          '${goal.notificationHour}:${goal.notificationMinute.toString().padLeft(2, '0')}',
          name: 'SmartWorker');
      await localNotifier.zonedSchedule(
        notifId, title, body,
        scheduledTime,
        details,
        // alarmClock: tratamiento especial de Android, visible en el reloj
        // del sistema. No es bloqueado por batería, Doze ni App Standby.
        // Funciona en release mode con workmanager instalado.
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        payload: payload,
      );
    }

    await prefs.setBool(dedupKey, true);
    developer.log('✅ "${goal.name}" procesada.', name: 'SmartWorker');
  }
}

// =============================================================================
//  TAREA 2: INTELIGENCIA DE FIN DE MES
// =============================================================================
Future<void> _runEndOfMonthIntelligence(
  SupabaseClient client,
  FlutterLocalNotificationsPlugin localNotifier,
  String userId,
) async {
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final isAlmost = (lastDay - now.day) == 3;
  final isLast = now.day == lastDay;

  if (!isAlmost && !isLast) return;

  developer.log('💸 Fin de mes — día ${now.day}/$lastDay.', name: 'SmartWorker');
  final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  if (isLast) {
    await _runSurplusAnalysis(client, localNotifier, userId, fmt);
    await Future.delayed(const Duration(milliseconds: 300));
  }
  await _runTopExpensesAnalysis(client, localNotifier, userId, fmt, now);
}

Future<void> _runSurplusAnalysis(
    SupabaseClient client, FlutterLocalNotificationsPlugin localNotifier,
    String userId, NumberFormat fmt) async {
  try {
    final resp = await client.rpc(
        'get_monthly_budget_surplus', params: {'p_user_id': userId});
    if (resp is! List || resp.isEmpty) return;
    final total = (resp as List).fold<double>(
        0.0, (s, i) => s + (i['surplus_amount'] as num));
    if (total <= 0) return;
    final cat = resp.first['category_name'] as String? ?? 'tu presupuesto';
    final body = 'Te quedaron ${fmt.format(total)} principalmente de '
        '"$cat". ¿Los mueves a una de tus metas?';
    await localNotifier.show(0x5E271C03, '✨ ¡Te sobró dinero este mes!', body,
      NotificationDetails(
        android: AndroidNotificationDetails('goal_reminders_channel',
            'Recordatorios de Metas',
            importance: Importance.max, priority: Priority.high,
            styleInformation: BigTextStyleInformation(body)),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: jsonEncode({'type': NotificationPayloadType.sweepSavings}),
    );
  } catch (e) {
    developer.log('🔥 Error surplus: $e', name: 'SmartWorker');
  }
}

Future<void> _runTopExpensesAnalysis(
    SupabaseClient client, FlutterLocalNotificationsPlugin localNotifier,
    String userId, NumberFormat fmt, DateTime now) async {
  try {
    final resp = await client.rpc('get_expense_summary_by_category',
        params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(now),
        });
    if (resp is! List || resp.isEmpty) return;
    final expenses = (resp as List)
        .map((i) => (
              name: (i['category'] as String?) ?? 'Otros',
              amount: ((i['total_spent'] as num?) ?? 0).toDouble().abs(),
            ))
        .where((e) => e.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (expenses.isEmpty) return;

    final String body;
    if (expenses.length == 1) {
      body = 'Tu mayor gasto fue en ${expenses[0].name} (${fmt.format(expenses[0].amount)}).';
    } else if (expenses.length == 2) {
      body = 'Tus 2 mayores gastos: ${expenses[0].name} (${fmt.format(expenses[0].amount)}) '
          'y ${expenses[1].name} (${fmt.format(expenses[1].amount)}).';
    } else {
      body = 'Tus 3 mayores gastos: ${expenses[0].name} (${fmt.format(expenses[0].amount)}), '
          '${expenses[1].name} (${fmt.format(expenses[1].amount)}) '
          'y ${expenses[2].name} (${fmt.format(expenses[2].amount)}).';
    }
    await localNotifier.show(0x70E52A11,
        '📊 Resumen: ${DateFormat('MMMM', 'es_CO').format(now)}', body,
      const NotificationDetails(
        android: AndroidNotificationDetails('goal_reminders_channel',
            'Recordatorios de Metas',
            importance: Importance.max, priority: Priority.high),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  } catch (e) {
    developer.log('🔥 Error top gastos: $e', name: 'SmartWorker');
  }
}