// lib/utils/app_icons.dart (CÓDIGO CORREGIDO)

import 'package:flutter/widgets.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

/// Este archivo existe únicamente para engañar al mecanismo de "tree-shaking" de Flutter.
///
/// Al compilar en modo release, Flutter elimina los iconos de las fuentes que no
/// se usan explícitamente en el código. Como los iconos de nuestras categorías
/// predeterminadas vienen de la base de datos, el compilador no los ve y los elimina.
///
/// Esta lista estática asegura que los iconos requeridos siempre se incluyan
/// en el paquete final de la aplicación. NO ES NECESARIO LLAMAR O USAR ESTA CLASE
/// EN NINGÚN OTRO LUGAR. Su sola existencia es suficiente.
class AppIcons {
  AppIcons._(); // Constructor privado para que no se pueda instanciar.

  // CORRECCIÓN: Se quita 'const' porque los iconos no son constantes de compilación.
  // Usar 'static final' es suficiente para que el compilador los detecte.
  static final List<IconData> usedIcons = [
    // --- Iconos de Gastos ---
    LineAwesomeIcons.utensils,        // 'Comida', 61668
    LineAwesomeIcons.bus,             // 'Transporte', 59675
    LineAwesomeIcons.gamepad,         // 'Ocio', 59823
    LineAwesomeIcons.home,            // 'Hogar', 60339
    LineAwesomeIcons.shopping_cart,   // 'Compras', 61014
    LineAwesomeIcons.file_invoice,    // 'Servicios', 61386
    LineAwesomeIcons.heartbeat,       // 'Salud', 60318
    LineAwesomeIcons.question_circle, // 'Otro' (expense), 59895

    // --- Iconos de Ingresos ---
    LineAwesomeIcons.wallet,          // 'Sueldo', 60628
    LineAwesomeIcons.line_chart,      // 'Inversión', 59892 (CORREGIDO: de chart_line a line_chart)
    LineAwesomeIcons.briefcase,       // 'Freelance', 59833
    LineAwesomeIcons.gift,            // 'Regalo', 60249
    LineAwesomeIcons.dollar_sign,     // 'Otro' (income), 60201
  ];
}