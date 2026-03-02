// lib/screens/pending_payments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:sasper/data/recurring_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/recurring_transaction_model.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/widget_service.dart' as widget_service;
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PendingPaymentsScreen extends StatelessWidget {
  const PendingPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Colors.black : const Color(0xFFF2F2F7);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers:[
          // --- AppBar ---
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: bg,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              centerTitle: false,
              title: Text(
                'Pagos Pendientes',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // --- Lista Combinada (Gastos Fijos + Cuotas + Cuota Manejo) ---
          FutureBuilder<List<Account>>(
            future: AccountRepository.instance.getAccounts(),
            builder: (context, accSnap) {
              return StreamBuilder<List<RecurringTransaction>>(
                stream: RecurringRepository.instance.getRecurringTransactionsStream(),
                builder: (context, recSnap) {
                  return StreamBuilder<List<Transaction>>(
                    stream: TransactionRepository.instance.getTransactionsStream(),
                    builder: (context, txSnap) {
                      
                      // Si alguno está cargando
                      if (recSnap.connectionState == ConnectionState.waiting) {
                        return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                      }

                      // Obtenemos las listas seguras
                      final accounts = accSnap.data ?? [];
                      final recurring = recSnap.data ??[];
                      final transactions = txSnap.data ??[];

                      // 1. Filtrar Gastos Fijos (Vencidos o que vencen en próximos 3 días)
                      final now = DateTime.now();
                      final pendingRecurring = recurring.where((tx) {
                        return tx.nextDueDate.isBefore(now.add(const Duration(days: 3)));
                      }).toList();

                      // 2. Filtrar Compras a Cuotas Activas
                      final activeInstallments = transactions.where((tx) {
                        return tx.isInstallment == true && 
                               tx.installmentsCurrent != null && 
                               tx.installmentsTotal != null && 
                               tx.installmentsCurrent! <= tx.installmentsTotal!;
                      }).toList();

                      // 3. Generar la lista de Widgets
                      final pendingWidgets = _buildSmartPendingList(
                        pendingRecurring, 
                        activeInstallments, 
                        accounts
                      );

                      if (pendingWidgets.isEmpty) {
                        return const _EmptyState();
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate(pendingWidgets),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // --- LÓGICA DE UNIFICACIÓN ---
  List<Widget> _buildSmartPendingList(
    List<RecurringTransaction> recurring, 
    List<Transaction> installments, 
    List<Account> accounts
  ) {
    List<Widget> list =[];

    // 1. Cuotas de Manejo (Las ponemos primero porque son del banco)
    for (var acc in accounts) {
      if (acc.type == 'Tarjeta de Crédito' && acc.maintenanceFee > 0) {
        list.add(_MaintenanceFeeCard(account: acc));
      }
    }

    // 2. Cuotas de Tarjeta de Crédito (Compras)
    for (var tx in installments) {
      list.add(_InstallmentPendingCard(tx: tx, accounts: accounts));
    }

    // 3. Gastos Fijos (Netflix, Gimnasio, etc.)
    for (var rx in recurring) {
      list.add(_PendingCard(tx: rx)); 
    }

    return list;
  }
}

// =======================================================================
// WIDGET 1: GASTOS FIJOS (El que ya teníamos)
// =======================================================================
class _PendingCard extends StatelessWidget {
  final RecurringTransaction tx;
  const _PendingCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOverdue = tx.nextDueDate.isBefore(DateTime.now());
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.transparent),
      ),
      child: Column(
        children:[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children:[
                Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: (isOverdue ? Colors.red : Colors.orange).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(isOverdue ? Iconsax.warning_2 : Iconsax.clock, color: isOverdue ? Colors.red : Colors.orange, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Vence: ${DateFormat('d MMM', 'es_CO').format(tx.nextDueDate)}', style: TextStyle(color: isOverdue ? Colors.red : Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                Text(fmt.format(tx.amount), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children:[
                Expanded(
                  child: _ActionButton(
                    label: 'Confirmar', icon: Iconsax.tick_circle, color: Colors.green,
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await RecurringRepository.instance.processPayment(tx.id);
                      // 👉 Actualizamos widgets después de cambiar datos
                      await widget_service.WidgetService.updateNextPaymentWidget();
                      await widget_service.WidgetService.updateUpcomingPaymentsWidget();
                      NotificationHelper.show(message: 'Pago registrado', type: NotificationType.success);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Omitir', icon: Iconsax.arrow_right_1, color: Colors.grey,
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await RecurringRepository.instance.skipPayment(tx.id);
                    await widget_service.WidgetService.updateNextPaymentWidget();
                    await widget_service.WidgetService.updateUpcomingPaymentsWidget();
                    NotificationHelper.show(message: 'Saltado al próximo mes', type: NotificationType.info);
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// =======================================================================
// WIDGET 2: CUOTAS DE COMPRAS (Nuevo)
// =======================================================================
class _InstallmentPendingCard extends StatelessWidget {
  final Transaction tx;
  final List<Account> accounts;
  const _InstallmentPendingCard({required this.tx, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    
    // Calculamos los valores
    final cuotaValue = tx.amount.abs() / tx.installmentsTotal!;
    final cuotasRestantes = (tx.installmentsTotal! - tx.installmentsCurrent!) + 1;
    final remainingTotalValue = cuotaValue * cuotasRestantes;
    
    final card = accounts.firstWhere((a) => a.id == tx.creditCardId, orElse: () => Account.empty());

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children:[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
            child: Row(
              children:[
                Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Iconsax.card, color: Colors.blue, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:[
                      Text(tx.description ?? 'Compra a cuotas', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Cuota ${tx.installmentsCurrent} de ${tx.installmentsTotal}  •  ${card.name}', style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children:[
                        Text(fmt.format(cuotaValue), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                          onPressed: () => _showInstallmentOptions(context, cuotaValue, remainingTotalValue),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children:[
                Expanded(
                  child: _ActionButton(
                    label: 'Pagar Cuota',
                    icon: Iconsax.tick_circle,
                    color: Colors.blue,
                    onTap: () {
                      _showPaymentSourcePicker(
                        context: context, 
                        title: "Pagar cuota de ${fmt.format(cuotaValue)}",
                        amount: cuotaValue,
                        onAccountSelected: (acc) async {
                          // Pago normal de 1 cuota
                          await TransactionRepository.instance.payInstallment(
                            originalTransaction: tx,
                            paymentSourceAccountId: acc.id,
                          );
                        }
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- MENÚ DE OPCIONES DE LA VIDA REAL ---
  void _showInstallmentOptions(BuildContext context, double cuotaValue, double remainingTotal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children:[
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          
          // 1. Pagar TODO lo que falta (Adelantar cuotas)
          ListTile(
            leading: const Icon(Iconsax.flash_1, color: Colors.green),
            title: const Text('Adelantar todas las cuotas', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Pagar totalidad: ${fmt.format(remainingTotal)}', style: const TextStyle(color: Colors.green)),
            onTap: () {
              Navigator.pop(ctx);
              _showPaymentSourcePicker(
                context: context, 
                title: "Pagar totalidad de ${fmt.format(remainingTotal)}", 
                amount: remainingTotal, 
                onAccountSelected: (acc) async {
                  // Creamos el gasto por el total restante
                  await TransactionRepository.instance.addTransaction(
                    accountId: acc.id,
                    amount: -remainingTotal,
                    type: 'Gasto',
                    category: tx.category ?? 'Pago Tarjeta',
                    description: 'Pago total anticipado: ${tx.description}',
                    transactionDate: DateTime.now(),
                  );
                  // Marcamos la transacción original como "terminada" (Current > Total)
await TransactionRepository.instance.updateInstallmentProgress(
  transactionId: tx.id,
  currentInstallment: tx.installmentsTotal! + 1, // Superar el total la da por pagada
  totalInstallments: tx.installmentsTotal!,
);
                  // Refrescar widgets
                  await widget_service.WidgetService.updateNextPaymentWidget();
                  await widget_service.WidgetService.updateUpcomingPaymentsWidget();
                  
                  NotificationHelper.show(message: '¡Deuda saldada por completo!', type: NotificationType.success);
                }
              );
            },
          ),
          const Divider(height: 1),

          // 2. Editar Progreso (Me equivoqué de cuota)
          ListTile(
            leading: const Icon(Iconsax.edit, color: Colors.blue),
            title: const Text('Ajustar progreso de cuotas'),
            subtitle: const Text('Cambiar en qué cuota vas', style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              Navigator.pop(ctx);
              _showEditProgressSheet(context);
            },
          ),
          const Divider(height: 1),

          // 3. Eliminar Compra
          ListTile(
            leading: const Icon(Iconsax.trash, color: Colors.red),
            title: const Text('Eliminar compra', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            subtitle: const Text('Borrará esta deuda para siempre', style: TextStyle(color: Colors.grey, fontSize: 12)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDelete(context);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // --- DIÁLOGO PARA EDITAR EL PROGRESO ---
  void _showEditProgressSheet(BuildContext context) {
    int tempCurrent = tx.installmentsCurrent!;
    int tempTotal = tx.installmentsTotal!;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
            title: const Text('Ajustar Cuotas'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    const Text('Cuota actual:'),
                    Row(
                      children:[
                        IconButton(onPressed: () => setStateDialog(() { if(tempCurrent > 1) tempCurrent--; }), icon: const Icon(Icons.remove_circle_outline, color: Colors.blue)),
                        Text('$tempCurrent', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setStateDialog(() { if(tempCurrent < tempTotal) tempCurrent++; }), icon: const Icon(Icons.add_circle_outline, color: Colors.blue)),
                      ],
                    )
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children:[
                    const Text('Total cuotas:'),
                    Row(
                      children:[
                        IconButton(onPressed: () => setStateDialog(() { if(tempTotal > tempCurrent) tempTotal--; }), icon: const Icon(Icons.remove_circle_outline, color: Colors.grey)),
                        Text('$tempTotal', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        IconButton(onPressed: () => setStateDialog(() { tempTotal++; }), icon: const Icon(Icons.add_circle_outline, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
              ],
            ),
            actions:[
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  HapticFeedback.mediumImpact();
                  await TransactionRepository.instance.updateInstallmentProgress(
  transactionId: tx.id,
  currentInstallment: tempCurrent,
  totalInstallments: tempTotal,
);
                  // Refrescar widgets cuando ajusta cuotas
                  await widget_service.WidgetService.updateNextPaymentWidget();
                  await widget_service.WidgetService.updateUpcomingPaymentsWidget();
                  NotificationHelper.show(message: 'Progreso actualizado', type: NotificationType.success);
                }, 
                child: const Text('Guardar', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
              ),
            ],
          );
        }
      ),
    );
  }

  // --- DIÁLOGO DE ELIMINACIÓN ---
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
        title: const Text('¿Eliminar compra?'),
        content: Text('Se eliminará la compra "${tx.description}" y dejará de aparecer en tus pagos pendientes.'),
        actions:[
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.heavyImpact();
              await TransactionRepository.instance.deleteTransaction(tx.id);
              // Refrescar widgets al eliminar compra
              await widget_service.WidgetService.updateNextPaymentWidget();
              await widget_service.WidgetService.updateUpcomingPaymentsWidget();
              NotificationHelper.show(message: 'Compra eliminada', type: NotificationType.info);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // --- SELECTOR DE CUENTA GENÉRICO (Sirve para cuota normal y total) ---
  void _showPaymentSourcePicker({
    required BuildContext context, 
    required String title, 
    required double amount, 
    required Function(Account) onAccountSelected
  }) {
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children:[
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text("¿Desde qué cuenta sale el dinero?", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            
            // Lista de cuentas
            ...accounts.where((a) => a.type != 'Tarjeta de Crédito').map((acc) {
              return ListTile(
                leading: Icon(acc.icon, color: acc.accountColor),
                title: Text(acc.name),
                subtitle: Text(fmt.format(acc.balance)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  onAccountSelected(acc);
                },
              );
            }).toList(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
void _showPaymentSourcePicker(BuildContext context, Transaction tx, List<Account> accounts) {
  final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final installmentValue = tx.amount.abs() / tx.installmentsTotal!;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Text("Pagar cuota de ${fmt.format(installmentValue)}", 
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          const Text("¿Desde qué cuenta sale el dinero?", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          
          // Lista de cuentas (excluyendo tarjetas de crédito, porque no pagas deuda con deuda)
          ...accounts.where((a) => a.type != 'Tarjeta de Crédito').map((acc) {
            return ListTile(
              leading: Icon(acc.icon, color: acc.accountColor),
              title: Text(acc.name),
              subtitle: Text(fmt.format(acc.balance)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                Navigator.pop(ctx); // Cerrar modal
                try {
                  HapticFeedback.mediumImpact();
                  // LLAMAR AL NUEVO MÉTODO DEL REPOSITORIO
                  await TransactionRepository.instance.payInstallment(
                    originalTransaction: tx,
                    paymentSourceAccountId: acc.id,
                  );
                  // actualizar widgets después de pagar cuota
                  await widget_service.WidgetService.updateNextPaymentWidget();
                  await widget_service.WidgetService.updateUpcomingPaymentsWidget();
                  NotificationHelper.show(message: '¡Cuota registrada con éxito!', type: NotificationType.success);
                } catch (e) {
                  NotificationHelper.show(message: 'Error al pagar: $e', type: NotificationType.error);
                }
              },
            );
          }).toList(),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

// =======================================================================
// WIDGET 3: CUOTA DE MANEJO (Nuevo)
// =======================================================================
class _MaintenanceFeeCard extends StatelessWidget {
  final Account account;
  const _MaintenanceFeeCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fmt = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children:[
          Container(
            width: 45, height: 45,
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Iconsax.bank, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                Text('Cuota de Manejo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(account.name, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          Text(fmt.format(account.maintenanceFee), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        ],
      ),
    );
  }
}

// --- WIDGET AUXILIAR ---
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children:[
          Icon(Iconsax.copy_success, size: 80, color: Colors.green.withOpacity(0.3)),
          const SizedBox(height: 20),
          const Text(
            '¡Todo al día!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('No tienes pagos pendientes por confirmar.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}