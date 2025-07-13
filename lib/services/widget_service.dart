// lib/services/widget_service.dart
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WidgetService {
  static const String appGroupId = 'group.com.example.sasper'; // Necesario para iOS

  static Future<void> updateBalanceWidget() async {
    try {
      // Obtenemos el saldo total directamente
      final data = await Supabase.instance.client.rpc('get_dashboard_data');
      final totalBalance = (data['total_balance'] as num? ?? 0).toDouble();
      final formattedBalance = NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(totalBalance);

      // Guardamos los datos que el widget nativo leerá
      await HomeWidget.saveWidgetData<String>('balance', formattedBalance);
      
      // Le decimos al sistema que actualice la vista del widget
      await HomeWidget.updateWidget(
        name: 'HomeWidgetExampleProvider', // Debe coincidir con el nombre de la clase en Kotlin
        androidName: 'HomeWidgetExampleProvider',
        // iOSName: 'TuNombreDeWidgetEniOS'
      );
      print('Widget de saldo actualizado con: $formattedBalance');
    } catch (e) {
      print('Error al actualizar el widget: $e');
    }
  }
}