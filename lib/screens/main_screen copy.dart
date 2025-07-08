// main_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'dashboard_screen.dart';
import 'add_transaction_screen.dart';

// Pantallas placeholder
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Pantalla de Cuentas',
            style: TextStyle(fontSize: 24, color: Colors.white70)),
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Pantalla de Ajustes',
            style: TextStyle(fontSize: 24, color: Colors.white70)),
      );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    AccountsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final mediaQuery = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          _widgetOptions.elementAt(_selectedIndex),

          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _selectedIndex == 0 ? 56.0 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: _selectedIndex == 0 ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => const AddTransactionScreen())),
                      child: const Icon(Iconsax.add),
                    ),
                  ),
                ),
                
                SizedBox(height: _selectedIndex == 0 ? 12 : 0),

                // --- NUESTRA BARRA DE NAVEGACIÓN COMPLETAMENTE ESTABLE ---
                _buildCustomNavBar(context),

                SizedBox(height: mediaQuery.padding.bottom + 8),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCustomNavBar(BuildContext context) {
    // Usamos el color del tema como base
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 220, // Ancho compacto fijo
      height: 65,  // Altura fija
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 25,
            spreadRadius: -10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            color: colorScheme.surfaceVariant.withAlpha(100),
            child: Row(
              // El Row contiene nuestras celdas de iconos inamovibles
              children: [
                _buildNavItem(index: 0, selectedIcon: Iconsax.home_15, regularIcon: Iconsax.home),
                // Usamos el icono que nos proporcionaste para Cuentas
                _buildNavItem(index: 1, selectedIcon: Iconsax.wallet_money, regularIcon: Iconsax.wallet_3),
                _buildNavItem(index: 2, selectedIcon: Iconsax.setting_4, regularIcon: Iconsax.setting_2),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // <-- CAMBIO CLAVE: LA CELDA DE ICONO AISLADA Y ESTABLE
  Widget _buildNavItem({
    required int index,
    required IconData selectedIcon,
    required IconData regularIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;
    
    return Expanded( // Cada celda ocupa 1/3 del espacio
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Stack( // Usamos un Stack para superponer el indicador y el icono
          alignment: Alignment.center,
          children: [
            // Capa 0: El indicador circular, que se anima con opacidad
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withAlpha(180),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            // Capa 1: El icono
            Icon(
              isSelected ? selectedIcon : regularIcon,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}