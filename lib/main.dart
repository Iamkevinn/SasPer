import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sasper/screens/SplashScreen.dart';
import 'package:provider/provider.dart';
import 'package:sasper/services/theme_provider.dart';

// La GlobalKey sigue siendo una buena práctica.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  // 1. Asegura que los bindings de Flutter estén listos.
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Inicializa la localización de fechas (es muy rápido).
  await initializeDateFormatting('es_CO', null);
  
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