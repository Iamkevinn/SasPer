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
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/main.dart'; // Para navigatorKey
import 'dart:developer' as developer; // Para logging
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';

enum RecurringStatus { due, upcoming, scheduled }

class RecurringTransactionsScreen extends StatefulWidget {
  // El constructor ya no recibe ningún repositorio.
  const RecurringTransactionsScreen({super.key});

  @override
  State<RecurringTransactionsScreen> createState() =>
      _RecurringTransactionsScreenState();
}

class _RecurringTransactionsScreenState
    extends State<RecurringTransactionsScreen> {
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

  void _navigateToEdit(RecurringTransaction transaction) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        // La pantalla de edición ahora tampoco necesita que le pasen repositorios.
        // Ella misma obtendrá los Singletons que necesite.
        builder: (_) =>
            EditRecurringTransactionScreen(transaction: transaction),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Confirmar Eliminación',
              style: GoogleFonts.poppins(
                  textStyle: Theme.of(dialogContext).textTheme.titleLarge)),
          content: Text('¿Seguro que quieres eliminar "${item.description}"?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor:
                      Theme.of(dialogContext).colorScheme.errorContainer),
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
        developer.log('✅ Notificaciones canceladas para: ${item.description}',
            name: 'RecurringScreen');

        await _repository.deleteRecurringTransaction(item.id);
        _repository.refreshData(); // Asegura que la UI se actualice
        NotificationHelper.show(
          message: '"${item.description}" eliminado.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message:
              'Error al eliminar: ${e.toString().replaceFirst("Exception: ", "")}',
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
    final dueDate =
        DateTime(nextDueDate.year, nextDueDate.month, nextDueDate.day);

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
        title: Text('Gastos Fijos',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
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
            // --- REEMPLAZO DE INDICADOR CON SKELETONIZER ---
            return Skeletonizer(
              child: ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: 6, // Muestra 6 elementos esqueleto
                itemBuilder: (context, index) => Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(),
                    title: Text('Cargando descripción...' * 2),
                    subtitle: const Text('Próximo: dd/mm/aaaa - Frecuencia'),
                    trailing: Text(' \$000,000',
                        style:
                            GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            // --- REEMPLAZO DE EMPTYSTATECARD CON LOTTIE ---
            return _buildLottieEmptyState();
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
                  title: Text(item.description,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    'Próximo: ${DateFormat.yMMMd('es_CO').format(item.nextDueDate)} - ${toBeginningOfSentenceCase(item.frequency)}',
                    style: GoogleFonts.poppins(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${item.type == 'Gasto' ? '-' : '+'}${NumberFormat.currency(locale: 'es_CO', symbol: '\$').format(item.amount)}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: item.type == 'Gasto'
                              ? Colors.red.shade300
                              : Colors.green.shade400,
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
              )
                  .animate()
                  .fadeIn(duration: 500.ms, delay: (100 * index).ms)
                  .slideY(begin: 0.2, curve: Curves.easeOutCubic);
            },
          );
        },
      ),
    );
  }

  // --- NUEVO WIDGET AUXILIAR PARA EL ESTADO VACÍO CON LOTTIE ---
  Widget _buildLottieEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/automation_animation.json',
                width: 250,
                height: 250,
              ),
              const SizedBox(height: 16),
              Text(
                'Automatiza tus Finanzas',
                style: GoogleFonts.poppins(
                    fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Añade aquí tus gastos o ingresos fijos (suscripciones, sueldo, alquiler) y la app los registrará por ti.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToAdd,
                icon: const Icon(Iconsax.add),
                label: const Text('Añadir mi primer gasto fijo'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}

// --- NUEVO WIDGET DE TARJETA INTERACTIVA ---
class _PaymentCard extends StatelessWidget {
  final RecurringTransaction item;
  final RecurringRepository _repository = RecurringRepository.instance;

  _PaymentCard({required this.item});

  // --- LÓGICA DE ACCIONES ---
  void _handlePay(BuildContext context) async {
    // Aquí podrías mostrar un diálogo de confirmación
    try {
      await _repository.processPayment(item.id);
      // Mostrar snackbar de éxito
    } catch (e) {
      // Mostrar snackbar de error
    }
  }

  void _handleSkip(BuildContext context) async {
    try {
      await _repository.skipPayment(item.id);
      // Mostrar snackbar de éxito
    } catch (e) {
      // Mostrar snackbar de error
    }
  }

  void _handleSnooze(BuildContext context) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: item.nextDueDate.add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (newDate != null) {
      try {
        await _repository.snoozePayment(item.id, newDate);
        // Mostrar snackbar de éxito
      } catch (e) {
        // Mostrar snackbar de error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'es_CO', symbol: '\$');
    final isGasto = item.type == 'Gasto';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(item.description,
                      style: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Text(
                  '${isGasto ? '-' : '+'}${currencyFormat.format(item.amount)}',
                  style: GoogleFonts.lato(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isGasto
                          ? Colors.red.shade300
                          : Colors.green.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Vence: ${DateFormat.yMMMd('es_CO').format(item.nextDueDate)}',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'snooze') _handleSnooze(context);
                    if (value == 'skip') _handleSkip(context);
                    if (value == 'edit') {/* Navegar a editar */}
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'snooze',
                        child: ListTile(
                            leading: Icon(Iconsax.clock),
                            title: Text('Posponer'))),
                    const PopupMenuItem(
                        value: 'skip',
                        child: ListTile(
                            leading: Icon(Iconsax.next),
                            title: Text('Omitir este mes'))),
                    const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                            leading: Icon(Iconsax.edit),
                            title: Text('Editar Gasto Fijo'))),
                  ],
                  child: const Text("Opciones"),
                ),
                FilledButton.tonal(
                  onPressed: () => _handlePay(context),
                  child: const Text('Pagar ahora'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
