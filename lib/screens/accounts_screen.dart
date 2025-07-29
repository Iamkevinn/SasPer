// lib/screens/accounts_screen.dart (VERSIÓN FINAL COMPLETA USANDO SINGLETONS)

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/screens/add_account_screen.dart';
import 'package:sasper/screens/add_transfer_screen.dart';
import 'package:sasper/screens/account_details_screen.dart';
import 'package:sasper/screens/edit_account_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/accounts/projection_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/main.dart';

class AccountsScreen extends StatefulWidget {
  // Los repositorios ya no se pasan en el constructor.
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final AccountRepository _accountRepository = AccountRepository.instance;

  late final Stream<List<Account>> _accountsStream;

  final Map<String, IconData> _accountIcons = {
    'Efectivo': Iconsax.money_3,
    'Cuenta Bancaria': Iconsax.building_4,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros': Iconsax.safe_home,
    'Inversión': Iconsax.chart_1,
    'default': Iconsax.wallet_3,
  };

  @override
  void initState() {
    super.initState();
    // Obtenemos el stream del repositorio singleton.
    _accountsStream = _accountRepository.getAccountsStream();
  }

  /// El "pull to refresh" ahora llama al método de refresco del singleton.
  Future<void> _handleRefresh() async {
    await _accountRepository.refreshData();
  }

  /// Navega a la pantalla de añadir transferencia.
  void _navigateToAddTransfer() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddTransferScreen(), // Ya no necesita el repo
      ),
    );
    // Si la transferencia fue exitosa, refrescamos los datos de las cuentas.
    if (result == true && mounted) {
      _accountRepository.refreshData();
    }
  }

  /// Navega a la pantalla de añadir cuenta.
  void _navigateToAddAccount() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const AddAccountScreen(), // Ya no necesita el repo
      ),
    );
    // Si se creó una cuenta, refrescamos la lista.
    if (result == true && mounted) {
      _accountRepository.refreshData();
    }
  }
  
  /// Navega a la pantalla de edición de cuenta.
  void _navigateToEditAccount(Account account) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditAccountScreen(account: account), // Ya no necesita el repo
      ),
    );
    // Si se editó la cuenta, refrescamos la lista.
    if (result == true && mounted) {
      _accountRepository.refreshData();
    }
  }

  /// Maneja la lógica de borrado de una cuenta.
  Future<void> _handleDeleteAccount(Account account) async {
    if (account.balance != 0) {
      NotificationHelper.show(
        message: 'No se puede eliminar. La cuenta aún tiene saldo.',
        type: NotificationType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      // 1. Usamos el context del Navigator global.
      context: navigatorKey.currentContext!,
      
      // 2. Usamos 'dialogContext' para el builder.
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar la cuenta "${account.name}"? Esta acción no se puede deshacer.'),
          actions: [
            // 3. Usamos 'dialogContext' para cerrar el diálogo.
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              // 4. Usamos 'dialogContext' para obtener el tema.
              style: FilledButton.styleFrom(backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer),
              // 5. Y para cerrar el diálogo.
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _accountRepository.deleteAccountSafely(account.id);
        // El listener reactivo debería actuar, pero un "nudge" asegura inmediatez.
        _accountRepository.refreshData();

        // Disparamos el evento global para el Dashboard, etc.
        EventService.instance.fire(AppEvent.accountUpdated);

        NotificationHelper.show(
          message: 'Cuenta eliminada.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          message: e.toString().replaceFirst("Exception: ", ""),
          type: NotificationType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Mis Cuentas', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.arrow_swap_horizontal),
            tooltip: 'Nueva Transferencia',
            onPressed: _navigateToAddTransfer,
          ),
          IconButton(
            icon: const Icon(Iconsax.add_square, size: 28),
            tooltip: 'Añadir Cuenta',
            onPressed: _navigateToAddAccount,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<Account>>(
        stream: _accountsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Error al cargar cuentas:\n${snapshot.error}', textAlign: TextAlign.center)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
                child: EmptyStateCard(
              title: 'Aún no tienes cuentas',
              message: '¡Añade una para empezar a organizar tus finanzas!',
              icon: Iconsax.wallet_add_1,
              actionButton: ElevatedButton.icon(onPressed: _navigateToAddAccount, icon: const Icon(Iconsax.add), label: const Text('Añadir mi primera cuenta')),
            ));
          }
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildContent(List<Account> accounts) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 375),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAccountTile(account),
                        FutureBuilder<double>(
                          key: ValueKey(account.id),
                          // Usamos la instancia singleton para obtener la proyección
                          future: _accountRepository.getAccountProjectionInDays(account.id),
                          builder: (context, projectionSnapshot) {
                            if (projectionSnapshot.connectionState == ConnectionState.waiting) {
                              return ProjectionCard.buildShimmer(context);
                            }
                            if (projectionSnapshot.hasError || !projectionSnapshot.hasData || projectionSnapshot.data! <= 0) {
                              return const SizedBox.shrink();
                            }
                            return ProjectionCard(daysLeft: projectionSnapshot.data!);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildAccountTile(Account account) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          // La pantalla de detalles no necesita recibir los repositorios,
          // ya que también los obtendrá de las instancias singleton.
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AccountDetailsScreen(accountId: account.id),
          ));
        },
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          leading: Icon(_accountIcons[account.type] ?? _accountIcons['default'], size: 30, color: Theme.of(context).colorScheme.primary),
          title: Text(account.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          subtitle: Text(account.type),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                NumberFormat.currency(locale: 'ES_CO', symbol: '\$', decimalDigits: 0).format(account.balance),
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: account.balance < 0 ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.onSurface),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _navigateToEditAccount(account);
                  if (value == 'delete') _handleDeleteAccount(account);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Iconsax.edit), title: Text('Editar'))),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Iconsax.trash), title: Text('Eliminar'))),
                ],
                icon: const Icon(Iconsax.more),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 150),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Container(
            height: 82,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
      ),
    );
  }
}