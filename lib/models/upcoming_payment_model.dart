// lib/models/upcoming_payment_model.dart

/// Tipos de pago próximo que el widget puede mostrar.
/// 
/// - [debt]        → Deuda activa con saldo pendiente
/// - [recurring]   → Transacción recurrente con nextDueDate futuro
/// - [freeTrial]   → Prueba gratuita que está por vencer (convierte a pago)
/// - [creditCard]  → Cuota de compra a plazos con cuotas pendientes
enum UpcomingPaymentType { debt, recurring, freeTrial, creditCard }

class UpcomingPayment {
  final String id;
  final String concept;
  final double amount;
  final DateTime nextDueDate;
  final UpcomingPaymentType type;

  /// Campo auxiliar para mostrar información extra en el widget.
  /// 
  /// Ejemplos por tipo:
  /// - debt:       null  (concept ya es descriptivo)
  /// - recurring:  null
  /// - freeTrial:  "Prueba gratuita"
  /// - creditCard: "Cuota 3 de 12"
  final String? subtype;

  /// Nombre del ícono para renderizado opcional en el widget.
  final String? iconName;

  UpcomingPayment({
    required this.id,
    required this.concept,
    required this.amount,
    required this.nextDueDate,
    required this.type,
    this.subtype,
    this.iconName,
  });

  /// Serializa a JSON para SharedPreferences → Kotlin (Gson).
  /// 
  /// El campo [type] se serializa como String con el nombre del enum.
  /// Kotlin lo lee en `tv_payment_category` directamente.
  /// El campo [subtype] es adicional y Kotlin puede ignorarlo sin romper nada.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'concept': concept,
      'amount': amount,
      'nextDueDate': nextDueDate.toIso8601String(),
      'type': type.name,       // 'debt' | 'recurring' | 'freeTrial' | 'creditCard'
      'subtype': subtype,      // Detalle adicional para el widget (nullable)
      'iconName': iconName,
    };
  }
}