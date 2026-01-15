// lib/screens/SplashScreen.dart
// ignore_for_file: file_names

import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:sasper/home_widget_callback_handler.dart' as hw;

// --- Configuración & Servicios ---
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/services/notification_service.dart';

// --- Rutas de Widgets ---

// --- Repositorios ---
import 'package:sasper/data/dashboard_repository.dart';

// --- Navegación ---
import 'package:sasper/screens/auth_gate.dart';

// ====================================================================
//                  GUARDAR PALETA MATERIAL YOU
// ====================================================================

Future<void> saveMaterialYouColors() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('m3_primary', palette.primary.get(100));
    await prefs.setInt('m3_surface', palette.neutral.get(100));
    await prefs.setInt('m3_onSurface', palette.neutralVariant.get(0));

    if (kDebugMode) {
      print("🎨 Colores Material You guardados.");
    }
  } catch (_) {}
}

// ====================================================================
//                  SPLASH SCREEN
// ====================================================================

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

  Future<void> _initializeAppAndNavigate() async {
    try {
      // ------------------------------------------------------------
      // 🔐 1. Guardar claves para el callback de widgets
      // ------------------------------------------------------------
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('supabase_url', AppConfig.supabaseUrl);
      await prefs.setString('supabase_api_key', AppConfig.supabaseAnonKey);

      developer.log("🔑 Claves Supabase guardadas.", name: "SplashInit");

      // ------------------------------------------------------------
      // ⚙️ 2. Inicializaciones críticas (en paralelo)
      // ------------------------------------------------------------
      await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        ),
        initializeDateFormatting('es_CO', null),
      ]);

      GlobalState.supabaseInitialized = true;

      // ------------------------------------------------------------
      // 📦 3. Inyectar dependencias
      // ------------------------------------------------------------
      final supabase = Supabase.instance.client;
      final messaging = FirebaseMessaging.instance;

      DashboardRepository.instance.initialize(supabase);

      NotificationService.instance.initializeDependencies(
        supabaseClient: supabase,
        firebaseMessaging: messaging,
      );

      // ------------------------------------------------------------
      // 🔄 4. Registrar callbacks de segundo plano
      // ------------------------------------------------------------
      HomeWidget.registerBackgroundCallback(hw.homeWidgetBackgroundCallback);
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      developer.log("🔄 Callbacks de widgets y FCM registrados.",
          name: "SplashInit");

      // ------------------------------------------------------------
      // 🌈 5. Navegación inmediata
      // ------------------------------------------------------------
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthGate()),
        );
      }

      // ------------------------------------------------------------
      // 🚀 6. Tareas en segundo plano
      // ------------------------------------------------------------
      unawaited(saveMaterialYouColors());
      unawaited(NotificationService.instance.initializeQuick());
    } catch (e, st) {
      debugPrint("🔥 ERROR CRÍTICO EN SPLASH: $e\n$st");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("No se pudo inicializar la app: $e"),
            backgroundColor: Colors.red,
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
            )
          ],
        ),
      ),
    );
  }
}
