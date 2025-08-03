// lib/screens/SplashScreen.dart

// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Dependencias de Configuración ---
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/firebase_options.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Pantallas y Servicios ---
import 'package:sasper/screens/auth_gate.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/widget_service.dart';

// --- Repositorios ---
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/data/transaction_repository.dart';

Future<void> saveMaterialYouColors() async {
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

  /// Orquesta la secuencia de inicialización completa de la aplicación.
  Future<void> _initializeAppAndNavigate() async {
    try {
      // --- TAREAS ESENCIALES Y ULTRARRÁPIDAS ---
      
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      
      final supabaseClient = Supabase.instance.client;
      final firebaseMessaging = FirebaseMessaging.instance;

      // --- ¡CORRECCIÓN CLAVE! ---
      // Inicialización de TODOS los repositorios Singleton.
      AccountRepository.instance.initialize(supabaseClient);
      AnalysisRepository.instance.initialize(supabaseClient);
      AuthRepository.instance.initialize(supabaseClient);
      BudgetRepository.instance.initialize(supabaseClient);
      CategoryRepository.instance.initialize(supabaseClient);
      DashboardRepository.instance.initialize(supabaseClient);
      DebtRepository.instance.initialize(supabaseClient);
      GoalRepository.instance.initialize(supabaseClient);
      RecurringRepository.instance.initialize(supabaseClient);
      TransactionRepository.instance.initialize(supabaseClient);

      // Inicialización de dependencias de servicios.
      NotificationService.instance.initializeDependencies(
        supabaseClient: supabaseClient,
        firebaseMessaging: firebaseMessaging,
      );
      
      // Configuración de callbacks en segundo plano.
      GlobalState.supabaseInitialized = true;
      HomeWidget.registerBackgroundCallback(backgroundCallback);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // --- NAVEGACIÓN INMEDIATA ---
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
      
      // --- TAREAS SECUNDARIAS (SE EJECUTAN DESPUÉS DE NAVEGAR) ---
      
      // Tareas rápidas que pueden ir en paralelo.
      Future.wait([
        initializeDateFormatting('es_CO', null),
        saveMaterialYouColors(),
        NotificationService.instance.initialize(), // Inicialización rápida de notificaciones
      ]);

      // Tareas pesadas que se ejecutan sin await para no bloquear.
      await Future.delayed(const Duration(milliseconds: 500));
      
      NotificationService.instance.refreshAllSchedules();
      WidgetService().updateUpcomingPaymentsWidget();

    } catch (e, stackTrace) {
      debugPrint("🔥🔥🔥 ERROR DURANTE LA INICIALIZACIÓN: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la app: $e')),
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

// Los callbacks deben ser funciones de alto nivel (fuera de cualquier clase).
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}