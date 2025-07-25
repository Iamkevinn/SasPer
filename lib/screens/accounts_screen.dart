// lib/screens/accounts_screen.dart (COMPLETO Y CORREGIDO)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
// Añade estos imports al inicio del archivo
import 'dart:ui';
import 'package:sasper/screens/edit_account_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

import 'account_details_screen.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'add_account_screen.dart';
import 'add_transfer_screen.dart';
import 'package:sasper/widgets/accounts/projection_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';

class AccountsScreen extends StatefulWidget {
  // Recibe las dependencias, no crea las suyas.
  final AccountRepository repository;
  final TransactionRepository transactionRepository;

  const AccountsScreen({
    super.key,
    required this.repository,
    required this.transactionRepository,
  });

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
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
    // Usamos el repositorio que llega a través del widget.
    _accountsStream = widget.repository.getAccountsWithBalanceStream();
  }

  Future<void> _handleRefresh() async {
    await widget.repository.forceRefresh();
  }

  void _navigateToAddTransfer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddTransferScreen(accountRepository: widget.repository),
      ),
    );
  }

  void _navigateToAddAccount() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddAccountScreen(accountRepository: widget.repository),
      ),
    );
  }

  // ---- NUEVA FUNCIÓN PARA NAVEGAR A EDITAR ----
  void _navigateToEditAccount(Account account) {
    Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => EditAccountScreen(
          accountRepository: widget.repository,
          account: account,
        ),
      ),
    ).then((changed) {
      // Si la pantalla de edición devuelve 'true', es una señal de que hubo un cambio.
      // Aunque el stream ya lo hace, una actualización forzada es más rápida.
      if (changed == true) {
        widget.repository.forceRefresh();
      }
    });
  }

  // ---- NUEVA FUNCIÓN PARA MANEJAR EL BORRADO ----
  Future<void> _handleDeleteAccount(Account account) async {
    // Primera validación en la UI para feedback instantáneo
    if (account.balance != 0) {
      NotificationHelper.show(
        context: context,
        message: 'No se puede eliminar. La cuenta aún tiene saldo.',
        type: NotificationType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          title: const Text('Confirmar eliminación'),
          content: Text('¿Seguro que quieres eliminar la cuenta "${account.name}"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await widget.repository.deleteAccountSafely(account.id);
        NotificationHelper.show(
          context: context,
          message: 'Cuenta eliminada.',
          type: NotificationType.success,
        );
      } catch (e) {
        NotificationHelper.show(
          context: context,
          message: e.toString(), // El repositorio ya formatea el mensaje de error
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
                          future: widget.repository.getAccountProjectionInDays(account.id),
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

  // ---- MODIFICAMOS EL WIDGET _buildAccountTile ----
  Widget _buildAccountTile(Account account) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) => AccountDetailsScreen(
              account: account,
              accountRepository: widget.repository,
              transactionRepository: widget.transactionRepository,
            ),
          ));
        },
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 8, 12), // Reducimos padding derecho
          leading: Icon(_accountIcons[account.type] ?? _accountIcons['default'], size: 30, color: Theme.of(context).colorScheme.primary),
          title: Text(account.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          subtitle: Text(account.type),
          trailing: Row( // Usamos un Row para el saldo y el menú
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
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(leading: Icon(Iconsax.edit), title: Text('Editar')),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(leading: Icon(Iconsax.trash), title: Text('Eliminar')),
                  ),
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

  /// --- MÉTODO CORREGIDO ---
  /// Este widget crea una animación de carga (shimmer) que imita la
  /// apariencia de la lista de cuentas, proporcionando una mejor experiencia de usuario.
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shimmer para el Tile de la cuenta (más alto)
              Container(
                height: 82, // Altura similar a la del ListTile
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(16)),
                ),
              ),
              // Shimmer para la tarjeta de proyección (más corto)
              // No lo añadimos para que no se vea el hueco si no hay proyección
            ],
          ),
        ),
      ),
    );
  }
}