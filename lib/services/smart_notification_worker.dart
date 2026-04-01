
// lib/services/smart_notification_worker.dart
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
import 'package:sasper/services/credit_card_notification_intelligence.dart';
import 'package:sasper/services/notification_service.dart'
    show NotificationPayloadType;

const String smartGoalTask = 'smart_goal_worker';

// ID Estable pero acotado para poder usar espacios correlativos (+1, +2, etc) sin desbordar el entero de 32 bits
int _stableId(String goalId) {
  final hex = goalId.replaceAll('-', '').substring(0, 8);
  return (int.parse(hex, radix: 16) & 0x07FFFFFF) * 10;
}

@pragma('vm:entry-point')
void smartGoalDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('🧠[SmartWorker] DISPATCHER INICIADO — Tarea: $task',
        name: 'SmartWorker');

    try {
      tz.initializeTimeZones();
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    final localNotifier = FlutterLocalNotificationsPlugin();
    await localNotifier.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings()));
    await initializeDateFormatting('es_CO', null);

    final androidPlugin = localNotifier.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'credit_card_assistant_channel',
        'Asistente de tarjetas',
        description:
            'Alertas inteligentes sobre corte y pago de tus tarjetas.',
        importance: Importance.max,
      ));
    }

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('supabase_url');
    final anonKey = prefs.getString('supabase_api_key');
    final userId = prefs.getString('user_id');

    if (url == null || anonKey == null || userId == null) return true;

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } catch (e) {
      if (!e.toString().contains('already been initialized')) return false;
    }

    final client = Supabase.instance.client;

    try {
      await _runGoalIntelligence(client, localNotifier, userId, prefs);
      await runCreditCardIntelligence(client, localNotifier, userId, prefs);
      await _runEndOfMonthIntelligence(client, localNotifier, userId, prefs);
      developer.log('✅ [SmartWorker] Tarea completada.', name: 'SmartWorker');
      return true;
    } catch (e, stack) {
      developer.log('🔥 [SmartWorker] FALLO INESPERADO: $e',
          name: 'SmartWorker', stackTrace: stack);
      return false;
    }
  });
}

String _formatCOP(double amount) =>
    NumberFormat('#,##0', 'es_CO').format(amount);

