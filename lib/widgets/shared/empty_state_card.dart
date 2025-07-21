// lib/widgets/shared/empty_state_card.dart

import 'package:flutter/material.dart';

class EmptyStateCard extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  // 1. AÑADIMOS UN WIDGET DE ACCIÓN OPCIONAL
  final Widget? actionButton;

  const EmptyStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionButton, // El nuevo parámetro opcional
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      // Padding un poco más generoso para un look más "aireado"
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      margin: const EdgeInsets.symmetric(horizontal: 24), // Margen para que no pegue a los bordes
      decoration: BoxDecoration(
        // Un color de fondo sutil del tema
        color: colorScheme.surface.withAlpha(50),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        // 2. HACEMOS QUE LA COLUMNA OCUPE EL MÍNIMO ESPACIO VERTICAL
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un círculo de fondo para el ícono, lo hace destacar más
          CircleAvatar(
            radius: 32,
            backgroundColor: colorScheme.primary.withOpacity(0.1),
            child: Icon(
              icon,
              size: 32,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          // 3. SI HAY UN BOTÓN DE ACCIÓN, LO MOSTRAMOS
          if (actionButton != null) ...[
            const SizedBox(height: 24),
            actionButton!,
          ]
        ],
      ),
    );
  }
}