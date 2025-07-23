// lib/services/notification_service.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Asumimos que tienes un archivo de config para la URL base de tu API
import 'package:sasper/config/app_config.dart'; 
import 'package:sasper/firebase_options.dart';

// La función de background handler se mantiene igual.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  developer.log("Handling a background message: ${message.messageId}", name: 'BackgroundMessageHandler');
}

class NotificationService {
  final SupabaseClient _supabase;
  final FirebaseMessaging _firebaseMessaging;
  final http.Client _httpClient;

  // 1. Singleton para un acceso fácil y único en toda la app.
  static final NotificationService instance = NotificationService._internal();

  // 2. Constructor privado con inyección de dependencias para tests.
  NotificationService._internal({
    SupabaseClient? supabaseClient,
    FirebaseMessaging? firebaseMessaging,
    http.Client? httpClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        _firebaseMessaging = firebaseMessaging ?? FirebaseMessaging.instance,
        _httpClient = httpClient ?? http.Client();

  /// Método principal para configurar todo el sistema de notificaciones.
  /// Se debe llamar una vez al inicio de la app (ej. en main.dart).
  Future<void> initialize() async {
    developer.log('🚀 Initializing Notification Service...', name: 'NotificationService');
    try {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await _firebaseMessaging.requestPermission();

      await _updateAndSaveToken();

      _firebaseMessaging.onTokenRefresh.listen((token) {
        developer.log('🔄 FCM Token refreshed. Saving new token...', name: 'NotificationService');
        _saveTokenToSupabase(token);
      });

      _setupMessageListeners();

      developer.log('✅ Notification service initialized successfully.', name: 'NotificationService');
    } catch (e, stackTrace) {
      developer.log("🔥 Error initializing notification service: $e", name: 'NotificationService', stackTrace: stackTrace);
    }
  }

  /// Obtiene el token actual y lo guarda en Supabase.
  Future<void> _updateAndSaveToken() async {
    final String? fcmToken = await _firebaseMessaging.getToken();
    if (fcmToken != null) {
      developer.log("Firebase Messaging Token: $fcmToken", name: 'NotificationService');
      await _saveTokenToSupabase(fcmToken);
    } else {
      developer.log("⚠️ Could not get FCM token.", name: 'NotificationService');
    }
  }

  void _setupMessageListeners() {
    // Para manejar notificaciones cuando la app está en primer plano.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer.log('🔔 Message received in foreground!', name: 'NotificationService');
      if (message.notification != null) {
        developer.log('Notification: ${message.notification!.title} - ${message.notification!.body}', name: 'NotificationService');
        // Aquí podrías mostrar una notificación o un diálogo en la app.
      }
    });

    // Para manejar cuando el usuario toca la notificación y abre la app.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('📲 Notification tapped, app opened from background.', name: 'NotificationService');
      // Aquí puedes navegar a una pantalla específica basada en message.data
    });
  }

  Future<void> _saveTokenToSupabase(String token) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      try {
        await _supabase
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', userId);
        developer.log("✅ FCM Token saved/updated in Supabase.", name: 'NotificationService');
      } catch (e, stackTrace) {
        developer.log("🔥 Error saving token to Supabase: $e", name: 'NotificationService', stackTrace: stackTrace);
      }
    }
  }
  
  /// Dispara una notificación llamando a un endpoint en el backend de Render.
  /// Este es el método que otros servicios (como BudgetService) llamarán.
  Future<void> triggerBudgetNotification({
    required String userId,
    required String categoryName,
  }) async {
    developer.log('📲 Triggering budget check via Render backend for category "$categoryName"', name: 'NotificationService');
    
    // Asumimos que tienes este endpoint en tu backend de Python
    final url = Uri.parse('${AppConfig.renderBackendBaseUrl}/check-budget-on-transaction');

    try {
      final response = await _httpClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'category': categoryName,
        }),
      );

      if (response.statusCode == 200) {
        developer.log('✅ Budget check successfully triggered on backend.', name: 'NotificationService');
      } else {
        developer.log('🔥 Error from Render backend: ${response.statusCode} - ${response.body}', name: 'NotificationService');
      }
    } catch (e) {
      developer.log('🔥 Error calling Render backend for budget check: $e', name: 'NotificationService');
    }
  }
}