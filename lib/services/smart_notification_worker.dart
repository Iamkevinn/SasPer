// lib/services/smart_notification_worker.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sasper/models/goal_model.dart';

const String smartGoalTask = "smart_goal_worker";

@pragma('vm:entry-point')
void smartGoalDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('🧠 [SmartWorker] DISPATCHER INICIADO. Tarea: $task',
        name: 'SmartWorker-DEBUG');

    final localNotifier = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await localNotifier.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit));

    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('supabase_url');
      final anonKey = prefs.getString('supabase_api_key');
      if (url == null || anonKey == null) {
        developer.log(
            '❌ [SmartWorker] ERROR: Credenciales de Supabase no encontradas.',
            name: 'SmartWorker-DEBUG');
        return Future.value(false);
      }

      await Supabase.initialize(url: url, anonKey: anonKey);
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        developer.log('❌ [SmartWorker] ERROR: No hay sesión de usuario activa.',
            name: 'SmartWorker-DEBUG');
        return Future.value(true);
      }
      developer.log('✅ [SmartWorker] Usuario encontrado: $userId',
          name: 'SmartWorker-DEBUG');

      await _runGoalIntelligence(client, localNotifier, userId);
      await _runEndOfMonthIntelligence(client, localNotifier, userId);

      developer.log('✅ [SmartWorker] Tareas ejecutadas con éxito.',
          name: 'SmartWorker-DEBUG');
      return Future.value(true);
    } catch (e, stack) {
      developer.log('🔥 [SmartWorker] FALLO CATASTRÓFICO: $e',
          name: 'SmartWorker-DEBUG', stackTrace: stack);
      return Future.value(false);
    }
  });
}

// =========================================================================
// Devuelve true si HOY es el día en que le toca ahorrar al usuario
// según la frecuencia y el día configurado en la meta.
// =========================================================================
bool _isSavingDayToday(
    GoalSavingsFrequency frequency, int? dayOfWeek, int? dayOfMonth) {
  final now = DateTime.now();
  switch (frequency) {
    case GoalSavingsFrequency.daily:
      return true;
    case GoalSavingsFrequency.weekly:
      // dayOfWeek: 1=Lunes ... 5=Viernes ... 7=Domingo (igual que DateTime.weekday)
      if (dayOfWeek == null) return false;
      return now.weekday == dayOfWeek;
    case GoalSavingsFrequency.monthly:
      // dayOfMonth: 1-31
      if (dayOfMonth == null) return false;
      return now.day == dayOfMonth;
  }
}

