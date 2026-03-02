import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/data/free_trial_repository.dart';
import 'package:sasper/services/notification_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

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
            slivers: [
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
                actions: [
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
                          onEdit: () => _showTrialSheet(context, editItem: trials[index]),
                          onDelete: () => _confirmDelete(context, trials[index]),
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
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await FreeTrialRepository.instance.deleteTrial(item['id']);
              Navigator.pop(ctx);
              NotificationHelper.show(message: 'Prueba eliminada', type: NotificationType.info);
            }, 
            child: const Text('Eliminar', style: TextStyle(color: _T.danger))
          ),
        ],
      ),
    );
  }

  // --- FORMULARIO DE CREACIÓN / EDICIÓN ---
  void _showTrialSheet(BuildContext context, {Map<String, dynamic>? editItem}) {
    TimeOfDay selectedTime = editItem != null 
    ? TimeOfDay(
        hour: int.parse(editItem['notification_time'].split(':')[0]),
        minute: int.parse(editItem['notification_time'].split(':')[1]))
    : const TimeOfDay(hour: 9, minute: 0);

    final nameCtrl = TextEditingController(text: editItem?['service_name']);
    final priceCtrl = TextEditingController(text: editItem?['future_price']?.toString());
    DateTime selectedDate = editItem != null 
        ? DateTime.parse(editItem['end_date']) 
        : DateTime.now().add(const Duration(days: 7));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          decoration: const BoxDecoration(color: _T.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(editItem == null ? 'Nueva Prueba' : 'Editar Detalles', 
                style: const TextStyle(color: _T.accent, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Nombre del servicio'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDeco('Precio tras la prueba'),
              ),
              const SizedBox(height: 16),
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
  // 1. Guardamos el resultado del repositorio en la variable 'newTrial'
  final newTrial = await FreeTrialRepository.instance.addTrial(
    nameCtrl.text, 
    selectedDate, 
    price,
    timeStr,
  );
  
  // 2. Ahora 'newTrial' ya existe y podemos usar su ID real
  await NotificationService.instance.scheduleFreeTrialReminder(
    id: newTrial['id'], // 👈 Ya no dará error de "Undefined name"
    serviceName: nameCtrl.text,
    endDate: selectedDate,
    price: price,
    notificationTime: selectedTime,
  );
} else {
    // Actualizar en BD
    await FreeTrialRepository.instance.updateTrial(
      editItem['id'], 
      nameCtrl.text, 
      selectedDate, 
      price,
      timeStr,
    );
    
    // RE-PROGRAMAR NOTIFICACIÓN (esto sobreescribe la anterior con el mismo ID)
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
        ),
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
  final NumberFormat fmt;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TrialCard({required this.data, required this.fmt, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final endDate = DateTime.parse(data['end_date']);
    final daysLeft = endDate.difference(DateTime.now()).inDays;
    final isCancelled = data['is_cancelled'] ?? false;
    final isUrgent = daysLeft <= 3 && !isCancelled;
    final color = isCancelled ? _T.success : (isUrgent ? _T.danger : _T.accent);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _T.surface, 
        borderRadius: BorderRadius.circular(24), 
        border: Border.all(color: color.withOpacity(0.2))
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(Iconsax.video_play, color: color),
            ),
            title: Text(data['service_name'], 
              style: const TextStyle(color: _T.textPrimary, fontWeight: FontWeight.bold)),
            subtitle: Text('Cobrará: ${fmt.format(data['future_price'])}', 
              style: const TextStyle(color: _T.textSecondary, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
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
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar', style: TextStyle(color: Colors.white))),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar', style: TextStyle(color: _T.danger))),
                  ],
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
  final isCancelled = data['is_cancelled'] ?? false;
  
  await FreeTrialRepository.instance.toggleCancel(data['id'], isCancelled);
  
  if (!isCancelled) { 
    // Si se acaba de marcar como cancelado (isCancelled era false)
    await NotificationService.instance.cancelTrialReminder(data['id']);
    NotificationHelper.show(message: 'Recordatorio cancelado', type: NotificationType.info);
  } else {
        // 1. Leemos la hora guardada de la base de datos
    final timeParts = (data['notification_time'] as String? ?? '09:00').split(':');
    final timeOfDay = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
    // Si se reactivó, volver a programar
    await NotificationService.instance.scheduleFreeTrialReminder(
      id: data['id'],
      serviceName: data['service_name'],
      endDate: DateTime.parse(data['end_date']),
      price: (data['future_price'] as num).toDouble(),
      notificationTime: timeOfDay, 
    );
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
      children: [
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
        children: [
          const Icon(Iconsax.magic_star5, color: _T.accent, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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