import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/config/global_state.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/data/budget_repository.dart';
import 'package:sasper/data/dashboard_repository.dart';
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/firebase_options.dart';
import 'package:sasper/screens/auth_gate.dart';
import 'package:sasper/services/widget_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Inicia el proceso de carga y navegación cuando la pantalla se construye
    _initializeAppAndNavigate();
  }

  Future<void> _initializeAppAndNavigate() async {
    try {
      // 1. Mueve toda tu lógica de inicialización pesada aquí
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        anonKey: AppConfig.supabaseAnonKey,
      );
      GlobalState.supabaseInitialized = true;
      HomeWidget.registerBackgroundCallback(backgroundCallback);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // 2. Inicialización de Singletons
      final supabaseClient = Supabase.instance.client;
      AccountRepository.instance.initialize(supabaseClient);
      AuthRepository.instance.initialize(supabaseClient);
      BudgetRepository.instance.initialize(supabaseClient);
      DashboardRepository.instance.initialize(supabaseClient);
      DebtRepository.instance.initialize(supabaseClient);
      GoalRepository.instance.initialize(supabaseClient);
      RecurringRepository.instance.initialize(supabaseClient);
      TransactionRepository.instance.initialize(supabaseClient);
      
      // 3. Pequeña pausa para que la transición sea más suave (opcional)
      await Future.delayed(const Duration(milliseconds: 500));

      // 4. Navega a la siguiente pantalla
      // Usamos `mounted` para asegurarnos de que el widget todavía existe antes de navegar
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthGate()),
        );
      }
    } catch (e) {
      // Manejar cualquier error de inicialización aquí
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al inicializar la app: $e')),
        );
      }
    }
  }

  // Esta es la UI que el usuario verá instantáneamente
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

// Requisito de Firebase: El handler debe ser una función de alto nivel, 
// así que lo mantenemos aquí o en main.dart para que SplashScreen lo vea.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}