// lib/screens/auth_gate.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Screens
import 'loading_screen.dart';
import 'login_screen.dart';
import 'biometric_gate.dart';

// Services
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:sasper/services/global_insight_service.dart';

/// 🔐 Widget "guardián" que gestiona el estado de autenticación
/// y la inicialización de servicios del usuario
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSubscription;

  // Timeouts para prevenir bloqueos
  static const Duration _servicesTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupWidgetInteractionListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Actualizar widget cuando la app vuelve al frente
    if (state == AppLifecycleState.resumed) {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        // 🔥 OPTIMIZACIÓN: unawaited para que no bloquee el hilo principal al reanudar
        unawaited(_refreshWidgetData());
      }
    }
  }

  /// 🎯 Configura el listener para clics en el widget de manifestaciones
  void _setupWidgetInteractionListener() {
    _widgetClickSubscription = HomeWidget.widgetClicked.listen((uri) {
      if (uri == null) return;
      developer.log(
        '🔔 Clic en widget detectado: ${uri.toString()}',
        name: 'AuthGate',
      );
      _handleWidgetClick(uri);
    });
  }

  /// 📱 Maneja las interacciones desde el widget
  void _handleWidgetClick(Uri uri) {
    final action = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';

    switch (uri.host) {
      case 'manifestation_widget':
      case 'simple_manifestation_widget': // Unificados porque hacen lo mismo
        switch (action) {
          case 'open_app':
            developer.log('📱 Usuario abrió app desde widget de manifestación', name: 'AuthGate');
            break;
          case 'visualize':
            _showVisualizationFeedback();
            break;
        }
        break;

      case 'affirmation_widget':
        switch (action) {
          case 'open_app':
            developer.log('📱 Usuario abrió app desde widget de afirmación', name: 'AuthGate');
            break;
          case 'focus':
            _showFocusFeedback();
            break;
        }
        break;
    }
  }

  /// ✨ Muestra feedback visual cuando el usuario hace "focus"
  void _showFocusFeedback() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.psychology, color: Colors.lightBlueAccent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Momento de enfoque registrado!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.indigo.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 🧠 Inicializa el escucha global de insights de IA
  void _initializeGlobalInsights() {
    GlobalInsightService.instance.startListening(); 
    developer.log('✅ GlobalInsightService iniciado', name: 'AuthGate');
  }

  /// 🔄 Refresca los datos del widget
  Future<void> _refreshWidgetData() async {
    try {
      await Future.wait([
        widget_service.WidgetService.updateFinancialHealthWidget(),
        widget_service.WidgetService.updateMonthlyComparisonWidget(),
        widget_service.WidgetService.updateGoalsWidget(),
        widget_service.WidgetService.updateUpcomingPaymentsWidget(),
        widget_service.WidgetService.updateNextPaymentWidget(),
      ]).timeout(
        _servicesTimeout,
        onTimeout: () {
          developer.log('⚠️ Timeout al refrescar widget', name: 'AuthGate');
          throw TimeoutException('El refrescado de los widgets tardó demasiado.');
        },
      );
      developer.log('✅ Widgets refrescados', name: 'AuthGate');
    } catch (e) {
      developer.log('⚠️ Error al refrescar widget: $e', name: 'AuthGate');
    }
  }

  /// ✨ Muestra feedback visual cuando el usuario "manifiesta"
  void _showVisualizationFeedback() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '✨ ¡Manifestación visualizada!',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          // 🔥 OPTIMIZACIÓN PRINCIPAL: 
          // En lugar de usar un FutureBuilder que frena la UI, lanzamos los 
          // servicios en segundo plano y pasamos inmediatamente a la app.
          unawaited(_initializeUserServicesInBackground(session.user.id));
          
          return const BiometricGate(); // Entra instantáneamente
        } else {
          return const LoginScreen();
        }
      },
    );
  }

  /// 🚀 Inicializa todos los servicios que dependen del usuario autenticado
  /// NOTA: Esta función ahora corre en "segundo plano" sin bloquear la UI
  Future<void> _initializeUserServicesInBackground(String userId) async {
    if (kDebugMode) {
      developer.log("✅ Usuario autenticado ($userId). Cargando servicios en background...", name: 'AuthGate');
    }

    try {
      _initializeGlobalInsights();
      // Ejecutar inicializaciones de forma asíncrona sin frenar al usuario
      await Future.wait([
        _initializeNotifications(),
        _initializeFinancialWidgets(),
      ], eagerError: false);

      if (kDebugMode) {
        developer.log('✅ Todos los servicios background listos.', name: 'AuthGate');
      }
    } catch (e, stackTrace) {
      developer.log(
        "🚨 Error en servicios background: $e",
        name: 'AuthGate',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 🔥 Inicializar todos los widgets financieros
  Future<void> _initializeFinancialWidgets() async {
    try {
      await Future.wait([
        widget_service.WidgetService.updateFinancialHealthWidget(),
        widget_service.WidgetService.updateMonthlyComparisonWidget(),
        widget_service.WidgetService.updateGoalsWidget(),
        widget_service.WidgetService.updateUpcomingPaymentsWidget(),
        widget_service.WidgetService.updateNextPaymentWidget(),
      ]).timeout(
        _servicesTimeout,
      );
      developer.log('✅ Widgets financieros inicializados', name: 'AuthGate');
    } catch (e) {
      developer.log('⚠️ Error al inicializar widgets financieros: $e', name: 'AuthGate');
    }
  }

  /// 🔔 Inicializa el servicio de notificaciones
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.instance.initializeLate().timeout(_servicesTimeout);
      developer.log('✅ NotificationService inicializado', name: 'AuthGate');
    } catch (e) {
      developer.log('⚠️ Error en NotificationService: $e', name: 'AuthGate');
    }
  }
}