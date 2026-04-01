// lib/services/budget_notification_intelligence.dart

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:sasper/models/budget_models.dart';
import 'package:sasper/services/notification_service.dart'
    show NotificationPayloadType;

const String _budgetChannelId = 'smart_budget_channel';

enum _BudgetInsightTier {
  exceeded,
  highRisk,
  earlyImbalance,
  onTrack,
}

// Límite de notificaciones diarias para no agobiar (global de presupuestos)
const int _kMaxBudgetNotifsPerDay = 2;

int _notifIdFor(int budgetId, _BudgetInsightTier tier) {
  final o = switch (tier) {
    _BudgetInsightTier.exceeded       => 0,
    _BudgetInsightTier.highRisk       => 1,
    _BudgetInsightTier.earlyImbalance => 2,
    _BudgetInsightTier.onTrack        => 3,
  };
  return ((budgetId ^ 0x5E771A) * 100 + o) & 0x7FFFFFFF;
}

String _periodKey(DateTime start) =>
    '${start.year}_${start.month}_${start.day}';

String _todayGlobalKey(tz.TZDateTime today) =>
    'bi_global_sent_${today.year}_${today.month}_${today.day}';

Future<void> runBudgetIntelligence(
  SupabaseClient client,
  FlutterLocalNotificationsPlugin localNotifier,
  String userId,
  SharedPreferences prefs,
) async {
  developer.log('📊 [Budget-Intel] Evaluando ritmos de gasto...', name: 'BudgetNotif');

  List<Budget> budgets;
  try {
    final response = await client.rpc(
      'get_active_budgets_with_progress',
      params: {'p_user_id': userId},
    );
    budgets = (response as List)
        .map((e) => Budget.fromMap(e as Map<String, dynamic>))
        .where((b) => b.isActive && b.amount > 0)
        .toList();
  } catch (e, st) {
    developer.log('🔥[Budget-Intel] Error cargando presupuestos: $e',
        name: 'BudgetNotif', stackTrace: st);
    return;
  }

  if (budgets.isEmpty) return;

  final nowTz    = tz.TZDateTime.now(tz.local);
  final todayMid = tz.TZDateTime(tz.local, nowTz.year, nowTz.month, nowTz.day);

  int sentToday = prefs.getInt(_todayGlobalKey(nowTz)) ?? 0;
  if (sentToday >= _kMaxBudgetNotifsPerDay) {
    developer.log('📊 [Budget-Intel] Tope diario ($_kMaxBudgetNotifsPerDay) alcanzado.', name: 'BudgetNotif');
    return;
  }

  for (final budget in budgets) {
    if (sentToday >= _kMaxBudgetNotifsPerDay) break;

    final startMid = tz.TZDateTime(tz.local, budget.startDate.year,
        budget.startDate.month, budget.startDate.day);
    final endMid = tz.TZDateTime(tz.local, budget.endDate.year,
        budget.endDate.month, budget.endDate.day);

    if (todayMid.isBefore(startMid) || todayMid.isAfter(endMid)) continue;

    final totalDays   = endMid.difference(startMid).inDays + 1;
    if (totalDays < 1) continue;

    final elapsedDays = todayMid.difference(startMid).inDays + 1;
    
    // t = % de tiempo transcurrido (0.0 a 1.0)
    final t = (elapsedDays / totalDays).clamp(0.0, 1.0);
    // g = % del presupuesto gastado (0.0 a >1.0)
    final g = (budget.spentAmount / budget.amount).clamp(0.0, double.infinity);

    final tier = _resolveTier(g: g, t: t, elapsedDays: elapsedDays, totalDays: totalDays);
    if (tier == null) continue;

    final dedupKey = 'bi_${budget.id}_${tier.name}_${_periodKey(budget.startDate)}';
    
    // 🛡️ ANTI-SPAM: Solo enviamos 1 notificación DE CADA TIPO por período de presupuesto.
    // Ejemplo: Te aviso 1 vez de Early Imbalance. Si mejoras, y luego caes en High Risk, te aviso 1 vez de High Risk.
    if (prefs.getBool(dedupKey) == true) continue;

    final (title, body) = _messageFor(tier, budget.category);
    final payload = jsonEncode({
      'type': NotificationPayloadType.smartBudgetInsight,
      'budget_id': budget.id,
    });

    await localNotifier.show(
      _notifIdFor(budget.id, tier),
      title,
      body,
      _budgetNotificationDetails(body),
      payload: payload,
    );

    // Bloqueamos este insight para este presupuesto en este período
    await prefs.setBool(dedupKey, true);

    sentToday++;
    await prefs.setInt(_todayGlobalKey(nowTz), sentToday);

    developer.log('📊[Budget-Intel] Emitida: ${tier.name} → ${budget.category}', name: 'BudgetNotif');
  }
}

_BudgetInsightTier? _resolveTier({
  required double g,
  required double t,
  required int elapsedDays,
  required int totalDays,
}) {
  // 1. Exceso Total (Gasto >= 100%)
  if (g >= 1.0) return _BudgetInsightTier.exceeded;
  
  // 2. Riesgo Alto (Gasto >= 80% ANTES del 70% del tiempo transcurrido)
  // Adaptado de tu "día 20", convertido a proporción para soportar presupuestos semanales/quincenales.
  if (g >= 0.8 && t < 0.70) return _BudgetInsightTier.highRisk;
  
  // 3. Desbalance Temprano (Gasto >= 50% en el primer 25% del tiempo)
  if (g >= 0.5 && t <= 0.25) return _BudgetInsightTier.earlyImbalance;
  
  // 4. Buen Ritmo (Gasto es 30% menor de lo que "debería" ir)
  // Ejemplo: Vamos a mitad de mes (t=0.50), deberías llevar 50% gastado.
  // Si llevas 20% (g <= 0.50 * 0.7 = 0.35), mereces una felicitación.
  if (t >= 0.20 && g <= (t * 0.70) && g > 0.05) return _BudgetInsightTier.onTrack;
  
  return null;
}

(String, String) _messageFor(_BudgetInsightTier tier, String category) {
  final c = category.trim().isEmpty ? 'la categoría' : '«$category»';
  return switch (tier) {
    _BudgetInsightTier.exceeded => (
        'Presupuesto superado ⚠️',
        'Has excedido tu límite para $c. Lo que gastes a partir de ahora afectará tus finanzas libres.',
      ),
    _BudgetInsightTier.highRisk => (
        'Frena un poco 🚦',
        'Estás a punto de agotar tu presupuesto de $c y aún falta bastante para el cierre.',
      ),
    _BudgetInsightTier.earlyImbalance => (
        'Gasto acelerado 📉',
        'Llevas la mitad del presupuesto de $c y el período apenas comienza. Trata de compensar los próximos días.',
      ),
    _BudgetInsightTier.onTrack => (
        '¡Ritmo perfecto! 🎯',
        'Vas súper bien. Tu gasto en $c está muy por debajo de lo esperado para esta fecha.',
      ),
  };
}

NotificationDetails _budgetNotificationDetails(String body) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      _budgetChannelId,
      'Presupuesto inteligente',
      channelDescription: 'Alertas sobre tu ritmo de gasto frente al avance del período.',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    ),
  );
}