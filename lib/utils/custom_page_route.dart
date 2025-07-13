// --- NUEVO: Pon esta clase al final de tu archivo dashboard_screen.dart ---
import 'package:flutter/material.dart';

class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget child;

  FadePageRoute({required this.child})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionsBuilder: (context, animation, secondaryAnimation, page) {
            return FadeTransition(opacity: animation, child: page);
          },
          transitionDuration: const Duration(milliseconds: 300), // Controla la velocidad
        );
}
