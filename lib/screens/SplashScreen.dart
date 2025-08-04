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

// --- Repositorios (TODOS se inicializan aquí) ---
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

// Función auxiliar para guardar colores de Material You
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
      // Ejecutamos las tareas de red/disco indispensables al mismo tiempo para minimizar la espera.
      await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        Supabase.initialize(
          url: AppConfig.supabaseUrl,
          anonKey: AppConfig.supabaseAnonKey,
        ),
        initializeDateFormatting('es_CO', null),
      ]);

      // --- ETAPA 2: INYECCIÓN DE DEPENDENCIAS (Síncrono y Rápido) ---
      // Una vez que lo crítico está listo, obtenemos las instancias.
      final supabaseClient = Supabase.instance.client;
      final firebaseMessaging = FirebaseMessaging.instance;
      
      // Inyección de dependencias para TODOS los repositorios. Esto es muy rápido.
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
      
      NotificationService.instance.initializeDependencies(
        supabaseClient: supabaseClient,
        firebaseMessaging: firebaseMessaging,
      );

      // --- ETAPA 3: REGISTRO DE CALLBACKS DE SEGUNDO PLANO ---
      GlobalState.supabaseInitialized = true;
      HomeWidget.registerBackgroundCallback(backgroundCallback);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // --- ETAPA 4: NAVEGACIÓN INMEDIATA ---
      // La app se siente rápida porque navegamos tan pronto como sea posible.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
      
      // --- ETAPA 5: TAREAS SECUNDARIAS (NO BLOQUEANTES) ---
      // Estas tareas se ejecutan en segundo plano después de que la navegación ha comenzado.
      // No usamos `await` para no bloquear el hilo principal.
      saveMaterialYouColors();
      NotificationService.instance.initialize();
      NotificationService.instance.refreshAllSchedules();

    } catch (e, stackTrace) {
      debugPrint("🔥🔥🔥 ERROR CRÍTICO DURANTE LA INICIALIZACIÓN: $e\n$stackTrace");
      if (mounted) {
        // En caso de un error fatal, es mejor informar al usuario.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al inicializar la app: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Un Splash Screen simple y limpio. El `const` ayuda al rendimiento.
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

// --- FUNCIONES DE ALTO NIVEL (CALLBACKS) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Asegurarse de que Firebase esté inicializado para manejar el mensaje.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}