import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Definimos las credenciales como cadenas de texto constantes y simples.
const supabaseUrl = 'https://flyqlrujavwndmdqaldr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZseXFscnVqYXZ3bmRtZHFhbGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NDQyOTEsImV4cCI6MjA2NzIyMDI5MX0.gv47_mKVpXRETdHxDC2vGxuOlKK_bgjZz2zqpJMxDXs';

// --- NUEVO: Función de callback para el segundo plano ---
@pragma('vm:entry-point')
void backgroundCallback(Uri? uri) async {
}

Future<void> main() async {
  // Asegúrate de que los bindings de Flutter están inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Supabase con las constantes que acabamos de definir
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  // Inicializa Firebase usando las opciones de la plataforma actual
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );  

  await initializeDateFormatting('es_ES', null);
  await setupFirebaseMessaging();
  runApp(const MyApp());
}

Future<void> setupFirebaseMessaging() async {
  final fcm = FirebaseMessaging.instance;

  // 1. Solicitar permiso para recibir notificaciones (importante para iOS y Android 13+)
  await fcm.requestPermission();

  // 2. Obtener el token de FCM
  final token = await fcm.getToken();
  print('========================================================');
  print('FCM Token: $token');
  print('========================================================');
  
  // ¡Guarda este token! Lo necesitarás para enviar notificaciones de prueba.

  // 3. Escuchar mensajes mientras la app está en primer plano
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('¡Recibí un mensaje mientras estaba en primer plano!');
    print('Datos del mensaje: ${message.data}');

    if (message.notification != null) {
      print('El mensaje también contenía una notificación: ${message.notification}');
    }
  });
}

// Hacemos el cliente de Supabase accesible globalmente
final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Envolvemos MaterialApp con DynamicColorBuilder
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        
        // Creamos nuestro esquema de colores base
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          // Si el sistema provee colores dinámicos, los usamos
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          // Si no, usamos nuestro color base 'seed'
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
          home: const AuthGate(),
        );
      },
    );
  }
}