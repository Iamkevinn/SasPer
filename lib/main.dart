// lib/main.dart
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:sasper/screens/manifestations_screen.dart';
import 'package:sasper/services/woop_event_bus.dart';
import 'package:sasper/widgets/shared/woop_listener_widget.dart';
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
import 'package:sasper/services/woop_constants.dart';
import 'package:sasper/home_widget_callback_handler.dart' as hw;

// --- Pantallas ---
import 'package:sasper/screens/auth_gate.dart';
import 'package:sasper/screens/add_transaction_screen.dart';
import 'package:sasper/screens/goals_screen.dart';
import 'package:sasper/screens/account_details_screen.dart';
import 'package:sasper/screens/budget_details_screen.dart';

import 'package:workmanager/workmanager.dart';
import 'package:sasper/services/smart_notification_worker.dart';
import 'package:sasper/services/woop_notification_worker.dart';
import 'package:sasper/services/budget_notification_intelligence.dart';
import 'package:sasper/services/credit_card_notification_intelligence.dart';

// =================================================================
//                 CONFIGURACIÓN GLOBAL
// =================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Dispatcher combinado para Workmanager
@pragma('vm:entry-point')
void _combinedDispatcher() {
  Workmanager().executeTask(_combinedTaskHandler);
}

/// Manejador de tareas combinado
@pragma('vm:entry-point')
Future<bool> _combinedTaskHandler(String task, Map<String, dynamic>? inputData) async {
  if (task == smartGoalTask) {
    developer.log('🧠[SmartWorker] DISPATCHER INICIADO — Tarea: $task', name: 'SmartWorker');

    try {
      tz.initializeTimeZones();
      final TimezoneInfo tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('America/Bogota'));
    }

    final localNotifier = FlutterLocalNotificationsPlugin();
    await localNotifier.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings()));
    await initializeDateFormatting('es_CO', null);

    final androidPlugin = localNotifier.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'credit_card_assistant_channel', 'Asistente de tarjetas',
        description: 'Alertas inteligentes sobre corte y pago de tus tarjetas.',
        importance: Importance.max,
      ));
      await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
        'smart_budget_channel', 'Presupuesto inteligente',
        description: 'Alertas sobre tu ritmo de gasto frente al avance del período.',
        importance: Importance.high,
      ));
    }

    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('supabase_url');
    final anonKey = prefs.getString('supabase_api_key');
    final userId = prefs.getString('user_id');

    if (url == null || anonKey == null || userId == null) return true;

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } catch (e) {
      if (!e.toString().contains('already been initialized')) return false;
    }

    final client = Supabase.instance.client;

    try {
      await runGoalIntelligence(client, localNotifier, userId, prefs);
      await runCreditCardIntelligence(client, localNotifier, userId, prefs);
      await runBudgetIntelligence(client, localNotifier, userId, prefs);
      await runEndOfMonthIntelligence(client, localNotifier, userId, prefs);
      await client.rpc('auto_renew_budgets', params: {'p_user_id': userId});
      developer.log('✅ [SmartWorker] Tarea completada.', name: 'SmartWorker');
      return true;
    } catch (e, stack) {
      developer.log('🔥 [SmartWorker] FALLO INESPERADO: $e', name: 'SmartWorker', stackTrace: stack);
      return false;
    }
  } else if (task == woopNotificationTask) {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('supabase_url');
    final anonKey = prefs.getString('supabase_api_key');
    final userId = prefs.getString('user_id');

    if (url == null || anonKey == null || userId == null) return true;

    try {
      await Supabase.initialize(url: url, anonKey: anonKey);
    } catch (e) {
      if (!e.toString().contains('already been initialized')) return false;
    }

    final client = Supabase.instance.client;

    return await WOOPNotificationService.executeTriggerEvaluation(
      client: client,
      userId: userId,
    );
  }
  return false;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kDebugMode) {
    print("--- INICIANDO SASPER ---");
  }

  AppConfig.checkKeys();

  await Future.wait([
    Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
    _initSupabaseSafe(),
    initializeDateFormatting('es_CO', null),
    _initTimezoneSafe(),
    _saveSupabaseKeysForBackground(),
  ]);

  GlobalState.supabaseInitialized = true;

  final supabase = Supabase.instance.client;
  final messaging = FirebaseMessaging.instance;

  DashboardRepository.instance.initialize(supabase);
  NotificationService.instance.initializeDependencies(
    supabaseClient: supabase,
    firebaseMessaging: messaging,
  );

  supabase.auth.onAuthStateChange.listen((data) async {
    final prefs = await SharedPreferences.getInstance();
    final session = data.session;
    if (session != null) {
      await prefs.setString('user_id', session.user.id);
      developer.log('🔑 user_id guardado en SharedPreferences para el Worker', name: 'Auth');
    } else {
      await prefs.remove('user_id');
    }
  });
  
  HomeWidget.registerBackgroundCallback(hw.homeWidgetBackgroundCallback);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  try {
    Workmanager().initialize(
      _combinedDispatcher,
      isInDebugMode: true,
    );

    Workmanager().registerPeriodicTask(
      "smart_goal_daily_check",
      smartGoalTask,
      frequency: const Duration(hours: 24),
      initialDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
    );

    Workmanager().registerPeriodicTask(
      "woop_notification_check",
      woopNotificationTask,
      frequency: const Duration(hours: 1),
      initialDelay: const Duration(minutes: 5),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
    );
  } catch (e) {
    developer.log('🔥 Error iniciando Workmanager: $e', name: 'MainInit');
  }

  unawaited(_saveMaterialYouColors());
  unawaited(NotificationService.instance.initializeQuick());

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
    _checkTerminatedNotification(); // 🔥 NUEVO: Atrapa el clic si la app estaba muerta
  }

// En lib/main.dart (Solo cambia la función _checkTerminatedNotification)

void _checkTerminatedNotification() async {
  // Damos un segundo para que la UI se monte
  await Future.delayed(const Duration(seconds: 1));
 
  final localNotifier = FlutterLocalNotificationsPlugin();
  final details = await localNotifier.getNotificationAppLaunchDetails();
 
  if (details == null ||
      !details.didNotificationLaunchApp ||
      details.notificationResponse == null) return;
 
  developer.log('🚀 [main] Cold-start detectado desde notificación', name: 'WOOP');

  globalHandleNotificationTap(details.notificationResponse!);
 
}
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
          lightColorScheme = ColorScheme.fromSeed(seedColor: AppTheme.accent);
          darkColorScheme = ColorScheme.fromSeed(
              seedColor: AppTheme.accent, brightness: Brightness.dark);
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
          // 👇 AÑADIDO: El builder envuelve TODA la navegación de la app
          builder: (context, child) {
            return WoopListenerWidget(child: child!);
          },
          home: const AuthGate(), // 👇 MODIFICADO: Ya no está envuelto aquí
          routes: {
            '/add_transaction': (context) => const AddTransactionScreen(),
            '/goals': (context) => const GoalsScreen(),
            '/manifestations': (context) => const ManifestationsScreen(),
            '/account_details': (context) {
              final id = ModalRoute.of(context)?.settings.arguments;
              final accountId = id is String ? id : '';
              return AccountDetailsScreen(accountId: accountId);
            },
            '/budget_details': (context) {
              final id = ModalRoute.of(context)?.settings.arguments;
              final budgetId = id is int
                  ? id
                  : (id is num ? id.toInt() : int.tryParse('$id') ?? 0);
              return BudgetDetailsScreen(budgetId: budgetId);
            },
          },
        );
      },
    );
  }
}