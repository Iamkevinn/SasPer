// En lib/services/checkBudgetStatusAfterTransaction.dart

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> checkBudgetStatusAfterTransaction({
  required String categoryName, // <--- CAMBIO: Recibimos el nombre, no el ID
  required String userId,
}) async {
  final supabase = Supabase.instance.client;

  try {
    // 1. Encontrar si existe un presupuesto para esta categoría (usando el nombre)
    final budgetResponse = await supabase
        .from('budgets')
        .select('id, amount') // No necesitamos category_id
        .eq('user_id', userId)
        .eq('category', categoryName) // <--- CAMBIO: Buscamos por nombre
        .maybeSingle(); // Usamos maybeSingle para manejar el caso de que no exista

    if (budgetResponse == null) {
      print('No hay presupuesto para la categoría "$categoryName". No se hace nada.');
      return;
    }

    final budgetAmount = budgetResponse['amount'] as double;

    // 2. Calcular el total gastado en esta categoría este mes (usando el nombre)
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final transactionsResponse = await supabase
        .from('transactions')
        .select('amount')
        .eq('user_id', userId)
        .eq('type', 'Gasto') // Es buena práctica asegurarse de que solo sumamos gastos
        .eq('category', categoryName) // <--- CAMBIO: Filtramos por nombre de categoría
        .gte('transaction_date', firstDayOfMonth.toIso8601String())
        .lte('transaction_date', lastDayOfMonth.toIso8601String());

    double totalSpent = 0.0;
    for (var transaction in transactionsResponse) {
      // Los montos de gasto deberían ser positivos en la BD, pero si los guardas negativos, hay que usar .abs()
      totalSpent += (transaction['amount'] as num).toDouble();
    }

    // 3. Verificar umbrales y "enviar" notificación (esta parte no cambia)
    final percentageSpent = (totalSpent / budgetAmount) * 100;
    print('Gasto del presupuesto para "$categoryName": ${percentageSpent.toStringAsFixed(2)}% de $budgetAmount');

    String? notificationTitle;
    String? notificationBody;
    
    // Podríamos añadir una columna 'last_notified_percentage' en la tabla de presupuestos
    // para no enviar la misma notificación (ej. del 80%) varias veces.
    // Pero por ahora, lo mantenemos simple.

    if (percentageSpent >= 100) {
      notificationTitle = 'Presupuesto Excedido';
      notificationBody = '¡Cuidado! Has superado tu presupuesto para "$categoryName".';
    } else if (percentageSpent >= 80) {
      notificationTitle = 'Alerta de Presupuesto';
      notificationBody = 'Ya has utilizado el 80% de tu presupuesto para "$categoryName".';
    }

    if (notificationTitle != null && notificationBody != null) {
      print('--- SIMULANDO NOTIFICACIÓN ---');
      print('Título: $notificationTitle');
      print('Cuerpo: $notificationBody');
      print('------------------------------');

      // Aquí es donde llamaremos al backend.
    }

  } catch (e) {
    print('Error verificando el estado del presupuesto: $e');
  }
}