import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sasper/screens/SplashScreen.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sasper/services/theme_provider.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart'; // ¡Asegúrate de importar el paquete!
import 'package:sasper/screens/auth_check_screen.dart';
// =================================================================
//                 SOLUCIÓN DEFINITIVA PARA TREE SHAKING
//
// Esta lista estática y sin usar se coloca aquí para asegurar que el compilador
// de Flutter vea estas referencias a iconos durante el análisis y los conserve
// en la compilación final de la app.
// =================================================================
final List<IconData> _usedIconsForTreeShaking = [
  // Iconos de Gastos
  LineAwesomeIcons.utensils,      // Comida
  LineAwesomeIcons.bus,           // Transporte
  LineAwesomeIcons.gamepad,       // Ocio
  LineAwesomeIcons.home,          // Hogar
  LineAwesomeIcons.shopping_cart, // Compras
  LineAwesomeIcons.plug,          // Servicios
  LineAwesomeIcons.heart,         // Salud
  LineAwesomeIcons.grip_horizontal, // Otro (Gasto)

  // Iconos de Ingresos
  LineAwesomeIcons.money_bill, // Sueldo
  LineAwesomeIcons.line_chart,      // Inversión
  LineAwesomeIcons.briefcase,       // Freelance
  LineAwesomeIcons.gift,            // Regalo
  // 'Otro' (Ingreso) usa grip_horizontal, que ya está incluido.
];

// La GlobalKey sigue siendo una buena práctica.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  
  if (kDebugMode) {
    print("--- CÓDIGOS PARA ICONOS DE GASTOS ---");
    print('El código para "Comida" (utensils) es: ${LineAwesomeIcons.utensils.codePoint}');
    print('El código para "Transporte" (bus) es: ${LineAwesomeIcons.bus.codePoint}');
    print('El código para "Ocio" (gamepad) es: ${LineAwesomeIcons.gamepad.codePoint}');
    print('El código para "Hogar" (home) es: ${LineAwesomeIcons.home.codePoint}');
    print('El código para "Compras" (shopping_cart) es: ${LineAwesomeIcons.shopping_cart.codePoint}');
    print('El código para "Servicios" (plug) es: ${LineAwesomeIcons.plug.codePoint}');
    print('El código para "Salud" (heartbeat) es: ${LineAwesomeIcons.heartbeat.codePoint}');
    print('El código para "Otro (Gasto)" (dot_circle) es: ${LineAwesomeIcons.dot_circle.codePoint}');
    print('El código para "Sueldo" (money_bill_wave) es: ${LineAwesomeIcons.money_bill.codePoint}');
    print('El código para "Inversión" (line_chart) es: ${LineAwesomeIcons.line_chart.codePoint}');
    print('El código para "Freelance" (briefcase) es: ${LineAwesomeIcons.briefcase.codePoint}');
    print('El código para "Regalo" (gift) es: ${LineAwesomeIcons.gift.codePoint}');
    print('El código para "Otro (Ingreso)" (question_circle) es: ${LineAwesomeIcons.question_circle.codePoint}');
  }

  
  // 1. Asegura que los bindings de Flutter estén listos.
  WidgetsFlutterBinding.ensureInitialized();
  print('Forzando la inclusión de ${_usedIconsForTreeShaking.length} iconos predeterminados.');
  // 2. Inicializa la localización de fechas (es muy rápido).
  await initializeDateFormatting('es_CO', null);
  await dotenv.load(fileName: ".env");
  final geminiApiKey = dotenv.env['GEMINI_API_KEY'];
  final openWeatherApiKey = dotenv.env['OPENWEATHER_API_KEY'];
  final supabaseApiKey = dotenv.env['SUPABASE_API_KEY'];
  print("🔑 Claves cargadas:");
  print("Gemini: ${geminiApiKey != null}");
  print("OpenWeather: ${openWeatherApiKey != null}");
  print("Supabase: ${supabaseApiKey != null}");
  // 3. ¡Ejecuta la app INMEDIATAMENTE!
  //    Toda la carga pesada ahora está dentro de SplashScreen.
  runApp(
    // Envolvemos la app con un ChangeNotifierProvider
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consumimos el provider para obtener el themeMode
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
          ],
          supportedLocales: const [
            Locale('es', ''),
            Locale('en', ''),
          ],
          navigatorKey: navigatorKey, 
          // --- CAMBIO CLAVE ---
          // La pantalla de inicio de la app ahora es la pantalla de carga.
          home: const SplashScreen(),
        );
      },
    );
  }
}