/// 🕰️ LÓGICA DE RELOJ DESPERTADOR:
/// Jamás devuelve fechas en el pasado. Si configuras las 9 AM y son las 10 AM, te pasa para mañana.
/// Si configuras las 8 PM y son las 10 AM, lo deja para hoy a las 8 PM.
List<tz.TZDateTime> _getNextSavingDates({
  required GoalSavingsFrequency frequency,
  int? dayOfWeek,
  int? dayOfMonth,
  required int hour,
  required int minute,
  int count = 3,
}) {
  List<tz.TZDateTime> dates = [];
  final now = tz.TZDateTime.now(tz.local);

  if (frequency == GoalSavingsFrequency.daily) {
    tz.TZDateTime candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    while (dates.length < count) {
      dates.add(candidate);
      candidate = candidate.add(const Duration(days: 1));
    }
  } else if (frequency == GoalSavingsFrequency.weekly) {
    tz.TZDateTime candidate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    int targetDay = dayOfWeek ?? DateTime.monday;
    while (candidate.weekday != targetDay) {
      candidate = candidate.add(const Duration(days: 1));
    }
    if (candidate.isBefore(now)) {
      candidate = candidate.add(const Duration(days: 7));
    }
    while (dates.length < count) {
      dates.add(candidate);
      candidate = candidate.add(const Duration(days: 7));
    }
  } else if (frequency == GoalSavingsFrequency.monthly) {
    int targetDay = dayOfMonth ?? 1;
    int month = now.month;
    int year = now.year;

    while (dates.length < count) {
      int daysInMonth = DateTime(year, month + 1, 0).day;
      int actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
      tz.TZDateTime candidate =
          tz.TZDateTime(tz.local, year, month, actualDay, hour, minute);

      if (candidate.isBefore(now)) {
        month++;
        if (month > 12) {
          month = 1;
          year++;
        }
        continue;
      }

      dates.add(candidate);
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }
  return dates;
}

Future<void> _runGoalIntelligence(
  SupabaseClient client,
  FlutterLocalNotificationsPlugin localNotifier,
  String userId,
  SharedPreferences prefs,
) async {
  developer.log('🎯 [SmartWorker] INICIANDO EVALUACIÓN DE METAS...',
      name: 'SmartWorker');

  final goalsRaw = await client
      .from('goals')
      .select()
      .eq('user_id', userId)
      .eq('status', 'active');
  final goals = (goalsRaw as List).map((e) => Goal.fromMap(e)).toList();

  String? topCategoryName;
  try {
    final catResponse =
        await client.rpc('get_expense_summary_by_category', params: {
      'p_user_id': userId,
      'client_date': DateFormat('yyyy-MM-dd').format(DateTime.now())
    });
    if (catResponse is List && catResponse.isNotEmpty) {
      final sorted = List<Map<String, dynamic>>.from(catResponse);
      sorted.sort((a, b) {
        final aAmt = ((a['total_spent'] as num?) ?? 0).toDouble().abs();
        final bAmt = ((b['total_spent'] as num?) ?? 0).toDouble().abs();
        return bAmt.compareTo(aAmt); // descendente
      });
      topCategoryName = sorted.first['category'] as String?;
    }
  } catch (_) {}

  final nowTz = tz.TZDateTime.now(tz.local);
  final todayMid = tz.TZDateTime(tz.local, nowTz.year, nowTz.month, nowTz.day);

  for (final goal in goals) {
    if (goal.savingsFrequency == null ||
        goal.isCompleted ||
        goal.targetDate == null) continue;

    final targetMid = tz.TZDateTime(tz.local, goal.targetDate!.year,
        goal.targetDate!.month, goal.targetDate!.day);
    if (targetMid.isBefore(todayMid)) continue;

    // 1. Calculamos las próximas 3 fechas clave (SIEMPRE futuras gracias al Reloj Despertador)
    final nextDates = _getNextSavingDates(
        frequency: goal.savingsFrequency!,
        dayOfWeek: goal.savingsDayOfWeek,
        dayOfMonth: goal.savingsDayOfMonth,
        hour: goal.notificationHour,
        minute: goal.notificationMinute,
        count: 3);

    // Evaluamos el calendario independientemente de la hora para saber si HOY toca ahorrar
    bool esDiaDeAhorro = false;
    if (goal.savingsFrequency == GoalSavingsFrequency.daily) {
      esDiaDeAhorro = true;
    } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
      int targetDay = goal.savingsDayOfWeek ?? DateTime.monday;
      esDiaDeAhorro = (nowTz.weekday == targetDay);
    } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly) {
      int targetDay = goal.savingsDayOfMonth ?? 1;
      int daysInMonth = DateTime(nowTz.year, nowTz.month + 1, 0).day;
      int actualDay = targetDay > daysInMonth ? daysInMonth : targetDay;
      esDiaDeAhorro = (nowTz.day == actualDay);
    }

    // Cálculos matemáticos
    final daysLeft = targetMid.difference(todayMid).inDays;
    int savingEventsLeft = daysLeft;
    try {
      final eventsResult =
          await client.rpc('get_remaining_saving_events', params: {
        'p_goal_id': goal.id,
        'p_frequency': goal.savingsFrequency!.name,
        'p_day_of_week': goal.savingsDayOfWeek,
        'p_day_of_month': goal.savingsDayOfMonth,
        'p_target_date': goal.targetDate!.toIso8601String().split('T')[0]
      });
      savingEventsLeft = (eventsResult as int?) ?? daysLeft;
    } catch (_) {}

    final remaining = goal.remainingAmount;
    double recalculatedAmount = (daysLeft <= 1)
        ? remaining
        : (savingEventsLeft > 0 ? remaining / savingEventsLeft : remaining);
    if (recalculatedAmount > remaining) recalculatedAmount = remaining;

    final baselineAmount = goal.savingsAmount ?? recalculatedAmount;
    final isMathBehind = recalculatedAmount > baselineAmount + 10.0;
    bool isBehind = isMathBehind;

    // 🛡️ PERIODO DE GRACIA (48h)
    final createdAtTz = tz.TZDateTime.from(goal.createdAt, tz.local);
    if (nowTz.difference(createdAtTz).inHours < 48) {
      isBehind = false;
    }

    // Ajustar la nueva normalidad en la BD silenciosamente
    if (isMathBehind ||
        goal.savingsAmount == null ||
        (recalculatedAmount < baselineAmount - 10.0)) {
      try {
        await client
            .from('goals')
            .update({'savings_amount': recalculatedAmount}).eq('id', goal.id);
      } catch (_) {}
    }

    // 🧠 NUEVO: Memoria de Ritmo (¿Ha estado inactivo mucho tiempo?)
    final referenceDate = goal.lastContributionDate ?? goal.createdAt;
    final daysSinceLastAction =
        nowTz.difference(tz.TZDateTime.from(referenceDate, tz.local)).inDays;

    bool missedLastPeriod = false;
    if (goal.savingsFrequency == GoalSavingsFrequency.daily &&
        daysSinceLastAction >= 2) {
      missedLastPeriod = true;
    } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly &&
        daysSinceLastAction >= 8) {
      missedLastPeriod = true;
    } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly &&
        daysSinceLastAction >= 32) {
      missedLastPeriod = true;
    }

    final amountStr = '\$${_formatCOP(recalculatedAmount)}';
    final extraHint = topCategoryName != null
        ? ' Guárdalo antes de gastártelo en $topCategoryName.'
        : '';
    final payloadJson = jsonEncode({
      'type': NotificationPayloadType.smartGoalReminder,
      'goal_id': goal.id
    });

