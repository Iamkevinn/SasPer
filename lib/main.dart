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
import 'dart:async'; // Necesario para StreamSubscription

// --- PAQUETE ACTUALIZADO PARA DEEP LINKS ---
// Se reemplaza 'uni_links' por 'app_links' que es más moderno y compatible.
import 'package:app_links/app_links.dart';
import 'package:flutter_quill/flutter_quill.dart';

// =================================================================
//                 CONFIGURACIÓN GLOBAL
// =================================================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  
  if (kDebugMode) {
    print("--- CÓDIGOS PARA ICONOS DE GASTOS ---");
    print('El código para "Comida" (utensils) es: ${LineAwesomeIcons.utensils.codePoint}');
    print('El código para "Transporte" (bus) es: ${LineAwesomeIcons.bus.codePoint}');
    // ... (resto de tus prints)
  }

  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_CO', null);
  AppConfig.checkKeys();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// =================================================================
//       WIDGET PRINCIPAL DE LA APP (CON LÓGICA DE WIDGETS Y SHORTCUTS)
// =================================================================
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Para los Shortcuts (menú al presionar largo)
  final QuickActions quickActions = const QuickActions();
  
  // Para el Widget de Pantalla de Inicio (usando app_links)
  final _appLinks = AppLinks(); // Instancia del paquete
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    
    // Inicializa la lógica para los Shortcuts
    _setupQuickActions();
    _handleQuickActions();

    // Inicializa la lógica para el Widget de Pantalla de Inicio
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  /// Inicializa el manejo de deep links (clics desde el widget) de forma robusta.
  Future<void> _initDeepLinks() async {
    // Escucha los links que llegan mientras la app está abierta o en segundo plano.
    // 'uriLinkStream' es la forma correcta y principal de recibir todos los links.
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      // Usamos 'mounted' para asegurarnos de que el widget todavía está en el árbol
      // antes de intentar navegar.
      if (mounted) {
        _navigateToRouteFromUri(uri);
      }
    }, onError: (err) {
      if (mounted) {
        if (kDebugMode) {
          print('Error escuchando los links: $err');
        }
      }
    });
  }
  
  /// Navega a la pantalla correcta basándose en el URI del deep link.
  void _navigateToRouteFromUri(Uri uri) {
    if (kDebugMode) {
      print('Link recibido: $uri');
    }
    if (uri.scheme == 'sasper' && uri.host == 'sasper' && uri.path == '/add_transaction') {
      navigatorKey.currentState?.pushNamed('/add_transaction');
    }
  }

  /// Define y crea la lista de accesos directos (Shortcuts).
  void _setupQuickActions() {
    quickActions.setShortcutItems(<ShortcutItem>[
      const ShortcutItem(
        type: 'add_transaction',
        localizedTitle: 'Nueva Transacción',
        icon: 'ic_shortcut_add_adaptive',
      )
    ]);
  }

  /// Inicializa el "listener" para los clics en los Shortcuts.
  void _handleQuickActions() {
    quickActions.initialize((String shortcutType) {
      if (shortcutType == 'add_transaction') {
        navigatorKey.currentState?.pushNamed('/add_transaction');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tu método build no necesita ningún cambio, se queda exactamente igual.
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
          darkColorScheme = ColorScheme.fromSeed(seedColor: Colors.blueAccent, brightness: Brightness.dark);
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
          },
        );
      },
    );
  }
}