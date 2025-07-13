import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'accounts_screen.dart';
import 'add_transaction_screen.dart';
import 'analysis_screen.dart';
import 'budgets_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import '../utils/custom_page_route.dart';
// ELIMINADO: Ya no necesitamos el EventService para este flujo.
// import '../services/event_service.dart';
// ELIMINADO: No se está usando en este archivo.
// import 'dart:developer' as developer; 

// --- PANTALLA PRINCIPAL (CONTROLADOR DE NAVEGACIÓN) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  // ELIMINADO: Las GlobalKeys ya no son necesarias porque no vamos a
  // llamar a métodos de refresco manuales desde aquí.
  // final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  // ... (y las otras keys) ...

  // La lista de widgets es ahora más simple. Son solo las pantallas.
  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    AccountsScreen(), // El estado de esta pantalla también debería ser reactivo.
    AnalysisScreen(),
    SettingsScreen(),
  ];

  // ELIMINADO: Este método es completamente obsoleto con la arquitectura de Streams.
  // void _refreshDataForCurrentTab() { ... }

  // CAMBIO: El método para añadir transacción ahora es mucho más simple.
  void _navigateToAddTransaction() {
    HapticFeedback.heavyImpact();
    // Simplemente navegamos a la pantalla de añadir transacción.
    Navigator.of(context).push(
      FadePageRoute(child: const AddTransactionScreen()),
    );
    // ELIMINADO: El bloque .then() es innecesario. Cuando esta pantalla
    // guarde la transacción en Supabase, los streams se activarán
    // y actualizarán el Dashboard automáticamente. ¡No hay que hacer nada más!
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // IndexedStack sigue siendo la mejor opción para mantener el estado de las pantallas.
          IndexedStack(
            index: _selectedIndex,
            children: _widgetOptions,
          ),
          
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // La animación del FAB ya no necesita lógica extra, solo _navigateToAddTransaction.
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _selectedIndex == 0 ? 56.0 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: _selectedIndex == 0 ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      onPressed: _navigateToAddTransaction,
                      child: const Icon(Iconsax.add),
                    ),
                  ),
                ),
                SizedBox(height: _selectedIndex == 0 ? 12 : 0),
                _buildLiquidGlassNavBar(context), 
                SizedBox(height: mediaQuery.padding.bottom + 8),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- El resto de tu UI está perfecto y no necesita cambios ---
  Widget _buildLiquidGlassNavBar(BuildContext context) {
    // ... tu código de la barra de navegación aquí ...
    return ClipRRect(
      borderRadius: BorderRadius.circular(50.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withAlpha(25),
                Colors.white.withAlpha(10),
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavItem(index: 0, selectedIcon: Iconsax.home_15, regularIcon: Iconsax.home),
              _buildNavItem(index: 1, selectedIcon: Iconsax.wallet_money, regularIcon: Iconsax.wallet_3),
              _buildNavItem(index: 2, selectedIcon: Iconsax.chart_215, regularIcon: Iconsax.chart_21),
              _buildNavItem(index: 3, selectedIcon: Iconsax.setting_4, regularIcon: Iconsax.setting_2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required int index, required IconData selectedIcon, required IconData regularIcon}) {
    // ... tu código del item de navegación aquí ...
        final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;
    return SizedBox(
      width: 68,
      height: 60,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _onItemTapped(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withAlpha(200),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Icon(isSelected ? selectedIcon : regularIcon, color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant.withAlpha(200)),
          ],
        ),
      ),
    );
  }
}

// La clase helper NoisePainter no se usa en el build, pero la dejamos por si se usa en otro lado.
// Si no la usas, puedes eliminarla también.
class NoisePainter extends CustomPainter {
  final FragmentProgram shaderProgram;
  NoisePainter(this.shaderProgram);
  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}