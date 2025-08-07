// lib/screens/SplashScreen.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Dependencias de Configuración y Servicios ---
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/screens/auth_gate.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/widget_service.dart';

// --- Repositorios CRÍTICOS (solo los que se inicializan tempranamente) ---
import 'package:sasper/data/dashboard_repository.dart';

// Función auxiliar para guardar colores de Material You.
Future<void> saveMaterialYouColors() async {
    try {
        final corePalette = await DynamicColorPlugin.getCorePalette();
        if (corePalette != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('m3_primary', corePalette.primary.get(100));
            await prefs.setInt('m3_surface', corePalette.neutral.get(100));
            await prefs.setInt('m3_onSurface', corePalette.neutralVariant.get(0));
            if (kDebugMode) {
              print("🎨 Colores de Material You guardados en SharedPreferences.");
            }
        }
    } catch(e) {
        debugPrint("⚠️ No se pudieron obtener los colores de Material You (probablemente no es Android 12+).");
    }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAppAndNavigate();
  }

  /// Orquesta la secuencia de inicialización optimizada de la aplicación.
  Future<void> _initializeAppAndNavigate() async {
    try {
      // --- ETAPA 1: INICIALIZACIONES CRÍTICAS EN PARALELO ---
      await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        ),
        initializeDateFormatting('es_CO', null),
      ]);

      // --- ETAPA 2: INYECCIÓN DE DEPENDENCIAS ESENCIALES ---
      final supabaseClient = Supabase.instance.client;
      final firebaseMessaging = FirebaseMessaging.instance;
      
      DashboardRepository.instance.initialize(supabaseClient);
      
      NotificationService.instance.initializeDependencies(
        supabaseClient: supabaseClient,
        firebaseMessaging: firebaseMessaging,
      );

      // --- ETAPA 3: REGISTRO DE CALLBACKS DE SEGUNDO PLANO ---
      GlobalState.supabaseInitialized = true;
      HomeWidget.registerBackgroundCallback(backgroundCallback);
      
      // [CAMBIO CLAVE] Se usa el nombre público de la función importada desde notification_service.dart
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // --- ETAPA 4: NAVEGACIÓN INMEDIATA ---
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
      
      // --- ETAPA 5: TAREAS SECUNDARIAS (NO BLOQUEANTES) ---
      saveMaterialYouColors();
      NotificationService.instance.initializeQuick();

    } catch (e, stackTrace) {
      debugPrint("🔥🔥🔥 ERROR CRÍTICO DURANTE LA INICIALIZACIÓN: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al inicializar la app: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Configurando tu espacio financiero...',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}