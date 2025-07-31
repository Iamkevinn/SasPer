// lib/widgets/dashboard/dashboard_header.dart

import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;

  const DashboardHeader({super.key, required this.userName});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  // --- CAMBIO CLAVE: Nuevo método para obtener solo el primer nombre ---
  String _getFirstName(String fullName) {
    // Si el nombre está vacío o solo son espacios, devolvemos un string vacío.
    if (fullName.trim().isEmpty) {
      return '';
    }
    // 1. Limpiamos los espacios de los extremos.
    // 2. Dividimos el nombre por los espacios.
    // 3. Tomamos el primer elemento de la lista resultante.
    // El método .first es seguro aquí porque el chequeo anterior asegura que la lista no estará vacía.
    return fullName.trim().split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    // Obtenemos el primer nombre usando nuestro nuevo método.
    final firstName = _getFirstName(userName);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getGreeting()},',
            style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w400,
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4), 
          
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Text(
              // Usamos la variable 'firstName' en lugar de 'userName'
              key: ValueKey<String>(firstName), 
              firstName, // <-- ¡AQUÍ ESTÁ EL CAMBIO!
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}