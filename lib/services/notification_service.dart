import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../firebase_options.dart';

// Función Top-Level para manejar mensajes en segundo plano
// Requisito de la librería: debe estar fuera de una clase.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
    print('Message data: ${message.data}');
    print('Message notification: ${message.notification?.title}');
  }
}

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> initializeNotifications() async {
    try {
      // 1. Pedir permiso al usuario
      await _firebaseMessaging.requestPermission();

      // 2. Obtener el token FCM
      final String? fcmToken = await _firebaseMessaging.getToken();
      if (fcmToken != null) {
        if (kDebugMode) {
          print("---------------------------------");
          print("Firebase Messaging Token: $fcmToken");
          print("---------------------------------");
        }
        await _saveTokenToSupabase(fcmToken);
      }

      // 3. Escuchar cambios en el token
      _firebaseMessaging.onTokenRefresh.listen(_saveTokenToSupabase);

      // 4. Configurar el manejador de mensajes en segundo plano
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    } catch (e) {
      if (kDebugMode) {
        print("Error al inicializar notificaciones: $e");
      }
    }
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
        if (kDebugMode) {
          print("FCM Token guardado en Supabase exitosamente.");
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error al guardar el token en Supabase: $e");
        }
      }
    }
  }
}