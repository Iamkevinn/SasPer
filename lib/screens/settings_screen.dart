// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:sasper/data/auth_repository.dart'; // <-- ¡IMPORTANTE!

class SettingsScreen extends StatefulWidget {
  // Ahora requiere el AuthRepository
  final AuthRepository authRepository;

  const SettingsScreen({super.key, required this.authRepository});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? _user;

  @override
  void initState() {
    super.initState();
    // Obtenemos el usuario desde el repositorio, no directamente de Supabase
    _user = widget.authRepository.currentUser;
  }

  Future<void> _showLogoutConfirmationDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirmar Cierre de Sesión', style: GoogleFonts.poppins()),
          content: const Text('¿Estás seguro de que quieres cerrar tu sesión?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      try {
        // --- ¡CAMBIO CLAVE! ---
        // Usamos el método del repositorio para cerrar sesión.
        await widget.authRepository.signOut();
        // El AuthGate se encargará del resto.
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Error al cerrar sesión: "${e.toString()}"',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // --- ¡NUEVO! ---
      // Usamos un AppBar para una estructura más estándar.
      appBar: AppBar(
        title: Text('Ajustes', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        children: [
          // --- SECCIÓN DE PERFIL ---
          _buildSectionHeader('Perfil'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                child: Text(
                  _user?.email?.substring(0, 1).toUpperCase() ?? '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              title: const Text('Sesión Iniciada como'),
              subtitle: Text(
                _user?.email ?? 'No autenticado',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
          
          // --- SECCIÓN DE APARIENCIA (Ejemplo de extensibilidad) ---
          const SizedBox(height: 16),
          _buildSectionHeader('Apariencia'),
           Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: SwitchListTile(
              title: const Text('Modo Oscuro'),
              secondary: const Icon(Iconsax.moon),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (bool value) {
                // Aquí iría la lógica para cambiar el tema de la app
                // usando un ThemeProvider (ej. Riverpod, Provider, etc.)
                 NotificationHelper.show(
                  context: context,
                  message: 'No se ha implementado esta función aún.',
                  type: NotificationType.error,
                );
              },
            ),
          ),

          // --- SECCIÓN DE ACCIONES ---
          const SizedBox(height: 16),
          _buildSectionHeader('Cuenta'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: ListTile(
              leading: Icon(Iconsax.logout, color: colorScheme.error),
              title: Text('Cerrar Sesión', style: TextStyle(color: colorScheme.error)),
              onTap: _showLogoutConfirmationDialog,
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para los títulos de sección
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}