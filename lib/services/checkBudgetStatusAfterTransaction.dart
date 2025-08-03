// lib/services/budget_service.dart (NUEVO ARCHIVO Y NOMBRE)

// ignore_for_file: file_names

import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

// Importaríamos un NotificationService para enviar la notificación real
// import 'notification_service.dart'; 

class BudgetService {
  final SupabaseClient _client;
  // final NotificationService _notificationService; // Para el futuro

  // 1. Inyección de dependencias para tests
  BudgetService({
    SupabaseClient? client,
    // NotificationService? notificationService
  })  : _client = client ?? Supabase.instance.client;
        // _notificationService = notificationService ?? NotificationService();

  /// Verifica el estado de un presupuesto después de una transacción y, si es necesario,
  /// activa una notificación.
  Future<void> checkBudgetStatusAfterTransaction({
    required String categoryName,
    required String userId,
  }) async {
    developer.log(
      '📊 [Service] Checking budget status for category "$categoryName"',
      name: 'BudgetService',
    );
    
    try {
      // 2. UNA ÚNICA LLAMADA a la función RPC del backend
      final result = await _client.rpc('check_budget_status', params: {
        'p_user_id': userId,
        'p_category_name': categoryName,
      });

      developer.log('📝 RPC Result: $result', name: 'BudgetService');

      final status = result['status'] as String?;
      
      // 3. Si la RPC indica que se necesita una notificación, la enviamos.
      if (status == 'notification_needed') {
        final title = result['title'] as String;
        final body = result['body'] as String;
        
        developer.log('❗❗❗ NOTIFICATION NEEDED: "$title" - "$body"', name: 'BudgetService');
        
        // --- LLAMADA AL SERVICIO DE NOTIFICACIONES REAL ---
        // Aquí es donde invocarías a tu backend o a un servicio como Firebase
        // para que envíe la notificación push al dispositivo.
        // Ejemplo:
        // await _notificationService.sendPushNotification(
        //   userId: userId,
        //   title: title,
        //   body: body,
        // );
      } else {
        developer.log('✅ Budget on track or no budget found. No action needed.', name: 'BudgetService');
      }

    } catch (e, stackTrace) {
      developer.log(
        '🔥 [Service] Error checking budget status: $e',
        name: 'BudgetService',
        error: e,
        stackTrace: stackTrace,
      );
      // No re-lanzamos el error, ya que esta es una operación "en segundo plano"
      // y no debería impedir que la UI continúe (por ejemplo, después de añadir una transacción).
    }
  }
}