// ── ESCENARIO 2 (El Olvidadizo) ──
    if (isBehind && !esDiaDeAhorro) {
      // NUEVO: El candado se adapta a la frecuencia de la meta
      String dedupReajuste;

      if (goal.savingsFrequency == GoalSavingsFrequency.monthly) {
        // Candado MENSUAL (Solo suena 1 vez al mes)
        dedupReajuste = 'reajuste_${goal.id}_${nowTz.year}_${nowTz.month}';
      } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
        // Candado SEMANAL (Solo suena 1 vez por semana. Dividimos el día entre 7 para saber en qué semana del mes estamos)
        int weekOfMonth = (nowTz.day / 7).ceil();
        dedupReajuste =
            'reajuste_${goal.id}_${nowTz.year}_${nowTz.month}_sem$weekOfMonth';
      } else {
        // Candado DIARIO (Suena todos los días)
        dedupReajuste =
            'reajuste_${goal.id}_${nowTz.year}_${nowTz.month}_${nowTz.day}';
      }

      if (prefs.getBool(dedupReajuste) != true) {
        String title = '⚠️ Reajuste: ${goal.name}';
        String body =
            'Te atrasaste en tus ahorros. Para lograr tu meta, tu nueva cuota es $amountStr.$extraHint';

        await localNotifier.show(
            _stableId(goal.id) + 999,
            title,
            body,
            NotificationDetails(
                android: AndroidNotificationDetails(
                    'goal_reminders_channel', 'Recordatorios de Metas',
                    importance: Importance.max,
                    priority: Priority.high,
                    styleInformation: BigTextStyleInformation(body),
                    actions: const [
                      AndroidNotificationAction(
                          'AHORRAR_AHORA', 'Ahorrar ahora 💰',
                          showsUserInterface: true)
                    ]),
                iOS: const DarwinNotificationDetails(
                    presentAlert: true, presentSound: true)),
            payload: payloadJson);
        await prefs.setBool(dedupReajuste, true);
      }
    }

    // ── 2. PROGRAMACIÓN EXACTA DE ALARMAS (El Recordatorio) ──
    for (int i = 0; i < nextDates.length; i++) {
      final date = nextDates[i];

      String title = '✨ Hoy toca ahorrar: ${goal.name}';
      String body;

      // Dependiendo de tu historial, te felicita o te invita a retomar el ritmo
      if (missedLastPeriod || isBehind) {
        body =
            'Es hora de retomar el ritmo. Tu cuota reajustada es $amountStr.$extraHint';
      } else {
        body = '¡Vas excelente! Tu cuota es $amountStr.$extraHint';
      }

      final notifId = _stableId(goal.id) + i;
      final specificDetails = NotificationDetails(
          android: AndroidNotificationDetails(
              'goal_reminders_channel', 'Recordatorios de Metas',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(body),
              actions: const [
                AndroidNotificationAction('AHORRAR_AHORA', 'Ahorrar ahora 💰',
                    showsUserInterface: true)
              ]),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true));

      await localNotifier.zonedSchedule(
        notifId,
        title,
        body,
        date,
        specificDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: payloadJson,
      );
    }
  }
}

