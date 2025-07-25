// En main.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
// NO es necesario runZonedGuarded para la depuración, lo volveremos a poner si hace falta.

Future<void> main() async {
  // 1. Bindings primero, siempre.
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Localización, es ligero y seguro.
  await initializeDateFormatting('es_CO', null);
  
  // 3. Servicios de backend principales. Son seguros de inicializar aquí.
  await Supabase.initialize(
    url: 'https://flyqlrujavwndmdqaldr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZseXFscnVqYXZ3bmRtZHFhbGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NDQyOTEsImV4cCI6MjA2NzIyMDI5MX0.gv47_mKVpXRETdHxDC2vGxuOlKK_bgjZz2zqpJMxDXs',
  );
  await WidgetService.initialize();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );  
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // 4. Corre la aplicación.
  runApp(const MyApp());
}

// ELIMINA la función setupFirebaseMessaging() de aquí. La moveremos.

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
  
final supabase = Supabase.instance.client;

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
          // --- AÑADE ESTAS LÍNEAS PARA EL SOPORTE DE IDIOMA ---
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''), // Español
            Locale('en', ''), // Inglés (como fallback)
          ],
          home: const AuthGate(),
        );
      },
    );
  }
}