// lib/utils/notification_helper.dart (VERSIÓN FINAL Y CORRECTA)

// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:sasper/main.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class NotificationHelper {
  static OverlayEntry? _overlayEntry;

  static void show({
    required String message,
    required NotificationType type,
  }) {
    // 1. Obtenemos el OverlayState directamente desde nuestra GlobalKey.
    final overlayState = navigatorKey.currentState?.overlay;
    if (overlayState == null) return; // Si no hay overlay, no podemos hacer nada.
    
    // Evita mostrar múltiples notificaciones a la vez.
    if (_overlayEntry != null) {
      _removeOverlay(); 
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // Envolvemos en Material para que los widgets internos tengan tema y estilo.
        return Material(
          color: Colors.transparent, 
          child: Align(
            alignment: Alignment.topCenter,
            child: CustomNotificationWidget(
              message: message,
              type: type,
              onDismissed: () => _removeOverlay(),
            ),
          ),
        );
      },
    );

    // 2. Usamos el OverlayState que obtuvimos para insertar la notificación.
    overlayState.insert(_overlayEntry!);
  }

  static void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}