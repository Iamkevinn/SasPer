// lib/utils/credit_card_engine.dart

import 'dart:math';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/transaction_models.dart';

class CreditCardEngine {
  
  // =========================================================================
  // 1. TUS MÉTODOS ORIGINALES (Cálculo de Cuotas y Amortización)
  // =========================================================================

  static double _eaToMv(double tasaEA) {
    if (tasaEA <= 0) return 0.0;
    double decimalEA = tasaEA / 100;
    double tmv = pow(1 + decimalEA, 1 / 12) - 1;
    return tmv;
  }

  /// Calcula el valor mensual promedio de la cuota (Amortización Mixta)
  static double calculateMonthlyInstallment({
    required double totalAmount,
    required int installments,
    required double interestRateEA,
    required int interestFreeCount,
  }) {
    // Si todas las cuotas son libres, o es a 1 cuota, o no hay interés configurado
    if (installments <= 1 || interestFreeCount >= installments || interestRateEA <= 0) {
      return totalAmount / installments;
    }

    double i = _eaToMv(interestRateEA);

    if (interestFreeCount == 0) {
      // Amortización estándar: Interés en todas las cuotas
      double factor = pow(1 + i, installments).toDouble();
      return totalAmount * (i * factor) / (factor - 1);
    } else {
      // Caso Mixto (Promo parcial): 
      double principalPaidFree = (totalAmount / installments) * interestFreeCount;
      double remainingPrincipal = totalAmount - principalPaidFree;
      int remainingMonths = installments - interestFreeCount;
      
      double factor = pow(1 + i, remainingMonths).toDouble();
      double quotaWithInterest = remainingPrincipal * (i * factor) / (factor - 1);
      
      double totalPaid = principalPaidFree + (quotaWithInterest * remainingMonths);
      return totalPaid / installments;
    }
  }

  static DateTime getNextBillingDate(DateTime purchaseDate, int closingDay, int dueDay) {
    int currentMonth = purchaseDate.month;
    int currentYear = purchaseDate.year;

    if (purchaseDate.day > closingDay) {
      currentMonth += 1;
      if (currentMonth > 12) {
        currentMonth = 1;
        currentYear += 1;
      }
    }

    int paymentMonth = currentMonth;
    int paymentYear = currentYear;
    
    if (dueDay < closingDay) {
      paymentMonth += 1;
      if (paymentMonth > 12) {
        paymentMonth = 1;
        paymentYear += 1;
      }
    }

    int lastDayOfMonth = DateTime(paymentYear, paymentMonth + 1, 0).day;
    int finalDueDay = dueDay > lastDayOfMonth ? lastDayOfMonth : dueDay;

    return DateTime(paymentYear, paymentMonth, finalDueDay);
  }

  // =========================================================================
  // 2. NUEVOS MÉTODOS (Resumen Inteligente y Vida Crediticia)
  // =========================================================================

  /// Devuelve la fecha del próximo corte basándose en el día de corte configurado
  static DateTime getNextClosingDate(Account card, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final closingDay = card.closingDay ?? 1;

    DateTime nextClosing = DateTime(ref.year, ref.month, closingDay);
    
    // Si hoy ya pasó o es el día de corte, el próximo corte es el mes siguiente
    if (ref.isAfter(nextClosing) || (ref.day == closingDay)) {
      int nextMonth = ref.month + 1;
      int nextYear = ref.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      nextClosing = DateTime(nextYear, nextMonth, closingDay);
    }
    
    return nextClosing;
  }

  /// Devuelve la fecha del próximo límite de pago basándose en el día de pago
  static DateTime getNextDueDate(Account card, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final dueDay = card.dueDay ?? 15;

    DateTime nextDue = DateTime(ref.year, ref.month, dueDay);
    
    if (ref.isAfter(nextDue) || (ref.day == dueDay)) {
      int nextMonth = ref.month + 1;
      int nextYear = ref.year;
      if (nextMonth > 12) {
        nextMonth = 1;
        nextYear++;
      }
      nextDue = DateTime(nextYear, nextMonth, dueDay);
    }
    return nextDue;
  }

  /// Divide la deuda de la tarjeta en dos baldes:
  /// 1. Lo que ya pasó por corte (Deuda a pagar AHORA)
  /// 2. Lo que se compró post-corte (Deuda para el SIGUIENTE mes)
  static Map<String, double> segmentDebtByClosingDate(Account card, List<Transaction> transactions) {
    if (card.type != 'Tarjeta de Crédito') return {'current_cycle': 0.0, 'next_cycle': 0.0};

    final now = DateTime.now();
    final closingDay = card.closingDay ?? 1;
    
    // Calcular cuándo fue el último corte
    DateTime lastClosingDate;
    if (now.day > closingDay) {
      lastClosingDate = DateTime(now.year, now.month, closingDay);
    } else {
      int prevMonth = now.month - 1;
      int prevYear = now.year;
      if (prevMonth < 1) {
        prevMonth = 12;
        prevYear--;
      }
      lastClosingDate = DateTime(prevYear, prevMonth, closingDay);
    }

    double currentCycleDebt = 0.0;
    double nextCycleDebt = 0.0;

    for (var tx in transactions) {
      // Gastos (negativos en bd, pero los queremos sumar absolutos)
      if (tx.amount < 0) {
        if (tx.transactionDate.isBefore(lastClosingDate) || tx.transactionDate.isAtSameMomentAs(lastClosingDate)) {
          currentCycleDebt += tx.amount.abs();
        } else {
          nextCycleDebt += tx.amount.abs();
        }
      }
      // Pagos (positivos en bd), descuentan de la deuda más vieja primero
      else if (tx.amount > 0) {
        if (currentCycleDebt >= tx.amount) {
          currentCycleDebt -= tx.amount;
        } else {
          double remainder = tx.amount - currentCycleDebt;
          currentCycleDebt = 0;
          nextCycleDebt -= remainder;
          if (nextCycleDebt < 0) nextCycleDebt = 0;
        }
      }
    }

    return {
      'current_cycle': currentCycleDebt,
      'next_cycle': nextCycleDebt,
    };
  }

  /// Calcula el puntaje simulado del manejo de esta tarjeta (Vida Crediticia)
  /// Devuelve un valor de 0 a 100.
  static int calculateCreditScoreImpact(Account card, double currentDebtCycle, double totalDebt) {
    if (card.creditLimit <= 0) return 50; // Sin info suficiente

    int score = 100;

    // Utilización del crédito (El "Ratio de Utilización" ideal es menor al 30%)
    double utilization = totalDebt / card.creditLimit;
    if (utilization > 0.8) score -= 40;
    else if (utilization > 0.5) score -= 20;
    else if (utilization > 0.3) score -= 10;
    else score += 10; // Bonus por buena utilización

    // Si la tasa de interés es alta y estamos pagando a cuotas (se deduce si no es interestFree o usa mucha línea)
    if (card.interestRate > 25 && currentDebtCycle > (card.creditLimit * 0.1)) {
      score -= 10; // Riesgo por intereses altos en saldos revolventes
    }

    return score.clamp(0, 100).toInt();
  }
}