// =============================================================================
//  TAREA 2: INTELIGENCIA DE FIN DE MES (Sin cambios)
// =============================================================================
Future<void> _runEndOfMonthIntelligence(
    SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier,
    String userId,
    SharedPreferences prefs) async {
  final now = DateTime.now();
  final lastDay = DateTime(now.year, now.month + 1, 0).day;
  final daysRemaining = lastDay - now.day;
  final isAlmost = daysRemaining == 3;
  final isLast = now.day == lastDay;

  if (!isAlmost && !isLast) return;

  // 🛡️ CANDADO ANTI-SPAM (Evita que suene cada vez que abres la app)
  final fase = isLast ? 'last' : 'almost';
  final dedupEOM = 'eom_notified_${now.year}_${now.month}_$fase';
  if (prefs.getBool(dedupEOM) == true) return;
  await prefs.setBool(dedupEOM, true);

  final fmt =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  if (isLast) {
    await _runSurplusAnalysis(client, localNotifier, userId, fmt);
    await Future.delayed(const Duration(milliseconds: 300));
  }
  await _runTopExpensesAnalysis(client, localNotifier, userId, fmt, now);
}

Future<void> _runSurplusAnalysis(
    SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier,
    String userId,
    NumberFormat fmt) async {
  try {
    final response = await client
        .rpc('get_monthly_budget_surplus', params: {'p_user_id': userId});
    if (response is! List || response.isEmpty) return;

    final totalSurplus = (response as List).fold<double>(
        0.0, (sum, item) => sum + (item['surplus_amount'] as num));
    if (totalSurplus <= 0) return;

    final topCategory =
        response.first['category_name'] as String? ?? 'presupuesto';
    final body =
        'Te quedaron ${fmt.format(totalSurplus)} principalmente de "$topCategory". ¿Los mueves a una de tus metas?';

    await localNotifier.show(
      0x5E271C03,
      '✨ ¡Te sobró dinero este mes!',
      body,
      NotificationDetails(
          android: AndroidNotificationDetails(
              'goal_reminders_channel', 'Recordatorios de Metas',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(body)),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true)),
      payload: jsonEncode({'type': NotificationPayloadType.sweepSavings}),
    );
  } catch (_) {}
}

Future<void> _runTopExpensesAnalysis(
    SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier,
    String userId,
    NumberFormat fmt,
    DateTime now) async {
  try {
    final response = await client.rpc('get_expense_summary_by_category',
        params: {
          'p_user_id': userId,
          'client_date': DateFormat('yyyy-MM-dd').format(now)
        });
    if (response is! List || response.isEmpty) return;
    final expenses = (response as List)
        .map((item) => (
              name: (item['category'] as String?) ?? 'Otros',
              amount: ((item['total_spent'] as num?) ?? 0).toDouble().abs()
            ))
        .where((e) => e.amount > 0)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    if (expenses.isEmpty) return;

    final body = expenses.length == 1
        ? 'Tu mayor gasto fue en ${expenses[0].name} (${fmt.format(expenses[0].amount)}).'
        : expenses.length == 2
            ? 'Tus 2 mayores gastos: ${expenses[0].name} (${fmt.format(expenses[0].amount)}) y ${expenses[1].name} (${fmt.format(expenses[1].amount)}).'
            : 'Tus 3 mayores gastos: ${expenses[0].name} (${fmt.format(expenses[0].amount)}), ${expenses[1].name} (${fmt.format(expenses[1].amount)}) y ${expenses[2].name} (${fmt.format(expenses[2].amount)}).';

    await localNotifier.show(
        0x70E52A11,
        '📊 Resumen: ${DateFormat('MMMM', 'es_CO').format(now)}',
        body,
         NotificationDetails(
            android: AndroidNotificationDetails(
                'goal_reminders_channel', 'Recordatorios de Metas',
                importance: Importance.max,
                priority: Priority.high,
                styleInformation: BigTextStyleInformation(body)),
            iOS: DarwinNotificationDetails(
                presentAlert: true, presentSound: true)));
  } catch (_) {}
}
