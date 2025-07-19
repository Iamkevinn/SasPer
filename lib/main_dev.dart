// lib/main_dev.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/screens/dashboard_screen.dart'; // Apunta a tu Dashboard
import 'package:sasper/data/dashboard_repository.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://flyqlrujavwndmdqaldr.supabase.co', // <-- Reemplaza con tu URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZseXFscnVqYXZ3bmRtZHFhbGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NDQyOTEsImV4cCI6MjA2NzIyMDI5MX0.gv47_mKVpXRETdHxDC2vGxuOlKK_bgjZz2zqpJMxDXs', // <-- Reemplaza con tu Anon Key
  );

  // Inicia sesión manualmente para la prueba
  // Reemplaza con un email y contraseña de un usuario de prueba VÁLIDO
  try {
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'kevinpedraza2003@gmail.com',
      password: 'hola',
    );
  } catch(e) {
    print("FALLO EL LOGIN MANUAL: $e");
    // Si esto falla, el problema es el login en sí. Detente aquí.
    return;
  }
  
  // Inicializaciones mínimas
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('es_CO', null);

  // Lanza una app que SOLO contiene el DashboardScreen
  runApp(const DevApp());
}

class DevApp extends StatelessWidget {
  const DevApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Creamos el repositorio aquí mismo para la prueba
    final dashboardRepository = DashboardRepository(Supabase.instance.client);
    
    return MaterialApp(
      home: Scaffold(
        body: DashboardScreen(repository: dashboardRepository),
      ),
    );
  }
}