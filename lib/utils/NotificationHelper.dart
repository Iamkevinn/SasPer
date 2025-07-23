// lib/utils/notification_helper.dart

import 'package:flutter/material.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class NotificationHelper {
  static OverlayEntry? _overlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    required NotificationType type,
  }) {
    if (_overlayEntry != null) {
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) {
        // --- LA SOLUCIÓN ESTÁ AQUÍ ---
        // Envolvemos el widget de notificación con Align.
        return Align(
          // Lo alineamos a la parte superior central de la pantalla.
          alignment: Alignment.topCenter,
          
          // El resto del código es idéntico.
          child: CustomNotificationWidget(
            message: message,
            type: type,
            onDismissed: () {
              _removeOverlay();
            },
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}