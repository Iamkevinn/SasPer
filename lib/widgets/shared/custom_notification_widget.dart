// lib/widgets/shared/custom_notification_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

// Enum para definir el tipo de notificación y controlar el estilo
enum NotificationType { success, error, info, warning }

class CustomNotificationWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final VoidCallback onDismissed; // Callback para cuando la animación de salida termina

  const CustomNotificationWidget({
    super.key,
    required this.message,
    required this.type,
    required this.onDismissed,
  });

  @override
  State<CustomNotificationWidget> createState() => _CustomNotificationWidgetState();
}

class _CustomNotificationWidgetState extends State<CustomNotificationWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5), // Empieza fuera de la pantalla, arriba
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Inicia la animación de entrada y programa la de salida
    _showAndHide();
  }
  
  void _showAndHide() async {
    // Animación de entrada
    await _controller.forward();
    // Espera 3 segundos
    await Future.delayed(const Duration(seconds: 3));
    // Animación de salida (solo si el widget todavía está montado)
    if (mounted) {
      await _controller.reverse();
      widget.onDismissed();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Lógica para obtener el estilo basado en el tipo
  _NotificationStyle _getStyle(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.type) {
      case NotificationType.success:
        return _NotificationStyle(
          icon: Iconsax.tick_circle,
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
        );
      case NotificationType.error:
        return _NotificationStyle(
          icon: Iconsax.info_circle,
          backgroundColor: colorScheme.errorContainer,
          foregroundColor: colorScheme.onErrorContainer,
        );
      case NotificationType.info:
      default:
        return _NotificationStyle(
          icon: Iconsax.info_circle,
          backgroundColor: colorScheme.secondaryContainer,
          foregroundColor: colorScheme.onSecondaryContainer,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle(context);

    return SlideTransition(
      position: _offsetAnimation,
      child: SafeArea( // Asegura que no se solape con la barra de estado
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Material(
            borderRadius: BorderRadius.circular(16.0),
            color: style.backgroundColor,
            elevation: 4.0, // Una pequeña sombra para destacar
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(style.icon, color: style.foregroundColor),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.poppins(
                        color: style.foregroundColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Pequeña clase helper para el estilo
class _NotificationStyle {
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  _NotificationStyle({required this.icon, required this.backgroundColor, required this.foregroundColor});
}