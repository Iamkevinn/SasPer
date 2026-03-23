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

// Constante para identificar nuestra tarea en el sistema operativo
const String smartGoalTask = "smart_goal_worker";

@pragma('vm:entry-point')
void smartGoalDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('🧠 [SmartWorker] DISPATCHER INICIADO. Tarea: $task',
        name: 'SmartWorker-DEBUG');

    // Inicializamos el notificador aquí, para que ambas tareas lo puedan usar
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
            '❌ [SmartWorker] ERROR: Credenciales de Supabase no encontradas en SharedPreferences.',
            name: 'SmartWorker-DEBUG');
        return Future.value(false);
      }
      developer.log('✅ [SmartWorker] Credenciales de Supabase encontradas.',
          name: 'SmartWorker-DEBUG');

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
      // --- Ejecutamos ambas tareas inteligentes en secuencia ---
      // Si quieres, puedes ponerlas en un Future.wait para que corran en paralelo
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
//              TAREA 1: INTELIGENCIA DE METAS (Tu código original mejorado)
// =========================================================================
Future<void> _runGoalIntelligence(SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier, String userId) async {
  developer.log('🎯 [SmartWorker] Evaluando inteligencia de metas...',
      name: 'SmartWorker');
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

  final now = DateTime.now();
  final fmt =
      NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  for (final goal in goals) {
    if (goal.savingsFrequency == null ||
        goal.targetDate == null ||
        goal.currentAmount >= goal.targetAmount) {
      continue;
    }

    bool missedPayment = false;
    String missedText = '';

    final lastDate = (goal as dynamic).lastContributionDate ?? goal.createdAt;
    final difference = now.difference(lastDate).inDays;

    if (goal.savingsFrequency == GoalSavingsFrequency.daily &&
        difference >= 2) {
      missedPayment = true;
      missedText = 'ayer';
    } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly &&
        difference >= 8) {
      missedPayment = true;
      missedText = 'la semana pasada';
    } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly &&
        difference >= 32) {
      missedPayment = true;
      missedText = 'el mes pasado';
    }

    if (missedPayment) {
      final remainingAmount = goal.targetAmount - goal.currentAmount;

      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(
          goal.targetDate!.year, goal.targetDate!.month, goal.targetDate!.day);

      int periodsLeft = 1;
      if (goal.savingsFrequency == GoalSavingsFrequency.daily) {
        periodsLeft = target.difference(today).inDays;
      } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
        periodsLeft = (target.difference(today).inDays / 7).ceil();
      } else {
        periodsLeft =
            (target.year - today.year) * 12 + target.month - today.month;
      }

      if (periodsLeft <= 0) periodsLeft = 1;

      final recalculatedAmount = remainingAmount / periodsLeft;
      final amountStr = fmt.format(recalculatedAmount);

      final payloadJson =
          jsonEncode({'type': 'smart_goal_reminder', 'goal_id': goal.id});

      await localNotifier.show(
        goal.id.hashCode & 0x7FFFFFFF,
        '⚠️ Reajuste para: ${goal.name}',
        'No ahorraste $missedText. Tu nueva cuota es de $amountStr. Guárdalo hoy o es muy probable que te lo gastes en $topCategoryName.',
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'goal_reminders_channel',
            'Recordatorios de Metas',
            importance: Importance.max,
            priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
            actions: [
              AndroidNotificationAction('AHORRAR_AHORA', 'Ahorrar ahora 💰',
                  showsUserInterface: true),
            ],
          ),
          iOS: const DarwinNotificationDetails(
              presentAlert: true, presentSound: true),
        ),
        payload: payloadJson,
      );

      developer.log(
          '🔔 [SmartWorker] Notificación de reajuste lanzada para meta: ${goal.name}',
          name: 'SmartWorker');
    }
  }
}

