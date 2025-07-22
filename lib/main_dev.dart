// lib/main_dev.dart (CORREGIDO Y COMPLETO)

import 'package:flutter/material.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/screens/dashboard_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Tu inicialización de Supabase y Firebase está perfecta.
  await Supabase.initialize(
    url: 'https://flyqlrujavwndmdqaldr.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZseXFscnVqYXZ3bmRtZHFhbGRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2NDQyOTEsImV4cCI6MjA2NzIyMDI5MX0.gv47_mKVpXRETdHxDC2vGxuOlKK_bgjZz2zqpJMxDXs',
  );

  try {
    await Supabase.instance.client.auth.signInWithPassword(
      email: 'kevinpedraza2003@gmail.com',
      password: 'hola',
    );
  } catch(e) {
    print("FALLO EL LOGIN MANUAL: $e");
    return;
  }
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('es_CO', null);

  runApp(const DevApp());
}

class DevApp extends StatelessWidget {
  const DevApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. AÑADIDO: Creamos instancias de TODOS los repositorios necesarios.
    final dashboardRepository = DashboardRepository(Supabase.instance.client);
    final accountRepository = AccountRepository();
    final transactionRepository = TransactionRepository();
    
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Útil para limpiar la UI de desarrollo
      home: Scaffold(
        // 2. CORREGIDO: Pasamos todos los repositorios requeridos a DashboardScreen.
        body: DashboardScreen(
          repository: dashboardRepository,
          accountRepository: accountRepository,
          transactionRepository: transactionRepository, budgetRepository: BudgetRepository(),
        ),
      ),
    );
  }
}