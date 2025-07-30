// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sasper/data/analysis_repository.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/config/global_state.dart'; 
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:home_widget/home_widget.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/screens/auth_gate.dart';
import 'firebase_options.dart';

// La GlobalKey para el Navigator es una excelente práctica.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Requisito de Firebase: el handler de background debe ser una función de alto nivel.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Aseguramos que Firebase esté inicializado en este Isolate de fondo.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kDebugMode) {
    print("Handling a background message: ${message.messageId}");
  }
}

Future<void> main() async {
  // 1. Asegura que los bindings de Flutter estén listos.
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa la localización de fechas.
  await initializeDateFormatting('es_CO', null);
  
  // 3. Inicializa los servicios de backend principales.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );
  GlobalState.supabaseInitialized = true;
  // Registra la función que se ejecutará en segundo plano.
  HomeWidget.registerBackgroundCallback(backgroundCallback);
  // Asigna el handler de mensajes en segundo plano.
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // --- 4. INICIALIZACIÓN DE SINGLETONS (LA PARTE CLAVE) ---
  // Obtenemos el cliente de Supabase una sola vez, ahora que está garantizado que existe.
  final supabaseClient = Supabase.instance.client;

  // Inyectamos el cliente en cada uno de nuestros repositorios Singleton.
  // Esto asegura que todos estén listos para ser usados ANTES de que la UI los necesite.
  AccountRepository.instance.initialize(supabaseClient);
  //AnalysisRepository.instance.initialize(supabaseClient); // <-- AÑADIDO
  AuthRepository.instance.initialize(supabaseClient);     // <-- AÑADIDO
  BudgetRepository.instance.initialize(supabaseClient);
  DashboardRepository.instance.initialize(supabaseClient);
  DebtRepository.instance.initialize(supabaseClient);
  GoalRepository.instance.initialize(supabaseClient);
  RecurringRepository.instance.initialize(supabaseClient); // <-- AÑADIDO
  TransactionRepository.instance.initialize(supabaseClient);
  // Añade aquí cualquier otro repositorio que necesite el cliente.
  
  // 5. Ahora que todo está listo, corre la aplicación.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.blueAccent);
          darkColorScheme = ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark);
        }

        return MaterialApp(
          title: 'Finanzas Personales IA',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: lightColorScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
            useMaterial3: true,
          ),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''),
            Locale('en', ''),
          ],
          navigatorKey: navigatorKey, 
          home: const AuthGate(),
        );
      },
    );
  }
}