// lib/utils/credit_card_engine.dart

import 'dart:math';

class CreditCardEngine {
  
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
    required int interestFreeCount, // <-- Recibimos número de cuotas libres
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
}