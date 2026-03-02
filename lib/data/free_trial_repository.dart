import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:supabase_flutter/supabase_flutter.dart';

class FreeTrialRepository {
  static final instance = FreeTrialRepository._();
  FreeTrialRepository._();

  final _client = Supabase.instance.client;

  // Stream en tiempo real
  Stream<List<Map<String, dynamic>>> get trialsStream => 
      _client.from('free_trials').stream(primaryKey: ['id']).order('end_date');

// En FreeTrialRepository
Future<Map<String, dynamic>> addTrial(String name, DateTime date, double price, String time, String frequency) async {
  final response = await _client.from('free_trials').insert({
    'user_id': _client.auth.currentUser!.id,
    'service_name': name,
    'end_date': date.toIso8601String(),
    'future_price': price,
    'notification_time': time, // Guardamos ej: "14:30"
    'frequency': frequency,
  }).select().single(); // 👈 IMPORTANTE: Esto hace que devuelva el objeto creado
  
  // actualizar widgets tras modificar datos
  await widget_service.WidgetService.updateNextPaymentWidget();
  await widget_service.WidgetService.updateUpcomingPaymentsWidget();

  return response;
}

  Future<void> updateTrial(String id, String name, DateTime date, double price,String time, String frequency) async {
    await _client.from('free_trials').update({
      'service_name': name,
      'end_date': date.toIso8601String(),
      'future_price': price,
      'notification_time': time,
      'frequency': frequency,

    }).eq('id', id);
  await widget_service.WidgetService.updateNextPaymentWidget();
  await widget_service.WidgetService.updateUpcomingPaymentsWidget();
  }

  Future<void> toggleCancel(String id, bool currentState) async {
    await _client.from('free_trials').update({'is_cancelled': !currentState}).eq('id', id);
  await widget_service.WidgetService.updateNextPaymentWidget();
  await widget_service.WidgetService.updateUpcomingPaymentsWidget();
  }

  Future<void> deleteTrial(String id) async {
    await _client.from('free_trials').delete().eq('id', id);
  await widget_service.WidgetService.updateNextPaymentWidget();
  await widget_service.WidgetService.updateUpcomingPaymentsWidget();  }
}