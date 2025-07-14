import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Función para mostrar el diálogo de confirmación de cierre de sesión
  Future<void> _showLogoutConfirmationDialog(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmar Cierre de Sesión'),
          content: const Text('¿Estás seguro de que quieres cerrar tu sesión?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false), // No confirmar
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true), // Sí confirmar
              style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );

    // Si el usuario confirmó y el widget todavía está montado, cerramos la sesión
    if (confirm == true && context.mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
        // No necesitamos navegar. El AuthGate escuchará el cambio de estado
        // y nos redirigirá automáticamente a la pantalla de login.
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error al cerrar sesión: $e'),
                backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final user = Supabase.instance.client.auth.currentUser;

    return Padding(
      // Padding superior para respetar la barra de estado
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Título de la pantalla
          Text(
            'Ajustes',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          // --- SECCIÓN DE PERFIL ---
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: ListTile(
              leading: const Icon(Iconsax.user, size: 30),
              title: const Text('Sesión Iniciada como',
                  style: TextStyle(fontSize: 14)),
              subtitle: Text(
                user?.email ?? 'No autenticado',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const Divider(), // Un separador visual
          
          const SizedBox(height: 16),

          // --- SECCIÓN DE ACCIONES ---
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            child: Column(
              children: [
                // Aquí podríamos añadir más opciones en el futuro (Ej: Apariencia, Notificaciones)
                ListTile(
                  leading: Icon(Iconsax.logout, color: colorScheme.error),
                  title: Text('Cerrar Sesión',
                      style: TextStyle(color: colorScheme.error)),
                  onTap: () => _showLogoutConfirmationDialog(context),
                ),
              ],
            ),
          ),

          // Espacio extra al final para que el menú flotante no tape nada
          const SizedBox(height: 150),
        ],
      ),
    );
  }
}
