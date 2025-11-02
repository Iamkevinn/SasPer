/// Tipos de widgets disponibles en la aplicación
enum WidgetType {
  dashboard,
  financialHealth,
  monthlyComparison,
  goals,
  upcomingPayments,
  nextPayment,
}

extension WidgetTypeExtension on WidgetType {
  /// Nombre del provider en la plataforma nativa
  String get providerName {
    switch (this) {
      case WidgetType.dashboard:
        return 'SasPerMediumWidgetProvider';
      case WidgetType.financialHealth:
        return 'FinancialHealthWidgetProvider';
      case WidgetType.monthlyComparison:
        return 'MonthlyComparisonWidgetProvider';
      case WidgetType.goals:
        return 'GoalsWidgetProvider';
      case WidgetType.upcomingPayments:
        return 'UpcomingPaymentsWidgetProvider';
      case WidgetType.nextPayment:
        return 'NextPaymentWidgetProvider';
    }
  }

  /// Clave para almacenamiento en SharedPreferences
  String get storageKey {
    switch (this) {
      case WidgetType.dashboard:
        return 'dashboard_data';
      case WidgetType.financialHealth:
        return 'financial_health_data';
      case WidgetType.monthlyComparison:
        return 'monthly_comparison_data';
      case WidgetType.goals:
        return 'goals_list';
      case WidgetType.upcomingPayments:
        return 'upcoming_payments_data';
      case WidgetType.nextPayment:
        return 'next_payment_data';
    }
  }

  /// Prioridad de actualización (mayor = más prioritario)
  int get priority {
    switch (this) {
      case WidgetType.nextPayment:
        return 10;
      case WidgetType.financialHealth:
        return 9;
      case WidgetType.dashboard:
        return 8;
      case WidgetType.upcomingPayments:
        return 7;
      case WidgetType.goals:
        return 6;
      case WidgetType.monthlyComparison:
        return 5;
    }
  }
}

/// Tamaños de widgets
enum WidgetSize {
  small(200, 100),
  medium(400, 200),
  large(400, 300);

  final double width;
  final double height;

  const WidgetSize(this.width, this.height);
}
