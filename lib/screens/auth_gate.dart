// lib/screens/auth_gate.dart
import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:sasper/services/affirmation_widget_service.dart';
import 'package:sasper/services/simple_manifestation_widget_service.dart'; // 🔥 AGREGADO
import 'package:supabase_flutter/supabase_flutter.dart';
// Screens
import 'loading_screen.dart';
import 'login_screen.dart';
import 'biometric_gate.dart';
// Services
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/manifestation_widget_service.dart';
import 'package:sasper/services/widget_service.dart' as widget_service; // 🔥 AÑADIDO

/// 🔐 Widget "guardián" que gestiona el estado de autenticación
/// y la inicialización de servicios del usuario
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  Future<void>? _initializationFuture;
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
        _refreshWidgetData();
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

    // Usamos un switch en el host para manejar diferentes widgets
    switch (uri.host) {
      case 'manifestation_widget':
        switch (action) {
          case 'open_app':
            developer.log('📱 Usuario abrió app desde widget de manifestación',
                name: 'AuthGate');
            break;
          case 'visualize':
            _showVisualizationFeedback();
            break;
        }
        break;

      case 'affirmation_widget':
        switch (action) {
          case 'open_app':
            developer.log('📱 Usuario abrió app desde widget de afirmación',
                name: 'AuthGate');
            break;
          case 'focus':
            _showFocusFeedback();
            break;
        }
        break;

      case 'simple_manifestation_widget':
        switch (action) {
          case 'open_app':
            developer.log('📱 Usuario abrió app desde widget simple de manifestación',
                name: 'AuthGate');
            break;
          case 'visualize':
            _showVisualizationFeedback();
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
        content: Row(
          children: const [
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

  /// 🔄 Refresca los datos del widget
  Future<void> _refreshWidgetData() async {
    try {
      await Future.wait([
        //ManifestationWidgetService.initializeWidget(),
        //AffirmationWidgetService.initializeWidget(),
        //SimpleManifestationWidgetService.initializeWidget(), // 🔥 AGREGADO
        // 🔥 AÑADIDO: Refrescar widgets financieros
        widget_service.WidgetService.updateFinancialHealthWidget(),
        widget_service.WidgetService.updateMonthlyComparisonWidget(),
        widget_service.WidgetService.updateGoalsWidget(),
        widget_service.WidgetService.updateUpcomingPaymentsWidget(),
        widget_service.WidgetService.updateNextPaymentWidget(),
      ]).timeout(
        _servicesTimeout,
        onTimeout: () {
          developer.log('⚠️ Timeout al refrescar widget', name: 'AuthGate');
          throw TimeoutException(
              'El refrescado de los widgets tardó demasiado.');
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
        content: Row(
          children: const [
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
          // Usuario autenticado: inicializar servicios una sola vez
          final initializationFuture =
              _initializeUserServices(session.user.id);
          return FutureBuilder<void>(
            future: initializationFuture,
            builder: (context, futureSnapshot) {
              if (futureSnapshot.connectionState == ConnectionState.done) {
                if (futureSnapshot.hasError) {
                  developer.log(
                    '⚠️ Error en inicialización: ${futureSnapshot.error}',
                    name: 'AuthGate',
                  );
                }
                return const BiometricGate();
              } else {
                return const LoadingScreen();
              }
            },
          );
        } else {
          // Usuario no autenticado: resetear estado
          _initializationFuture = null;
          return const LoginScreen();
        }
      },
    );
  }

  /// 🚀 Inicializa todos los servicios que dependen del usuario autenticado
  Future<void> _initializeUserServices(String userId) async {
    if (kDebugMode) {
      developer.log(
        "✅ Usuario autenticado ($userId). Inicializando servicios...",
        name: 'AuthGate',
      );
    }

    try {
      // Ejecutar inicializaciones en paralelo para mayor velocidad
      await Future.wait([
        _initializeNotifications(),
        //_initializeManifestationWidget(),
        //_initializeAffirmationWidget(),
        //_initializeSimpleManifestationWidget(), // 🔥 AGREGADO
        _initializeFinancialWidgets(),
      ], eagerError: false); // Continuar aunque alguno falle


      if (kDebugMode) {
        developer.log(
          '✅ Todos los servicios inicializados exitosamente.',
          name: 'AuthGate',
        );
      }
    } catch (e, stackTrace) {
      developer.log(
        "🚨 Error durante inicialización de servicios: $e",
        name: 'AuthGate',
        error: e,
        stackTrace: stackTrace,
      );
      // No hacer rethrow para permitir que la app continúe
    }
  }

  /// 🔄 Inicializa widgets específicos por widgetId
  
  // 🔥 NUEVA FUNCIÓN: Inicializar todos los widgets financieros
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
        onTimeout: () {
          developer.log(
            '⚠️ Timeout al inicializar widgets financieros',
            name: 'AuthGate',
          );
          throw TimeoutException('Financial widgets timeout');
        },
      );
      developer.log(
        '✅ Widgets financieros inicializados',
        name: 'AuthGate',
      );
    } catch (e, stackTrace) {
      developer.log(
        '⚠️ Error al inicializar widgets financieros: $e',
        name: 'AuthGate',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initializeAffirmationWidget() async {
    try {
      await AffirmationWidgetService.initializeWidget().timeout(
        _servicesTimeout,
        onTimeout: () {
          developer.log(
            '⚠️ Timeout al inicializar widget de afirmaciones',
            name: 'AuthGate',
          );
          throw TimeoutException('Affirmation widget timeout');
        },
      );
      developer.log(
        '✅ Widget de afirmaciones inicializado',
        name: 'AuthGate',
      );
    } catch (e, stackTrace) {
      developer.log(
        '⚠️ Error al inicializar widget de afirmaciones: $e',
        name: 'AuthGate',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 🔔 Inicializa el servicio de notificaciones
  Future<void> _initializeNotifications() async {
    try {
      await NotificationService.instance.initializeLate().timeout(
        _servicesTimeout,
        onTimeout: () {
          developer.log('⚠️ Timeout en NotificationService', name: 'AuthGate');
        },
      );
      developer.log('✅ NotificationService inicializado', name: 'AuthGate');
    } catch (e) {
      developer.log(
        '⚠️ Error en NotificationService: $e',
        name: 'AuthGate',
      );
    }
  }

  /// 🌟 Inicializa el widget de manifestaciones
  Future<void> _initializeManifestationWidget() async {
    try {
      await ManifestationWidgetService.initializeWidget().timeout(
        _servicesTimeout,
        onTimeout: () {
          developer.log(
            '⚠️ Timeout al inicializar widget de manifestaciones',
            name: 'AuthGate',
          );
          throw TimeoutException('Widget initialization timeout');
        },
      );
      developer.log(
        '✅ Widget de manifestaciones inicializado',
        name: 'AuthGate',
      );
    } catch (e, stackTrace) {
      developer.log(
        '⚠️ Error al inicializar widget: $e',
        name: 'AuthGate',
        error: e,
        stackTrace: stackTrace,
      );
      // Intentar establecer un estado por defecto
      try {
        await _setDefaultWidgetState();
      } catch (defaultError) {
        developer.log(
          '⚠️ Error al establecer estado por defecto: $defaultError',
          name: 'AuthGate',
        );
      }
    }
  }

  /// 🌟 Inicializa el widget simple de manifestaciones
  Future<void> _initializeSimpleManifestationWidget() async {
    try {
      await SimpleManifestationWidgetService.initializeWidget().timeout(
        _servicesTimeout,
        onTimeout: () {
          developer.log(
            '⚠️ Timeout al inicializar widget simple de manifestaciones',
            name: 'AuthGate',
          );
          throw TimeoutException('Simple Manifestation widget timeout');
        },
      );
      developer.log(
        '✅ Widget simple de manifestaciones inicializado',
        name: 'AuthGate',
      );
    } catch (e, stackTrace) {
      developer.log(
        '⚠️ Error al inicializar widget simple: $e',
        name: 'AuthGate',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 📝 Establece un estado por defecto para el widget
  Future<void> _setDefaultWidgetState() async {
    await HomeWidget.saveWidgetData<String>(
      'vision_current_title',
      'Comienza a Manifestar',
    );
    await HomeWidget.saveWidgetData<String>(
      'vision_current_description',
      'Crea tu primera manifestación en la app',
    );
    await HomeWidget.saveWidgetData<String>('vision_current_image_url', '');
    await HomeWidget.saveWidgetData<int>(
        'vision_current_manifestation_index', 0);
    await HomeWidget.saveWidgetData<int>('vision_manifestations_total_count', 0);
    await HomeWidget.updateWidget(
      androidName: 'ManifestationVisionWidget',
      iOSName: 'ManifestationVisionWidget',
    );
    developer.log(
      'ℹ️ Widget configurado con estado por defecto',
      name: 'AuthGate',
    );
  }
}