// =========================================================================
//              TAREA 2: INTELIGENCIA DE FIN DE MES (¡NUEVO!)
// =========================================================================
Future<void> _runEndOfMonthIntelligence(SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier, String userId) async {

  final now = DateTime.now();
  final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
  final isAlmostEndOfMonth = (lastDayOfMonth - now.day) == 3;
  final isLastDay = now.day == lastDayOfMonth;

  // ✅ Solo corre 3 días antes o el último día del mes
  if (!isAlmostEndOfMonth && !isLastDay) {
    developer.log('📅 [SmartWorker] No es fin de mes (día ${now.day}/$lastDayOfMonth). Omitiendo.', name: 'SmartWorker-DEBUG');
    return;
  }

  developer.log('💸 [SmartWorker] Evaluando inteligencia de fin de mes (día ${now.day})...', name: 'SmartWorker-DEBUG');
  final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  // El surplus solo tiene sentido el último día (ya se gastó todo el mes)
  // Los top gastos se muestran ambos días como "aviso" y "resumen final"
  await Future.wait([
    if (isLastDay) _runSurplusAnalysis(client, localNotifier, userId, fmt),
    _runTopExpensesAnalysis(client, localNotifier, userId, fmt, now),
  ]);

  await Future.delayed(const Duration(milliseconds: 500));
  developer.log('✅ [SmartWorker] Fin de mes completado.', name: 'SmartWorker-DEBUG');
}

Future<void> _runSurplusAnalysis(SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier, String userId,
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
            'goal_reminders_channel', 'Recordatorios de Metas',
            importance: Importance.max, priority: Priority.high,
            styleInformation: BigTextStyleInformation(''),
          ),
          iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
        ),
        payload: jsonEncode({'type': 'sweep_savings_suggestion'}),
      );
      developer.log('🔔 Notificación surplus enviada.', name: 'SmartWorker-DEBUG');
    }
  } catch (e, stack) {
    developer.log('🔥 Error surplus: $e\n$stack', name: 'SmartWorker-DEBUG');
  }
}

Future<void> _runTopExpensesAnalysis(SupabaseClient client,
    FlutterLocalNotificationsPlugin localNotifier, String userId,
    NumberFormat fmt, DateTime now) async {
  try {
    await initializeDateFormatting('es_CO', null);
    final clientDate = DateFormat('yyyy-MM-dd').format(now);
    final response = await client.rpc('get_expense_summary_by_category',
        params: {'p_user_id': userId, 'client_date': clientDate});

    developer.log('🔍 RAW Top Gastos: $response', name: 'SmartWorker-DEBUG');

    if (response is! List || response.isEmpty) return;

    final expenseData = (response as List)
        .map((item) => {
              'name': (item['category'] as String?) ?? 'Otros',
              'amount': ((item['total_spent'] as num?) ?? 0).toDouble().abs(),
            })
        .where((item) => (item['amount'] as double) > 0)
        .toList();

    developer.log('📋 Procesado: $expenseData', name: 'SmartWorker-DEBUG');

    if (expenseData.isEmpty) return;

    expenseData.sort((a, b) =>
        (b['amount'] as double).compareTo(a['amount'] as double));

    String messageBody;
    if (expenseData.length == 1) {
      messageBody = 'Tu mayor gasto fue en ${expenseData[0]['name']} (${fmt.format(expenseData[0]['amount'])}).';
    } else if (expenseData.length == 2) {
      messageBody = 'Tus 2 mayores gastos: ${expenseData[0]['name']} (${fmt.format(expenseData[0]['amount'])}) y ${expenseData[1]['name']} (${fmt.format(expenseData[1]['amount'])}).';
    } else {
      messageBody = 'Tus 3 mayores gastos: ${expenseData[0]['name']} (${fmt.format(expenseData[0]['amount'])}), ${expenseData[1]['name']} (${fmt.format(expenseData[1]['amount'])}) y ${expenseData[2]['name']} (${fmt.format(expenseData[2]['amount'])}).';
    }

    developer.log('📝 Mensaje: $messageBody', name: 'SmartWorker-DEBUG');

    await localNotifier.show(
      'top_expenses'.hashCode,
      '📊 Resumen de Gastos: ${DateFormat('MMMM', 'es_CO').format(now)}',
      messageBody,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'goal_reminders_channel', 'Recordatorios de Metas',
          importance: Importance.max, priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
    developer.log('🔔 Notificación Top Gastos enviada.', name: 'SmartWorker-DEBUG');
  } catch (e, stack) {
    developer.log('🔥 Error Top Gastos: $e\n$stack', name: 'SmartWorker-DEBUG');
  }
}