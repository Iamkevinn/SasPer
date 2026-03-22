// lib/services/smart_notification_worker.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';
import 'package:sasper/models/goal_model.dart';

const String smartGoalTask = "smart_goal_worker";

// 1. LE CAMBIAMOS EL NOMBRE PARA EVITAR CONFLICTOS
@pragma('vm:entry-point')
void smartGoalDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    developer.log('🧠 [SmartWorker] Iniciando evaluación...', name: 'SmartWorker');

    try {
      // 2. INICIALIZAR EL PLUGIN DE NOTIFICACIONES EN SEGUNDO PLANO (¡Faltaba esto!)
      final localNotifier = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await localNotifier.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit)
      );

      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString('supabase_url');
      final anonKey = prefs.getString('supabase_api_key');
      
      if (url == null || anonKey == null) return Future.value(false);

      await Supabase.initialize(url: url, anonKey: anonKey);
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;

      if (userId == null) return Future.value(true);

      final response = await client.from('goals').select().eq('user_id', userId).eq('status', 'active');
      final goals = (response as List).map((e) => Goal.fromMap(e)).toList();

      String topCategoryName = 'gastos innecesarios';
      try {
        final clientDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final catResponse = await client.rpc('get_expense_summary_by_category', params: {
          'p_user_id': userId, 'client_date': clientDate
        });
        if (catResponse is List && catResponse.isNotEmpty) {
          catResponse.sort((a, b) => (b['total_amount'] as num).compareTo(a['total_amount'] as num));
          topCategoryName = catResponse.first['category_name'];
        }
      } catch (_) {}

      final now = DateTime.now();
      final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

      for (final goal in goals) {
        if (goal.savingsFrequency == null || goal.targetDate == null || goal.currentAmount >= goal.targetAmount) {
          continue;
        }

        bool missedPayment = false;
        String missedText = '';

        final lastDate = (goal as dynamic).lastContributionDate ?? goal.createdAt; 
        final difference = now.difference(lastDate).inDays;

        if (goal.savingsFrequency == GoalSavingsFrequency.daily && difference >= 2) {
          missedPayment = true; missedText = 'ayer';
        } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly && difference >= 8) {
          missedPayment = true; missedText = 'la semana pasada';
        } else if (goal.savingsFrequency == GoalSavingsFrequency.monthly && difference >= 32) {
          missedPayment = true; missedText = 'el mes pasado';
        }

        if (missedPayment) {
          final remainingAmount = goal.targetAmount - goal.currentAmount;
          int periodsLeft = 1;
          if (goal.savingsFrequency == GoalSavingsFrequency.daily) {
            periodsLeft = goal.targetDate!.difference(now).inDays;
          } else if (goal.savingsFrequency == GoalSavingsFrequency.weekly) {
            periodsLeft = (goal.targetDate!.difference(now).inDays / 7).ceil();
          } else {
            periodsLeft = (goal.targetDate!.year - now.year) * 12 + goal.targetDate!.month - now.month;
          }
          if (periodsLeft <= 0) periodsLeft = 1;

          final recalculatedAmount = remainingAmount / periodsLeft;
          final amountStr = fmt.format(recalculatedAmount);

          final payloadJson = jsonEncode({
            'type': 'smart_goal_reminder',
            'goal_id': goal.id,
          });
          
          // 3. ENVIAR NOTIFICACIÓN
          await localNotifier.show(
            goal.id.hashCode & 0x7FFFFFFF,
            '⚠️ Reajuste para: ${goal.name}',
            'No ahorraste $missedText. Tu nueva cuota es de $amountStr. Guárdalo hoy o es muy probable que te lo gastes en $topCategoryName.',
             NotificationDetails(
              android: AndroidNotificationDetails(
                'goal_reminders_channel', 'Recordatorios de Metas',
                importance: Importance.max, priority: Priority.high,
                styleInformation: const BigTextStyleInformation(''),
                // 👇 NUEVO: BOTÓN DE ACCIÓN
                actions:[
                  const AndroidNotificationAction(
                    'AHORRAR_AHORA', 
                    'Ahorrar ahora 💰',
                    showsUserInterface: true, // Esto hace que la app se abra al tocar
                  ),
                ],
              ),
              iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
            ),
            payload: payloadJson,
          );
          
          developer.log('🔔[SmartWorker] Notificación lanzada: ${goal.name}', name: 'SmartWorker');
        }
      }

      return Future.value(true);
    } catch (e) {
      developer.log('🔥 [SmartWorker] Fallo: $e', name: 'SmartWorker');
      return Future.value(false);
    }
  });
}