// =========================================================================
//              TAREA 1: INTELIGENCIA DE METAS
// =========================================================================
Future<void> _runGoalIntelligence(SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier, String userId) async {
  developer.log('🎯 [SmartWorker] Evaluando inteligencia de metas...',
      name: 'SmartWorker');

  await initializeDateFormatting('es_CO', null);

  final goalsResponse = await client
      .from('goals')
      .select()
      .eq('user_id', userId)
      .eq('status', 'active');
  final goals = (goalsResponse as List).map((e) => Goal.fromMap(e)).toList();

  String topCategoryName = 'gastos innecesarios';
  try {
    final clientDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final catResponse = await client.rpc('get_expense_summary_by_category',
        params: {'p_user_id': userId, 'client_date': clientDate});
    if (catResponse is List && catResponse.isNotEmpty) {
      catResponse.sort((a, b) =>
          (b['total_spent'] as num).compareTo(a['total_spent'] as num));
      topCategoryName = catResponse.first['category'] ?? 'gastos innecesarios';
    }
  } catch (_) {}

  // ✅ FIX TIMEZONE: Usar hora local, no UTC.
  // UTC causaba que daysLeft fuera 1 menos en Colombia (UTC-5)
  // cuando el worker corría después de las 7pm hora local.
  final nowLocal = DateTime.now();
  final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

  // ✅ FIX FORMATO: Construir el string manualmente para garantizar
  // que el símbolo quede a la izquierda en el isolate de Workmanager.
  final numFmt = NumberFormat('#,##0', 'es_CO');
  String formatCOP(double amount) => '\$${numFmt.format(amount)}';

  for (final goal in goals) {
    if (goal.savingsFrequency == null ||
        goal.targetDate == null ||
        goal.currentAmount >= goal.targetAmount) {
      continue;
    }

    final remainingAmount = goal.targetAmount - goal.currentAmount;

    // Normalizar fechas a medianoche local para que difference() sea exacto
    final targetLocal = DateTime(
      goal.targetDate!.year,
      goal.targetDate!.month,
      goal.targetDate!.day,
    );
    final createdLocal = DateTime(
      goal.createdAt.year,
      goal.createdAt.month,
      goal.createdAt.day,
    );

    // 1. CÁLCULO DE DÍAS Y CUOTA REAJUSTADA
    int daysLeft = targetLocal.difference(todayLocal).inDays;

    developer.log(
      '📅 [SmartWorker] Meta: ${goal.name} | '
      'Hoy (local): $todayLocal | Límite (local): $targetLocal | '
      'Días restantes: $daysLeft | Restante: $remainingAmount',
      name: 'SmartWorker-DEBUG',
    );

    if (daysLeft <= 0) {
      developer.log(
        '⏭️ [SmartWorker] Meta ${goal.name} vencida o vence hoy. Saltando.',
        name: 'SmartWorker-DEBUG',
      );
      continue;
    }

    if (daysLeft == 1) {
      developer.log(
        '⚠️ [SmartWorker] daysLeft=1 para ${goal.name}. Cuota = monto restante completo.',
        name: 'SmartWorker-DEBUG',
      );
    }

    final double dailyNeeded = remainingAmount / daysLeft;

    double recalculatedAmount = dailyNeeded;
    if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
      recalculatedAmount = dailyNeeded * 7;
    } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly) {
      recalculatedAmount = dailyNeeded * 30.4;
    }

    // Nunca pedir más de lo que falta
    if (recalculatedAmount > remainingAmount) {
      recalculatedAmount = remainingAmount;
    }

    // 2. DETECCIÓN DE ATRASO
    final int totalDays = targetLocal.difference(createdLocal).inDays;
    final int daysPassed = todayLocal.difference(createdLocal).inDays;

    developer.log(
      '📊 [SmartWorker] totalDays: $totalDays | daysPassed: $daysPassed | '
      'currentAmount: ${goal.currentAmount}',
      name: 'SmartWorker-DEBUG',
    );

    bool isBehind = false;
    String missedText = 'en los últimos días';

    if (totalDays > 0 && daysPassed > 0) {
      final expectedProgress = (goal.targetAmount / totalDays) * daysPassed;
      final gracePeriod = recalculatedAmount;

      developer.log(
        '🧮 [SmartWorker] expectedProgress: $expectedProgress | '
        'gracePeriod: $gracePeriod | umbral: ${expectedProgress - gracePeriod}',
        name: 'SmartWorker-DEBUG',
      );

      if (goal.currentAmount < (expectedProgress - gracePeriod)) {
        isBehind = true;
        if (goal.savingsFrequency == GoalSavingsFrequency.daily) {
          missedText = 'ayer';
        } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
          missedText = 'esta semana';
        } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly) {
          missedText = 'este mes';
        }
      }
    } else if (daysPassed > 3 && goal.currentAmount == 0) {
      isBehind = true;
      missedText = 'desde que creaste la meta';
    }

    // 3. CÁLCULO DEL DESPLAZAMIENTO
    // ¿Cuántos días se retrasaría la meta si no ahorra hoy?
    final String delayText;
    if (totalDays > 0) {
      final double originalDailyRate = goal.targetAmount / totalDays;
      final int daysDelay = originalDailyRate > 0
          ? (recalculatedAmount / originalDailyRate).round()
          : 1;
      delayText = daysDelay <= 1 ? '1 día' : '$daysDelay días';
    } else {
      delayText = '1 día';
    }

    developer.log(
      '📆 [SmartWorker] isBehind: $isBehind | delayText: $delayText | '
      'esDíaDePago: ${_isSavingDayToday(goal.savingsFrequency!, goal.savingsDayOfWeek, goal.savingsDayOfMonth)}',
      name: 'SmartWorker-DEBUG',
    );

    // 4. ENVÍO DE LA NOTIFICACIÓN
    final payloadJson =
        jsonEncode({'type': 'smart_goal_reminder', 'goal_id': goal.id});

    if (isBehind) {
      // CASO A: El usuario está atrasado → notificamos siempre, cualquier día.
      // Es urgente reajustar sin importar la frecuencia configurada.
      final amountStr = formatCOP(recalculatedAmount);

      developer.log(
        '🔔 [SmartWorker] NOTIFICANDO (reajuste): ${goal.name} | '
        'cuota: $amountStr | motivo: $missedText | desplazamiento: $delayText',
        name: 'SmartWorker-DEBUG',
      );

      final body = 'No ahorraste $missedText. Tu nueva cuota es de $amountStr. '
          'Si no ahorras hoy, tu meta se desplaza $delayText. '
          'Guárdalo antes de gastártelo en $topCategoryName.';

      await localNotifier.show(
        goal.id.hashCode & 0x7FFFFFFF,
        '⚠️ Reajuste para: ${goal.name}',
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'goal_reminders_channel',
            'Recordatorios de Metas',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(body),
            actions: const [
              AndroidNotificationAction(
                'AHORRAR_AHORA',
                'Ahorrar ahora 💰',
                showsUserInterface: true,
              ),
            ],
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true),
        ),
        payload: payloadJson,
      );
    } else {
      // CASO B: Está al día → solo notificamos si HOY es su día de ahorro.
      final bool esDiaDeAhorro = _isSavingDayToday(
        goal.savingsFrequency!,
        goal.savingsDayOfWeek,
        goal.savingsDayOfMonth,
      );

      if (esDiaDeAhorro) {
        final amountStr = formatCOP(recalculatedAmount);

        developer.log(
          '🔔 [SmartWorker] NOTIFICANDO (recordatorio normal): ${goal.name} | '
          'cuota: $amountStr',
          name: 'SmartWorker-DEBUG',
        );

        final body = '¡Aporta $amountStr para "${goal.name}"! '
            'Te faltan ${formatCOP(remainingAmount)} para tu meta.';

        await localNotifier.show(
          goal.id.hashCode & 0x7FFFFFFF,
          '✨ Hoy toca ahorrar',
          body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              'goal_reminders_channel',
              'Recordatorios de Metas',
              importance: Importance.max,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(body),
              actions: const [
                AndroidNotificationAction(
                  'AHORRAR_AHORA',
                  'Ahorrar ahora 💰',
                  showsUserInterface: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
                presentAlert: true, presentSound: true),
          ),
          payload: payloadJson,
        );
      } else {
        developer.log(
          '✅ [SmartWorker] ${goal.name} al día y hoy no es su día de ahorro. No se notifica.',
          name: 'SmartWorker-DEBUG',
        );
      }
    }
  }
}

