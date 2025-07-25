// lib/screens/recurring_transactions_screen.dart (VERSIÓN FINAL Y CORREGIDA)

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/screens/add_recurring_transaction_screen.dart';
import 'package:sasper/screens/edit_recurring_transaction_screen.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

// Enum para definir los estados visuales de un gasto fijo.
enum RecurringStatus { due, upcoming, scheduled }

class RecurringTransactionsScreen extends StatefulWidget {
  final RecurringRepository repository;
  final AccountRepository accountRepository;

  const RecurringTransactionsScreen({
    super.key,
    required this.repository,
    required this.accountRepository,
  });

  @override
  State<RecurringTransactionsScreen> createState() => _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState extends State<RecurringTransactionsScreen> {
  late final Stream<List<RecurringTransaction>> _stream;
  // --- DECLARACIÓN AÑADIDA AQUÍ ---
  late final StreamSubscription<AppEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    _stream = widget.repository.getRecurringTransactionsStream();
    
    // Nos suscribimos al stream de eventos
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      // Si el evento es el que nos interesa, forzamos la recarga de datos
      if (event == AppEvent.recurringTransactionChanged) {
        widget.repository.forceRefresh();
      }
    });
  }

  @override
  void dispose() {
    _eventSubscription.cancel(); // Cancelamos la suscripción al evento
    widget.repository.dispose(); // Limpiamos los recursos del repositorio
    super.dispose();
  }
  
  void _navigateToEdit(RecurringTransaction transaction) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditRecurringTransactionScreen(
        repository: widget.repository,
        accountRepository: widget.accountRepository,
        transaction: transaction,
      ),
    ));
  }

  Future<void> _handleDelete(RecurringTransaction item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: Text('¿Seguro que quieres eliminar "${item.description}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
              child: const Text('Eliminar')),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.repository.deleteRecurringTransaction(item.id);
        EventService.instance.fire(AppEvent.recurringTransactionChanged);
        NotificationHelper.show(
          context: context,
          message: '"${item.description}" eliminado.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          context: context,
          message: 'Error al eliminar: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    }
  }

  void _navigateToAdd() async {
    // La pantalla de añadir debería disparar un evento, igual que la de editar.
    // Opcionalmente, puedes esperar un resultado `true` si prefieres ese método.
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddRecurringTransactionScreen(
        repository: widget.repository,
        accountRepository: widget.accountRepository,
      ),
    ));
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
              Widget? animationWidget;

              switch (status) {
                case RecurringStatus.due:
                  statusColor = Colors.red.shade400;
                  statusIcon = Iconsax.warning_2;
                  animationWidget = TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.5, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) => Opacity(opacity: value, child: child),
                    child: Icon(Icons.circle, color: statusColor.withOpacity(0.5), size: 10),
                  );
                  break;
                case RecurringStatus.upcoming:
                  statusColor = Colors.orange.shade400;
                  statusIcon = Iconsax.clock;
                  animationWidget = null;
                  break;
                case RecurringStatus.scheduled:
                default:
                  statusColor = Theme.of(context).colorScheme.onSurfaceVariant;
                  statusIcon = Iconsax.calendar_1;
                  animationWidget = null;
                  break;
              }

              return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.1),
                      child: Icon(statusIcon, color: statusColor, size: 20),
                    ),
                    title: Text(item.description, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      'Próximo: ${DateFormat.yMMMd('es_CO').format(item.nextDueDate)} - ${item.frequency}',
                      style: GoogleFonts.poppins(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item.type == 'Gasto' ? '-' : '+'}${NumberFormat.currency(locale: 'ES_CO', symbol: '\$').format(item.amount)}',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            color: item.type == 'Gasto' ? Colors.red.shade300 : Colors.green.shade400,
                          ),
                        ),
                        PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _navigateToEdit(item);
                              if (value == 'delete') _handleDelete(item);
                            },
                            itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                  const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                ]),
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