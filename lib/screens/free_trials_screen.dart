import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/data/free_trial_repository.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/data/dashboard_repository.dart'; 
import 'package:sasper/models/dashboard_data_model.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart'; 

import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/data/category_repository.dart'; // Si tienes categorías dinámicas
import 'package:sasper/models/account_model.dart';
import 'package:sasper/models/category_model.dart';

class _T {
  static const Color bg = Color(0xFF0A0A0F);
  static const Color surface = Color(0xFF16161E);
  static const Color accent = Color(0xFFC9A96E);
  static const Color danger = Color(0xFFFF453A);
  static const Color success = Color(0xFF30D158);
  static const Color textPrimary = Color(0xFFF0ECE4);
  static const Color textSecondary = Color(0xFF8E8E93);
}

class FreeTrialsScreen extends StatelessWidget {
  const FreeTrialsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    
    // Obtenemos los datos del Dashboard en cache para la IA
    final dashboardData = DashboardRepository.instance.currentData ?? DashboardData.empty();
    final double availableBalance = dashboardData.availableBalance;

    return Scaffold(
      backgroundColor: _T.bg,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FreeTrialRepository.instance.trialsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _T.accent));
          }

          final trials = snapshot.data ?? [];
          double totalAtRisk = trials
              .where((t) => t['is_cancelled'] == false)
              .fold(0, (sum, item) => sum + (item['future_price'] as num).toDouble());

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers:[
              SliverAppBar(
                expandedHeight: 160,
                pinned: true,
                backgroundColor: _T.bg,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  title: const Text('Pruebas Gratuitas', 
                    style: TextStyle(color: _T.textPrimary, fontWeight: FontWeight.w800, fontSize: 22)),
                  background: Container(color: _T.bg),
                ),
                actions:[
                  IconButton(
                    icon: const Icon(Iconsax.add_circle, color: _T.accent, size: 28),
                    onPressed: () => _showTrialSheet(context),
                  ),
                  const SizedBox(width: 10),
                ],
              ),
              
              if (trials.isNotEmpty)
                SliverToBoxAdapter(
                  child: _AIBriefing(totalAtRisk: totalAtRisk, fmt: fmt)
                      .animate().fadeIn().slideY(begin: 0.1),
                ),

              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: trials.isEmpty 
                  ? const SliverFillRemaining(child: _EmptyState())
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _TrialCard(
                          data: trials[index],
                          fmt: fmt,
                          availableBalance: availableBalance, // 👈 Pasamos el saldo a la tarjeta
                          onEdit: () => _showTrialSheet(context, editItem: trials[index]),
                          onDelete: () => _confirmDelete(context, trials[index]),
                          onConvert: () => _showConvertToRecurringSheet(context, trials[index]),
                        ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.05),
                        childCount: trials.length,
                      ),
                    ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  // --- LÓGICA DE ELIMINACIÓN ---
  void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _T.surface,
        title: const Text('¿Eliminar prueba?', style: TextStyle(color: Colors.white)),
        content: Text('Se borrará el seguimiento de ${item['service_name']}.', style: const TextStyle(color: _T.textSecondary)),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await FreeTrialRepository.instance.deleteTrial(item['id']);              
              await widget_service.WidgetService.updateNextPaymentWidget();
              await widget_service.WidgetService.updateUpcomingPaymentsWidget();              
              Navigator.pop(ctx);
              NotificationHelper.show(message: 'Prueba eliminada', type: NotificationType.info);
            }, 
            child: const Text('Eliminar', style: TextStyle(color: _T.danger))
          ),
        ],
      ),
    );
  }

  // --- CONVERTIR A GASTO FIJO ---
  void _showConvertToRecurringSheet(BuildContext context, Map<String, dynamic> trial) {
    // Datos pre-llenados desde la prueba
    final name = trial['service_name'];
    final amount = (trial['future_price'] as num).toDouble();
    final frequency = trial['frequency'] ?? 'mensual'; // Valor por defecto
    
    // Controladores para selección
    Account? selectedAccount;
    String selectedCategory = 'Suscripciones'; // Valor por defecto o el primero de la lista

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: _T.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Iconsax.repeat, color: _T.accent, size: 24),
                const SizedBox(width: 12),
                const Text('Convertir a Gasto Fijo', 
                  style: TextStyle(color: _T.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
              ]),
              const SizedBox(height: 8),
              Text('Convertir "$name" en un pago recurrente automático.', 
                style: const TextStyle(color: _T.textSecondary, fontSize: 13)),
              
              const SizedBox(height: 24),

              // 1. Selector de Cuenta (Obligatorio)
              const Text('¿De qué cuenta se paga?', style: TextStyle(color: _T.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              FutureBuilder<List<Account>>(
                future: AccountRepository.instance.getAccounts(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator(color: _T.accent);
                  
                  final accounts = snapshot.data!;
                  if (selectedAccount == null && accounts.isNotEmpty) {
                    // Auto-seleccionar la primera cuenta
                    selectedAccount = accounts.first;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Account>(
                        value: selectedAccount,
                        isExpanded: true,
                        dropdownColor: _T.surface,
                        style: const TextStyle(color: Colors.white),
                        items: accounts.map((acc) => DropdownMenuItem(
                          value: acc,
                          child: Row(children: [
                            Icon(acc.icon, size: 16, color: _T.textSecondary),
                            const SizedBox(width: 8),
                            Text(acc.name),
                          ]),
                        )).toList(),
                        onChanged: (val) => setSheetState(() => selectedAccount = val),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 2. Selector de Categoría (Simplificado)
              const Text('Categoría', style: TextStyle(color: _T.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Aquí podrías usar tu CategoryRepository si quieres, por ahora uso un dropdown simple
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    dropdownColor: _T.surface,
                    style: const TextStyle(color: Colors.white),
                    items: ['Suscripciones', 'Entretenimiento', 'Educación', 'Software', 'Servicios']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setSheetState(() => selectedCategory = val!),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Botón de Acción
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.success, // Verde para indicar "Aprobado"
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  if (selectedAccount == null) return;
                  HapticFeedback.heavyImpact();
                  
                  try {
                    // 1. Crear el Gasto Fijo
                    await RecurringRepository.instance.addRecurringTransaction(
                      description: name,
                      amount: amount,
                      type: 'Gasto',
                      category: selectedCategory,
                      accountId: selectedAccount!.id,
                      frequency: frequency, // Heredamos la frecuencia de la prueba
                      interval: 1,
                      startDate: DateTime.now(), // Empieza hoy
                    );

                    // 2. Borrar la Prueba Gratuita (Ya no es necesaria)
                    await FreeTrialRepository.instance.deleteTrial(trial['id']);
                    
                    // 3. Limpiar notificaciones
                    await NotificationService.instance.cancelTrialReminder(trial['id']);
                    // Refrescar ambos widgets para asegurar sincronía
                    await widget_service.WidgetService.updateNextPaymentWidget();
                    await widget_service.WidgetService.updateUpcomingPaymentsWidget();

                    if (context.mounted) {
                      Navigator.pop(ctx); // Cerrar sheet
                      NotificationHelper.show(
                        message: '¡$name es ahora un gasto fijo!', 
                        type: NotificationType.success
                      );
                    }
                  } catch (e) {
                    NotificationHelper.show(message: 'Error al convertir', type: NotificationType.error);
                  }
                },
                child: const Text('Confirmar y Convertir', 
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- FORMULARIO DE CREACIÓN / EDICIÓN ---
  void _showTrialSheet(BuildContext context, {Map<String, dynamic>? editItem}) async {
    // Leemos el ingreso mensual en tiempo real para hacer el cálculo de IA en el form
    final dashboardData = DashboardRepository.instance.currentData ?? DashboardData.empty();
    final monthlyIncome = dashboardData.monthlyIncome > 0 ? dashboardData.monthlyIncome : 1.0; // Evitar división por 0

    TimeOfDay selectedTime = editItem != null 
    ? TimeOfDay(
        hour: int.parse(editItem['notification_time'].split(':')[0]),
        minute: int.parse(editItem['notification_time'].split(':')[1]))
    : const TimeOfDay(hour: 9, minute: 0);

    final nameCtrl = TextEditingController(text: editItem?['service_name']);
    final priceCtrl = TextEditingController(text: editItem?['future_price']?.toString());
    String selectedFrequency = editItem?['frequency'] ?? 'mensual'; // 👈 FRECUENCIA

    DateTime selectedDate = editItem != null 
        ? DateTime.parse(editItem['end_date']) 
        : DateTime.now().add(const Duration(days: 7));

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          
          // --- CÁLCULO DE IA EN VIVO ---
          double parsedPrice = double.tryParse(priceCtrl.text) ?? 0.0;
          double annualCost = selectedFrequency == 'mensual' ? parsedPrice * 12 : parsedPrice;
          double percentageOfIncome = (annualCost / (monthlyIncome * 12)) * 100;
          final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
            decoration: const BoxDecoration(color: _T.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                Text(editItem == null ? 'Nueva Prueba' : 'Editar Detalles', 
                  style: const TextStyle(color: _T.accent, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Nombre del servicio'),
                ),
                const SizedBox(height: 16),
                
                // Selector de Frecuencia
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedFrequency,
                      isExpanded: true,
                      dropdownColor: _T.surface,
                      style: const TextStyle(color: Colors.white),
                      items: const[
                        DropdownMenuItem(value: 'diario', child: Text('Diario')),
                        DropdownMenuItem(value: 'semanal', child: Text('Semanal')),
                        DropdownMenuItem(value: 'quincenal', child: Text('Quincenal')),
                        DropdownMenuItem(value: 'mensual', child: Text('Mensual')),
                        DropdownMenuItem(value: 'anual', child: Text('Anual')),
                      ],
                      onChanged: (val) => setModalState(() => selectedFrequency = val!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('Precio tras la prueba'),
                  onChanged: (val) => setModalState(() {}), // 👈 Recalcula la IA al escribir
                ),
                const SizedBox(height: 16),

                // --- TARJETA IA EN EL FORMULARIO ---
                if (parsedPrice > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: _T.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _T.accent.withOpacity(0.3))),
                    child: Row(
                      children:[
                        const Icon(Iconsax.magic_star, color: _T.accent, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Si te quedas, te costará ${fmt.format(annualCost)} al año. Representa el ${percentageOfIncome.toStringAsFixed(1)}% de tu ingreso anual.',
                            style: const TextStyle(color: _T.accent, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Finaliza el', style: TextStyle(color: _T.textSecondary, fontSize: 14)),
                  subtitle: Text(DateFormat('dd MMMM, yyyy', 'es_CO').format(selectedDate), 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Iconsax.calendar, color: _T.accent),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (date != null) setModalState(() => selectedDate = date);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hora del recordatorio', style: TextStyle(color: _T.textSecondary, fontSize: 14)),
                  subtitle: Text(selectedTime.format(context), 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Iconsax.clock, color: _T.accent),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (time != null) setModalState(() => selectedTime = time);
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _T.accent,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async { 
                    final timeStr = "${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}";

                    if (nameCtrl.text.isEmpty || priceCtrl.text.isEmpty) return;
                    HapticFeedback.mediumImpact();
                    
                    final price = double.parse(priceCtrl.text);

                    if (editItem == null) {
                      final newTrial = await FreeTrialRepository.instance.addTrial(
                        nameCtrl.text, selectedDate, price, timeStr, selectedFrequency // 👈 FRECUENCIA
                      );
                      
                      await NotificationService.instance.scheduleFreeTrialReminder(
                        id: newTrial['id'], 
                        serviceName: nameCtrl.text,
                        endDate: selectedDate,
                        price: price,
                        notificationTime: selectedTime,
                      );
                    } else {
                      await FreeTrialRepository.instance.updateTrial(
                        editItem['id'], nameCtrl.text, selectedDate, price, timeStr, selectedFrequency
                      );
                      
                      await NotificationService.instance.scheduleFreeTrialReminder(
                        id: editItem['id'],
                        serviceName: nameCtrl.text,
                        endDate: selectedDate,
                        price: price,
                        notificationTime: selectedTime,
                      );
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(editItem == null ? 'Crear Seguimiento' : 'Guardar Cambios', 
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.white24),
    filled: true,
    fillColor: Colors.white.withOpacity(0.05),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
  );
}

class _TrialCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onConvert;
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final double availableBalance;

  const _TrialCard({
    required this.data, 
    required this.fmt, 
    required this.onEdit, 
    required this.onDelete,
    required this.availableBalance,
    required this.onConvert, // 👈 Se inyecta aquí
  });

  @override
  Widget build(BuildContext context) {
    final endDate = DateTime.parse(data['end_date']);
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    final isCancelled = data['is_cancelled'] ?? false;
    final isUrgent = daysLeft <= 3 && !isCancelled;
    final color = isCancelled ? _T.success : (isUrgent ? _T.danger : _T.accent);
    final price = (data['future_price'] as num).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _T.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: color.withOpacity(0.2))
      ),
      child: Column(
        children:[
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(Iconsax.video_play, color: color),
            ),
            title: Text(data['service_name'], 
              style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text('Cobrará: ${fmt.format(price)}', 
              style: const TextStyle(color: _T.textSecondary, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children:[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children:[
                    Text(isCancelled ? 'Listo' : '$daysLeft d', 
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18)),
                    Text(isCancelled ? 'Cancelado' : 'restantes', 
                      style: const TextStyle(color: _T.textSecondary, fontSize: 10)),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: _T.textSecondary),
                  color: _T.surface,
                  onSelected: (val) {
                     if (val == 'convert') { // 👈 NUEVA OPCIÓN
                      // Necesitamos llamar a la función que está en el widget padre.
                      // Opción A: Pasar la función por callback
                      // Opción B (Rápida): Si _showConvertToRecurringSheet está en el estado, 
                      // pasar el context y buscarlo, pero mejor pasemos un callback nuevo.
                      onConvert(); 
                    }
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) =>[
                    const PopupMenuItem(
                      value: 'convert', 
                      child: Row(children: [
                        Icon(Iconsax.repeat, color: _T.success, size: 18),
                        SizedBox(width: 10),
                        Text('Convertir a Gasto Fijo', style: TextStyle(color: _T.success)),
                      ])
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: _T.danger))),
                  ],
                ),
              ],
            ),
          ),
          
          // --- ALERTA DE IA: IMPACTO EN EL SALDO ---
          if (!isCancelled && daysLeft >= 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _T.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)
              ),
              child: Row(
                children:[
                  const Icon(Iconsax.warning_2, color: _T.danger, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Si no cancelas, en $daysLeft días tu saldo bajará a ${fmt.format(availableBalance - price)}',
                      style: const TextStyle(color: _T.danger, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: color.withOpacity(0.05), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () async {
                  final isCurrentlyCancelled = data['is_cancelled'] ?? false;
                  final newStatus = !isCurrentlyCancelled;
                  
                  await FreeTrialRepository.instance.toggleCancel(data['id'], isCurrentlyCancelled);
                  await widget_service.WidgetService.updateNextPaymentWidget();
                  
                  if (newStatus) { 
                    await NotificationService.instance.cancelTrialReminder(data['id']);
                    NotificationHelper.show(message: 'Recordatorio cancelado', type: NotificationType.info);
                  } else {
                    final timeParts = (data['notification_time'] as String? ?? '09:00').split(':');
                    final timeOfDay = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
                    
                    await NotificationService.instance.scheduleFreeTrialReminder(
                      id: data['id'],
                      serviceName: data['service_name'],
                      endDate: DateTime.parse(data['end_date']),
                      price: price,
                      notificationTime: timeOfDay, 
                    );
                    NotificationHelper.show(message: 'Seguimiento reactivado', type: NotificationType.success);
                  }
                },
                child: Text(isCancelled ? 'Reactivar Seguimiento' : 'Ya cancelé el servicio', 
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children:[
        Icon(Iconsax.timer_1, size: 64, color: Colors.white10),
        SizedBox(height: 16),
        Text('No hay pruebas activas', style: TextStyle(color: _T.textSecondary, fontSize: 16)),
      ],
    );
  }
}

class _AIBriefing extends StatelessWidget {
  final double totalAtRisk;
  final NumberFormat fmt;
  const _AIBriefing({required this.totalAtRisk, required this.fmt});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: _T.accent.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: _T.accent.withOpacity(0.2))),
      child: Row(
        children:[
          const Icon(Iconsax.magic_star5, color: _T.accent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('RIESGO DE COBRO', style: TextStyle(color: _T.accent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                Text(fmt.format(totalAtRisk), style: const TextStyle(color: _T.textPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                const Text('Si no cancelas hoy.', style: TextStyle(color: _T.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}