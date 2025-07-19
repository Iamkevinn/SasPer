// lib/widgets/dashboard/dashboard_header.dart

import 'package:flutter/material.dart';

class DashboardHeader extends StatelessWidget {
  final String userName;

  const DashboardHeader({super.key, required this.userName});

  // La lógica del saludo está perfecta, no necesita cambios.
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 19) return 'Buenas tardes'; // Ajustado a las 7 PM para ser más común
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16), // Aumentamos el padding inferior
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getGreeting()},',
            style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w400, // Un peso un poco más ligero para el saludo
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 4), // Un pequeño espaciador
          
          // 1. ANIMATED SWITCHER para una transición suave al cargar el nombre
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: Text(
              // Usamos el nombre como Key para que el switcher detecte el cambio
              key: ValueKey<String>(userName), 
              userName,
              maxLines: 1, // 2. Evita saltos de línea en nombres largos
              overflow: TextOverflow.ellipsis, // Corta el nombre si es demasiado largo
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                height: 1.2, // Ajusta la altura de línea para un mejor espaciado
              ),
            ),
          ),
        ],
      ),
    );
  }
}