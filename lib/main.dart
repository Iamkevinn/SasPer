import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sasper/config/app_config.dart';
import 'package:sasper/screens/SplashScreen.dart';
import 'package:provider/provider.dart';
import 'package:sasper/services/theme_provider.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:sasper/screens/add_transaction_screen.dart';
import 'dart:async';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_quill/flutter_quill.dart';

// 🌟 NUEVO: Import para el widget de manifestaciones

// =================================================================
//                 CONFIGURACIÓN GLOBAL
// =================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  if (kDebugMode) {
    print("--- CÓDIGOS PARA ICONOS DE GASTOS ---");
    print(
        'El código para "Comida" (utensils) es: ${LineAwesomeIcons.utensils_solid.codePoint}');
    print(
        'El código para "Transporte" (bus) es: ${LineAwesomeIcons.bus_alt_solid.codePoint}');
  }

  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO', null);
  AppConfig.checkKeys();

  try {
    tz.initializeTimeZones();
    final TimezoneInfo timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
    developer.log('✅ Timezone inicializado globalmente: $timeZoneName',
        name: 'Main');
  } catch (e) {
    developer.log('🔥 Error al inicializar timezone: $e', name: 'Main');
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
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
  //final _appLinks = AppLinks();
  //StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _setupQuickActions();
    _handleQuickActions();
    //_initDeepLinks();
  }

  @override
  void dispose() {
    //_linkSubscription?.cancel();
    super.dispose();
  }

  /// Inicializa el manejo de deep links (clics desde widgets y otros)
  //Future<void> _initDeepLinks() async {
  //  _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
  //    if (mounted) {
  //      _navigateToRouteFromUri(uri);
  //    }
  //  }, onError: (err) {
  //    if (mounted && kDebugMode) {
  //      print('Error escuchando los links: $err');
  //    }
  //  });
  //}

  /// Navega a la pantalla correcta basándose en el URI del deep link
  //void _navigateToRouteFromUri(Uri uri) {
  //  if (kDebugMode) {
  //    print('🔗 Link recibido: $uri');
  //  }
//
  //  // Deep link para agregar transacción
  //  if (uri.scheme == 'sasper' &&
  //      uri.host == 'sasper' &&
  //      uri.path == '/add_transaction') {
  //    navigatorKey.currentState?.pushNamed('/add_transaction');
  //    return;
  //  }
//
  //  // 🌟 NUEVO: Deep link para interacciones del widget de manifestaciones
  //  if (uri.scheme == 'sasper' && uri.host == 'manifestation') {
  //    _handleManifestationWidgetAction(uri);
  //    return;
  //  }
  //}

  /// 🌟 NUEVO: Maneja las acciones del widget de manifestaciones
  //void _handleManifestationWidgetAction(Uri uri) {
  //  final action = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
//
  //  if (kDebugMode) {
  //    print('🌟 Acción de widget de manifestación: $action');
  //  }
//
  //  switch (action) {
  //    case 'open_app':
  //      // El usuario abrió la app desde el widget
  //      // Podrías navegar directamente a la pantalla de manifestaciones
  //      navigatorKey.currentState?.pushNamed('/manifestations');
  //      break;
//
  //    case 'next':
  //    case 'previous':
  //    case 'visualize':
  //      // Estas acciones se manejan en el background callback
  //      // pero si la app está abierta, mostramos feedback
  //      if (action == 'visualize') {
  //        _showVisualizationFeedback();
  //      }
  //      break;
//
  //    default:
  //      if (kDebugMode) {
  //        print('❓ Acción desconocida: $action');
  //      }
  //  }
  //}

  /// 🌟 NUEVO: Muestra feedback cuando el usuario "manifiesta"
  //void _showVisualizationFeedback() {
  //  final context = navigatorKey.currentContext;
  //  if (context == null) return;
//
  //  ScaffoldMessenger.of(context).showSnackBar(
  //    SnackBar(
  //      content: Row(
  //        children: const [
  //          Icon(Icons.auto_awesome, color: Colors.amber),
  //          SizedBox(width: 12),
  //          Expanded(
  //            child: Text(
  //              '✨ ¡Manifestación visualizada!',
  //              style: TextStyle(fontWeight: FontWeight.w600),
  //            ),
  //          ),
  //        ],
  //      ),
  //      backgroundColor: Colors.deepPurple.shade700,
  //      behavior: SnackBarBehavior.floating,
  //      shape: RoundedRectangleBorder(
  //        borderRadius: BorderRadius.circular(12),
  //      ),
  //      duration: const Duration(seconds: 2),
  //    ),
  //  );
  //}

  /// Define los accesos directos (Shortcuts)
  void _setupQuickActions() {
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'add_transaction',
        localizedTitle: 'Nueva Transacción',
        icon: 'ic_shortcut_add_adaptive',
      ),
      // 🌟 NUEVO: Shortcut para ver manifestaciones
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
            FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('es', ''),
            Locale('en', ''),
          ],
          navigatorKey: navigatorKey,
          home: const SplashScreen(),
          routes: {
            '/add_transaction': (context) => const AddTransactionScreen(),
            // 🌟 NUEVO: Ruta para manifestaciones (debes crearla o ajustarla)
            // '/manifestations': (context) => const ManifestationsScreen(),
          },
        );
      },
    );
  }
}