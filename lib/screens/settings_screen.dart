import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:sasper/data/auth_repository.dart';
import 'package:sasper/screens/categories_screen.dart'; // Asegúrate de que este archivo exista
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/theme_provider.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/screens/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Accedemos a la única instancia (Singleton) del repositorio de autenticación.
  final AuthRepository _authRepository = AuthRepository.instance;
  User? _user;

  @override
  void initState() {
    super.initState();
    // Obtenemos el usuario actual desde el repositorio al iniciar la pantalla.
    _user = _authRepository.currentUser;
  }

  /// Muestra un diálogo para confirmar el cierre de sesión.
  Future<void> _showLogoutConfirmationDialog() async {
    // Usamos el 'context' del State, que es más seguro que un GlobalKey.
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmar Cierre de Sesión',
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(dialogContext).textTheme.titleLarge)),
          content: const Text('¿Estás seguro de que quieres cerrar tu sesión?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await _authRepository.signOut();
        // No necesitamos navegar manualmente, el AuthGate se encargará de
        // detectar el cambio de estado y redirigir a la pantalla de login.
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al cerrar sesión: "${e.toString()}"',
            type: NotificationType.error,
          );
        }
      }
    }
  }

  /// Muestra un diálogo para seleccionar el tema de la aplicación.
  void _showThemeDialog() {
    // Obtenemos la instancia del ThemeProvider sin escuchar cambios (listen: false)
    // porque solo necesitamos llamar a un método.
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Seleccionar Tema'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('Claro'),
                value: ThemeMode.light,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Oscuro'),
                value: ThemeMode.dark,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Automático (Sistema)'),
                value: ThemeMode.system,
                groupValue: themeProvider.themeMode,
                onChanged: (value) {
                  if (value != null) themeProvider.setThemeMode(value);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Devuelve un string legible para el modo de tema actual.
  String _getThemeModeString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Automático';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // Escuchamos los cambios en el ThemeProvider para reconstruir la UI cuando sea necesario.
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Ajustes',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      color: colorScheme.onPrimaryContainer),
                ),
              ),
              title: const Text('Sesión Iniciada como'),
              subtitle: Text(
                _user?.email ?? 'No autenticado',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
          ),
          // AÑADE ESTE BOTÓN DE PRUEBA
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Probar Notificación Inmediata'),
            subtitle: const Text('Recibirás una notificación en 5 segundos'),
            onTap: () {
              NotificationService.instance.testImmediateNotification();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text(
                        'Notificación de prueba programada para 5 segundos...')),
              );
            },
          ),
          // --- SECCIÓN DE PERSONALIZACIÓN ---
          const SizedBox(height: 16),
          _buildSectionHeader('Personalización'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: Column(
              children: [
                // --- ↓↓↓ AÑADE ESTA OPCIÓN, PREFERIBLEMENTE AL INICIO ↓↓↓ ---
                ListTile(
                  leading: const Icon(Iconsax.user),
                  title: const Text('Mi Progreso'),
                  subtitle: const Text('Ver tu nivel y logros'),
                  trailing: const Icon(Iconsax.arrow_right_3),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const ProfileScreen()),
                    );
                  },
                ),

                const Divider(),
                ListTile(
                  leading: const Icon(Iconsax.moon),
                  title: const Text('Modo de la aplicación'),
                  subtitle: Text(_getThemeModeString(themeProvider.themeMode)),
                  trailing: const Icon(Iconsax.arrow_down_1, size: 18),
                  onTap: _showThemeDialog,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Iconsax.shapes_1),
                  title: const Text('Gestionar Categorías'),
                  trailing: const Icon(Iconsax.arrow_right_3, size: 18),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CategoriesScreen(),
                    ));
                  },
                ),
              ],
            ),
          ),

          // --- SECCIÓN DE CUENTA ---
          const SizedBox(height: 16),
          _buildSectionHeader('Cuenta'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: ListTile(
              leading: Icon(Iconsax.logout, color: colorScheme.error),
              title: Text('Cerrar Sesión',
                  style: TextStyle(color: colorScheme.error)),
              onTap: _showLogoutConfirmationDialog,
            ),
          ),
        ],
      ),
    );
  }

  /// Widget auxiliar para construir los encabezados de sección con un estilo consistente.
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
