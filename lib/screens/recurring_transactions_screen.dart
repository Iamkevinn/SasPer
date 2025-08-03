// lib/screens/recurring_transactions_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/screens/add_recurring_transaction_screen.dart';
import 'package:sasper/screens/edit_recurring_transaction_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/services/notification_service.dart'; 
import 'package:sasper/main.dart'; // Para navigatorKey
import 'dart:developer' as developer; // Para logging

enum RecurringStatus { due, upcoming, scheduled }

class RecurringTransactionsScreen extends StatefulWidget {
  // El constructor ya no recibe ningún repositorio.
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  // Accedemos a la única instancia del repositorio directamente.
  final RecurringRepository _repository = RecurringRepository.instance;
  late final Stream<List<RecurringTransaction>> _stream;

  @override
  void initState() {
    super.initState();
    // Obtenemos el stream de la instancia singleton.
    _stream = _repository.getRecurringTransactionsStream();
  }

  @override
  void dispose() {
    // Ya no se llama a dispose() del repositorio.
    super.dispose();
  }
  
  void _navigateToEdit(RecurringTransaction transaction) async  {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        // La pantalla de edición ahora tampoco necesita que le pasen repositorios.
        // Ella misma obtendrá los Singletons que necesite.
        builder: (_) => EditRecurringTransactionScreen(transaction: transaction),
      ),
    );

    // Si volvemos con 'true', le damos el "empujón" al repositorio para
    // asegurar una actualización visual inmediata si fuera necesario.
    if (result == true) {
      _repository.refreshData();
    }
  }

  Future<void> _handleDelete(RecurringTransaction item) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Confirmar Eliminación', style: GoogleFonts.poppins(textStyle: Theme.of(dialogContext).textTheme.titleLarge)),
          content: Text('¿Seguro que quieres eliminar "${item.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // 2. Primero, eliminamos la transacción de la base de datos
        await _repository.deleteRecurringTransaction(item.id);

        // 3. LUEGO, CANCELAMOS SUS NOTIFICACIONES PROGRAMADAS
        await NotificationService.instance.cancelRecurringReminders(item.id);
        developer.log('✅ Notificaciones canceladas para: ${item.description}', name: 'RecurringScreen');

        await _repository.deleteRecurringTransaction(item.id);
        _repository.refreshData(); // Asegura que la UI se actualice
        NotificationHelper.show(
          message: '"${item.description}" eliminado.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message: 'Error al eliminar: ${e.toString().replaceFirst("Exception: ", "")}',
          type: NotificationType.error,
        );
      }
    }
  }

  void _navigateToAdd() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        // La pantalla de "Añadir" tampoco necesita repositorios en el constructor.
        builder: (_) => const AddRecurringTransactionScreen(),
      ),
    );

    if (result == true) {
      _repository.refreshData();
    }
  }

  RecurringStatus _getStatus(DateTime nextDueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);
    
    if (dueDate.isBefore(today) || dueDate.isAtSameMomentAs(today)) {
      return RecurringStatus.due;
    } else if (dueDate.difference(today).inDays <= 7) {
      return RecurringStatus.upcoming;
    } else {
      return RecurringStatus.scheduled;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gastos Fijos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square, size: 28),
            tooltip: 'Añadir Gasto Fijo',
            onPressed: _navigateToAdd,
          ),
        ],
      ),
      body: StreamBuilder<List<RecurringTransaction>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Center(
              child: EmptyStateCard(
                icon: Iconsax.repeat,
                title: 'Automatiza tus Finanzas',
                message: 'Añade aquí tus gastos o ingresos fijos (suscripciones, sueldo, alquiler) y la app los registrará por ti.',
                actionButton: ElevatedButton.icon(
                  onPressed: _navigateToAdd,
                  icon: const Icon(Iconsax.add),
                  label: const Text('Añadir mi primer gasto fijo'),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final status = _getStatus(item.nextDueDate);

              Color statusColor;
              IconData statusIcon;

              switch (status) {
                case RecurringStatus.due:
                  statusColor = Colors.red.shade400;
                  statusIcon = Iconsax.warning_2;
                  break;
                case RecurringStatus.upcoming:
                  statusColor = Colors.orange.shade400;
                  statusIcon = Iconsax.clock;
                  break;
                case RecurringStatus.scheduled:
                  statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
                  statusIcon = Iconsax.calendar_1;
                  break;
              }

              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainer,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: ListTile(
                  onTap: () => _navigateToEdit(item),
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.1),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  title: Text(item.description, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Próximo: ${DateFormat.yMMMd('es_CO').format(item.nextDueDate)} - ${toBeginningOfSentenceCase(item.frequency)}',
                    style: GoogleFonts.poppins(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.type == 'Gasto' ? '-' : '+'}${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(item.amount)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: item.type == 'Gasto' ? Colors.red.shade300 : Colors.green.shade400,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Iconsax.trash),
                        onPressed: () => _handleDelete(item),
                        tooltip: 'Eliminar',
                        color: Theme.of(context).colorScheme.error,
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}