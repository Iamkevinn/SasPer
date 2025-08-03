// lib/screens/SplashScreen.dart

// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
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
        // Guardamos los colores que nos interesan como enteros (ARGB)
        await prefs.setInt('m3_primary', corePalette.primary.get(100)); // Usamos el tono 100
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

  Future<void> _initializeAppAndNavigate() async {
    try {
      // 1. Inicialización de servicios base (Firebase y Supabase)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      
      final supabaseClient = Supabase.instance.client;

      // 2. Inicialización de TODOS los repositorios Singleton.
      // Este es el paso clave para evitar el LateInitializationError.
      AccountRepository.instance.initialize(supabaseClient);
      AuthRepository.instance.initialize(supabaseClient);
      BudgetRepository.instance.initialize(supabaseClient);
      DashboardRepository.instance.initialize(supabaseClient);
      DebtRepository.instance.initialize(supabaseClient);
      GoalRepository.instance.initialize(supabaseClient);
      RecurringRepository.instance.initialize(supabaseClient);
      TransactionRepository.instance.initialize(supabaseClient);
      CategoryRepository.instance.initialize(supabaseClient);

      // 3. Inicialización de los servicios que dependen de los repositorios.
      await NotificationService.instance.initialize();
      await NotificationService.instance.testImmediateNotification();

      // --------- AQUÍ agregamos el refresh de recordatorios ------------
      final allRecurring = await RecurringRepository.instance.getAll(); 
      // getAll debe devolver List<RecurringTransaction>
      await NotificationService.instance.refreshAllSchedules(allRecurring);
      
      WidgetService.listenToDashboardChanges(); // ¡Ahora esta llamada es segura!
      // 3a. Guardamos los colores de Material You para que los widgets los usen.
      await saveMaterialYouColors();

      // 3b. Lanzamos la primera actualización para el widget de "Próximos Pagos".
      // Lo hacemos sin 'await' para no bloquear la navegación, se ejecutará en segundo plano.
      if (kDebugMode) {
        print("🚀 SplashScreen: Solicitando actualización inicial del widget de próximos pagos.");
      }
      WidgetService().updateUpcomingPaymentsWidget();


      // 4. Configuración de callbacks en segundo plano.
      GlobalState.supabaseInitialized = true;
      HomeWidget.registerBackgroundCallback(backgroundCallback);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 5. Pequeña pausa para una transición suave (opcional).
      await Future.delayed(const Duration(milliseconds: 500));

      // 6. Navegación a la siguiente pantalla.
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint("🔥🔥🔥 ERROR DURANTE LA INICIALIZACIÓN: $e\n$stackTrace");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la app: $e')),
        );
        // Opcional: Navegar a una pantalla de error.
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