// lib/services/credit_card_notification_intelligence.dart
//
// Alertas contextuales para tarjetas de crédito (corte y pago), alimentadas
// con los mismos datos que Account / AccountRepository (vía RPC get_accounts_with_balance).

import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/notification_service.dart'
    show NotificationPayloadType;

const String _creditCardType = 'Tarjeta de Crédito';

int _stableCcBaseId(String accountId) {
  final hex = accountId.replaceAll('-', '').substring(0, 8);
  return int.parse(hex, radix: 16) & 0x03FFFFFF;
}

int _notifIdClosing(String accountId) =>
    ((_stableCcBaseId(accountId) << 2) ^ 0x1CC00001) & 0x7FFFFFFF;

int _notifIdDue(String accountId, int daysBucket) =>
    ((_stableCcBaseId(accountId) << 2) ^ (0x1CC00002 + daysBucket)) & 0x7FFFFFFF;

String _formatMoney(double amount) =>
    NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0)
        .format(amount);

int _dayClamped(int year, int month, int preferredDay) {
  final last = DateTime(year, month + 1, 0).day;
  return preferredDay > last ? last : preferredDay;
}

/// Próxima fecha de calendario con día `dayOfMonth` (1–31), >= [anchor] (comparación por día civil).
tz.TZDateTime _nextDayOfMonthOnOrAfter(
  tz.TZDateTime anchor,
  int dayOfMonth,
) {
  var y = anchor.year;
  var m = anchor.month;
  final anchorMid =
      tz.TZDateTime(tz.local, anchor.year, anchor.month, anchor.day);
  for (var i = 0; i < 14; i++) {
    final d = _dayClamped(y, m, dayOfMonth);
    final candMid = tz.TZDateTime(tz.local, y, m, d);
    if (!candMid.isBefore(anchorMid)) {
      return tz.TZDateTime(tz.local, y, m, d, anchor.hour, anchor.minute);
    }
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return anchorMid;
}

bool _isSameCalendarDay(tz.TZDateTime a, tz.TZDateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Ejecuta la lógica de notificaciones inteligentes para tarjetas.
/// Convive con [smart_notification_worker]: se llama desde el mismo dispatcher.
Future<void> runCreditCardIntelligence(
  SupabaseClient client,
  FlutterLocalNotificationsPlugin localNotifier,
  String userId,
  SharedPreferences prefs,
) async {
  developer.log('💳 [CC-Intel] Evaluando tarjetas de crédito...',
      name: 'CreditCardNotif');

  List<Account> cards;
  try {
    final response = await client.rpc(
      'get_accounts_with_balance',
      params: {'p_user_id': userId},
    );
    cards = (response as List)
        .map((e) => Account.fromMap(e as Map<String, dynamic>))
        .where((a) =>
            a.type == _creditCardType &&
            a.status == AccountStatus.active &&
            (a.closingDay != null || a.dueDay != null))
        .toList();
  } catch (e, st) {
    developer.log('🔥 [CC-Intel] Error cargando cuentas: $e',
        name: 'CreditCardNotif', stackTrace: st);
    return;
  }

  if (cards.isEmpty) return;

  final today = tz.TZDateTime.now(tz.local);
  final todayMid = tz.TZDateTime(tz.local, today.year, today.month, today.day);
  final tomorrowMid = todayMid.add(const Duration(days: 1));

  for (final card in cards) {
    await _maybeNotifyClosing(
      card: card,
      todayMid: todayMid,
      tomorrowMid: tomorrowMid,
      localNotifier: localNotifier,
      prefs: prefs,
    );
    await _maybeNotifyDue(
      card: card,
      todayMid: todayMid,
      localNotifier: localNotifier,
      prefs: prefs,
    );
  }
}

Future<void> _maybeNotifyClosing({
  required Account card,
  required tz.TZDateTime todayMid,
  required tz.TZDateTime tomorrowMid,
  required FlutterLocalNotificationsPlugin localNotifier,
  required SharedPreferences prefs,
}) async {
  final closingDay = card.closingDay;
  if (closingDay == null) return;

  final nextClosing =
      _nextDayOfMonthOnOrAfter(todayMid, closingDay);
  final closingMid = tz.TZDateTime(
      tz.local, nextClosing.year, nextClosing.month, nextClosing.day);

  if (!_isSameCalendarDay(closingMid, tomorrowMid)) return;

  final dedup =
      'cc_closing_${card.id}_${tomorrowMid.year}_${tomorrowMid.month}_${tomorrowMid.day}';
  if (prefs.getBool(dedup) == true) return;
  await prefs.setBool(dedup, true);

  final firstDayAfterClosing = tomorrowMid.add(const Duration(days: 1));
  final weekdayAfter =
      DateFormat('EEEE', 'es_CO').format(firstDayAfterClosing);

  final title = '📅 Mañana es tu corte: ${card.name}';
  final body =
      'Lo que compres hoy, lo pagas en este ciclo; si esperas hasta el $weekdayAfter, '
      'entra al siguiente y lo pagas el mes que viene.';

  final payload = jsonEncode({
    'type': NotificationPayloadType.creditCardAssistant,
    'account_id': card.id,
  });

  await localNotifier.show(
    _notifIdClosing(card.id),
    title,
    body,
    _ccNotificationDetails(body),
    payload: payload,
  );

  developer.log('💳 [CC-Intel] Corte mañana → ${card.name}',
      name: 'CreditCardNotif');
}

Future<void> _maybeNotifyDue({
  required Account card,
  required tz.TZDateTime todayMid,
  required FlutterLocalNotificationsPlugin localNotifier,
  required SharedPreferences prefs,
}) async {
  final dueDay = card.dueDay;
  if (dueDay == null) return;

  final nextDue = _nextDayOfMonthOnOrAfter(todayMid, dueDay);
  final dueMid =
      tz.TZDateTime(tz.local, nextDue.year, nextDue.month, nextDue.day);
  final daysUntil = dueMid.difference(todayMid).inDays;

  if (!const [0, 1, 3].contains(daysUntil)) return;

  final dedup =
      'cc_due_${card.id}_${dueMid.year}_${dueMid.month}_${dueMid.day}_$daysUntil';
  if (prefs.getBool(dedup) == true) return;
  await prefs.setBool(dedup, true);

  final debt = card.currentDebt.abs();
  final debtStr = _formatMoney(debt);

  String title;
  String body;
  if (daysUntil == 0) {
    title = '🔔 Hoy pagas: ${card.name}';
    body = debt > 0
        ? 'Es tu fecha de pago. Debes $debtStr.'
        : 'Es tu fecha de pago. ¡Sin saldo pendiente en la tarjeta!';
  } else if (daysUntil == 1) {
    title = '⏳ Mañana vence el pago: ${card.name}';
    body = debt > 0
        ? 'Falta 1 día para tu fecha de pago. Debes $debtStr.'
        : 'Falta 1 día para tu fecha de pago. Llevas la tarjeta al día.';
  } else {
    title = '💳 Pronto pagas: ${card.name}';
    body = debt > 0
        ? 'Faltan 3 días para tu fecha de pago. Debes $debtStr.'
        : 'Faltan 3 días para tu fecha de pago. Revisa tu estado de cuenta.';
  }

  final payload = jsonEncode({
    'type': NotificationPayloadType.creditCardAssistant,
    'account_id': card.id,
  });

  await localNotifier.show(
    _notifIdDue(card.id, daysUntil),
    title,
    body,
    _ccNotificationDetails(body),
    payload: payload,
  );

  developer.log(
      '💳 [CC-Intel] Pago en $daysUntil días → ${card.name}',
      name: 'CreditCardNotif');
}

NotificationDetails _ccNotificationDetails(String body) {
  return NotificationDetails(
    android: AndroidNotificationDetails(
      'credit_card_assistant_channel',
      'Asistente de tarjetas',
      channelDescription:
          'Alertas inteligentes sobre corte y pago de tus tarjetas.',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    ),
  );
}
