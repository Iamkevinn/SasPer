import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _copFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static final NumberFormat _copCompactFormat = NumberFormat.compactCurrency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static String format(double amount, {bool compact = false}) {
    if (compact && amount.abs() >= 1000000) {
      return _copCompactFormat.format(amount);
    }
    return _copFormat.format(amount);
  }

  static String formatPercentage(double value, {int decimals = 1}) {
    return '${value.toStringAsFixed(decimals)}%';
  }

  static String formatShort(double amount) {
    if (amount.abs() >= 1000000) {
      return '\$${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(0)}K';
    }
    return '\$${amount.toStringAsFixed(0)}';
  }
}