// =========================================================================
//              TAREA 2: INTELIGENCIA DE FIN DE MES
// =========================================================================
Future<void> _runEndOfMonthIntelligence(SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier, String userId) async {
  final now = DateTime.now();
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
  final isAlmostEndOfMonth = (lastDayOfMonth - now.day) == 3;
  final isLastDay = now.day == lastDayOfMonth;

  if (!isAlmostEndOfMonth && !isLastDay) {
    developer.log(
        '📅 [SmartWorker] No es fin de mes (día ${now.day}/$lastDayOfMonth). Omitiendo.',
        name: 'SmartWorker-DEBUG');
    return;
  }

  developer.log(
      '💸 [SmartWorker] Evaluando inteligencia de fin de mes (día ${now.day})...',
      name: 'SmartWorker-DEBUG');
  final fmt =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  await Future.wait([
    if (isLastDay) _runSurplusAnalysis(client, localNotifier, userId, fmt),
    _runTopExpensesAnalysis(client, localNotifier, userId, fmt, now),
  ]);

  await Future.delayed(const Duration(milliseconds: 500));
  developer.log('✅ [SmartWorker] Fin de mes completado.',
      name: 'SmartWorker-DEBUG');
}

Future<void> _runSurplusAnalysis(
    SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier,
    String userId,
    NumberFormat fmt) async {
  try {
    final surplusResponse = await client
        .rpc('get_monthly_budget_surplus', params: {'p_user_id': userId});
    developer.log('💰 Surplus: $surplusResponse', name: 'SmartWorker-DEBUG');

    if (surplusResponse is List && surplusResponse.isNotEmpty) {
      final totalSurplus = surplusResponse.fold<double>(
          0.0, (sum, item) => sum + (item['surplus_amount'] as num));
      final topSurplusCategory = surplusResponse.first['category_name'];
      await localNotifier.show(
        'sweep_savings'.hashCode,
        '✨ ¡Te sobró dinero este mes!',
        'Te quedaron ${fmt.format(totalSurplus)}, principalmente de "$topSurplusCategory". ¿Quieres moverlos a una de tus metas?',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'goal_reminders_channel',
            'Recordatorios de Metas',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS:
              DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: jsonEncode({'type': 'sweep_savings_suggestion'}),
      );
      developer.log('🔔 Notificación surplus enviada.',
          name: 'SmartWorker-DEBUG');
    }
  } catch (e, stack) {
    developer.log('🔥 Error surplus: $e\n$stack', name: 'SmartWorker-DEBUG');
  }
}

