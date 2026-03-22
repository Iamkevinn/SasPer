// lib/main.dart
import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:sasper/screens/manifestations_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

// --- Archivos locales ---
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/theme/design_system.dart';
import 'package:sasper/services/theme_provider.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/home_widget_callback_handler.dart' as hw;

// --- Pantallas ---
import 'package:sasper/screens/auth_gate.dart';
import 'package:sasper/screens/add_transaction_screen.dart';
import 'package:sasper/screens/goals_screen.dart';

import 'package:workmanager/workmanager.dart';
import 'package:sasper/services/smart_notification_worker.dart';


// =================================================================
//                 CONFIGURACIÓN GLOBAL
// =================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // 1. Asegurar que los bindings de Flutter estén listos (Obligatorio)
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print("--- INICIANDO SASPER ---");
  }

  // 2. Tareas síncronas muy rápidas
  AppConfig.checkKeys();

  // 3. 🚀 CARGA PARALELA
  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    _initSupabaseSafe(),
    initializeDateFormatting('es_CO', null),
    _initTimezoneSafe(),
    _saveSupabaseKeysForBackground(),
  ]);

  GlobalState.supabaseInitialized = true;

  // 4. 📦 INYECCIÓN DE DEPENDENCIAS
  final supabase = Supabase.instance.client;
  final messaging = FirebaseMessaging.instance;

  DashboardRepository.instance.initialize(supabase);
  NotificationService.instance.initializeDependencies(
    supabaseClient: supabase,
    firebaseMessaging: messaging,
  );

  // 5. 🔄 REGISTRO DE SEGUNDO PLANO
  HomeWidget.registerBackgroundCallback(hw.homeWidgetBackgroundCallback);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 👈 NUEVO: INICIALIZACIÓN DE WORKMANAGER
  try {
    Workmanager().initialize(
      smartGoalDispatcher, // 2. USAMOS EL NUEVO NOMBRE AQUÍ
      isInDebugMode: true, // Ponlo en true para que nos avise en la consola
    );

    ////////////////////////////////////////////////////////////////////////////////////////////////////

    // Código de prueba: Forzar ejecución en 10 segundos
    Workmanager().registerOneOffTask(
      "prueba_rapida_2",
      smartGoalTask,
      initialDelay: const Duration(seconds: 10),
    );

    // Registramos la tarea para que corra cada 24h
    /*Workmanager().registerPeriodicTask(
      "1", // ID único de la tarea
      smartGoalTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected, // Solo si hay internet
        requiresBatteryNotLow: true, // No agotar la batería del usuario
      ),
    );*/
  } catch (e) {
    developer.log('🔥 Error iniciando Workmanager: $e', name: 'MainInit');
  }

  // 6. 👻 TAREAS FANTASMA
  unawaited(_saveMaterialYouColors());
  unawaited(NotificationService.instance.initializeQuick());

  // 7. 🎨 ¡DIBUJAR LA APP DIRECTAMENTE!
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}
// =================================================================
//                 FUNCIONES AUXILIARES DE INICIO
// =================================================================

Future<void> _initSupabaseSafe() async {
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  } catch (e) {
    if (!e.toString().contains('already been initialized')) {
      developer.log('🔥 Error al inicializar Supabase: $e', name: 'MainInit');
    }
  }
}

Future<void> _initTimezoneSafe() async {
  try {
    tz.initializeTimeZones();
    final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));
  } catch (e) {
    developer.log('🔥 Error al inicializar timezone: $e', name: 'MainInit');
  }
}

Future<void> _saveSupabaseKeysForBackground() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('supabase_url', AppConfig.supabaseUrl);
  await prefs.setString('supabase_api_key', AppConfig.supabaseAnonKey);
}

Future<void> _saveMaterialYouColors() async {
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('m3_primary', palette.primary.get(100));
    await prefs.setInt('m3_surface', palette.neutral.get(100));
    await prefs.setInt('m3_onSurface', palette.neutralVariant.get(0));
  } catch (_) {}
}

// =================================================================
//       WIDGET PRINCIPAL DE LA APP
// =================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final QuickActions quickActions = const QuickActions();

  @override
  void initState() {
    super.initState();
    _setupQuickActions();
    _handleQuickActions();
  }

  /// Define los accesos directos (Shortcuts de icono de app)
  void _setupQuickActions() {
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'add_transaction',
        localizedTitle: 'Nueva Transacción',
        icon: 'ic_shortcut_add_adaptive',
      ),
      const ShortcutItem(
        type: 'view_manifestations',
        localizedTitle: 'Mis Manifestaciones',
        icon: 'ic_shortcut_manifestation_adaptive',
      ),
    ]);
  }

  /// Maneja los clics en los Shortcuts
  void _handleQuickActions() {
    quickActions.initialize((String shortcutType) {
      switch (shortcutType) {
        case 'add_transaction':
          navigatorKey.currentState?.pushNamed('/add_transaction');
          break;
        case 'view_manifestations':
          navigatorKey.currentState?.pushNamed('/manifestations');
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.blueAccent);
          darkColorScheme = ColorScheme.fromSeed(
              seedColor: Colors.blueAccent, brightness: Brightness.dark);
        }

        return MaterialApp(
          themeMode: themeProvider.themeMode,
          title: 'Finanzas Personales IA',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(lightColorScheme),
          darkTheme: buildDarkTheme(darkColorScheme),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''),
            Locale('en', ''),
          ],
          navigatorKey: navigatorKey,
          // 🔥 MAGIA AQUÍ: Entramos directamente al AuthGate sin pasar por un Splash falso
          home: const AuthGate(),
          routes: {
            '/add_transaction': (context) => const AddTransactionScreen(),
            '/goals': (context) => const GoalsScreen(),
            '/manifestations': (context) => const ManifestationsScreen(),
          },
        );
      },
    );
  }
}