Future<void> _runTopExpensesAnalysis(
    SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier,
    String userId,
    NumberFormat fmt,
    DateTime now) async {
  try {
    await initializeDateFormatting('es_CO', null);
    final clientDate = DateFormat('yyyy-MM-dd').format(now);
    final response = await client.rpc('get_expense_summary_by_category',
        params: {'p_user_id': userId, 'client_date': clientDate});

    if (response is! List || response.isEmpty) return;

    final expenseData = (response as List)
        .map((item) => {
              'name': (item['category'] as String?) ?? 'Otros',
              'amount': ((item['total_spent'] as num?) ?? 0).toDouble().abs(),
            })
        .where((item) => (item['amount'] as double) > 0)
        .toList();

    if (expenseData.isEmpty) return;

    expenseData.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    String messageBody;
    if (expenseData.length == 1) {
      messageBody =
          'Tu mayor gasto fue en ${expenseData[0]['name']} (${fmt.format(expenseData[0]['amount'])}).';
    } else if (expenseData.length == 2) {
      messageBody =
          'Tus 2 mayores gastos: ${expenseData[0]['name']} (${fmt.format(expenseData[0]['amount'])}) y ${expenseData[1]['name']} (${fmt.format(expenseData[1]['amount'])}).';
    } else {
      messageBody =
          'Tus 3 mayores gastos: ${expenseData[0]['name']} (${fmt.format(expenseData[0]['amount'])}), ${expenseData[1]['name']} (${fmt.format(expenseData[1]['amount'])}) y ${expenseData[2]['name']} (${fmt.format(expenseData[2]['amount'])}).';
    }

    await localNotifier.show(
      'top_expenses'.hashCode,
      '📊 Resumen de Gastos: ${DateFormat('MMMM', 'es_CO').format(now)}',
      messageBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel',
          'Recordatorios de Metas',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
    developer.log('🔔 Notificación Top Gastos enviada.',
        name: 'SmartWorker-DEBUG');
  } catch (e, stack) {
    developer.log('🔥 Error Top Gastos: $e\n$stack',
        name: 'SmartWorker-DEBUG');
  }
}