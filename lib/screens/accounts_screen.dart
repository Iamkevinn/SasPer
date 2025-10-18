// lib/screens/accounts_screen.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/models/account_model.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/screens/add_account_screen.dart';
import 'package:sasper/screens/add_transfer_screen.dart';
import 'package:sasper/screens/account_details_screen.dart';
import 'package:sasper/screens/edit_account_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/accounts/projection_card.dart';
import 'package:sasper/main.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  final AccountRepository _accountRepository = AccountRepository.instance;
  late final Stream<List<Account>> _accountsStream;

  String _selectedFilter = 'Todas';
  bool _showArchived = false;
  final List<String> _filterOptions = [
    'Todas',
    'Efectivo',
    'Bancarias',
    'Crédito',
    'Ahorros'
  ];

  final Map<String, IconData> _accountIcons = {
    'Efectivo': Iconsax.money_3,
    'Cuenta Bancaria': Iconsax.building_4,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros': Iconsax.safe_home,
    'Inversión': Iconsax.chart_1,
    'default': Iconsax.wallet_3,
  };

  final Map<String, Color> _accountColors = {
    'Efectivo': Colors.green,
    'Cuenta Bancaria': Colors.blue,
    'Tarjeta de Crédito': Colors.purple,
    'Ahorros': Colors.orange,
    'Inversión': Colors.teal,
    'default': Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _accountsStream = _accountRepository.getAccountsStream();
  }

  Future<void> _handleRefresh() async {
    await _accountRepository.refreshData();
  }

  void _navigateToAddTransfer() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddTransferScreen()),
    );
    if (result == true && mounted) {
      _accountRepository.refreshData();
    }
  }

  void _navigateToAddAccount() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const AddAccountScreen()),
    );
    if (result == true && mounted) {
      _accountRepository.refreshData();
    }
  }

  void _navigateToEditAccount(Account account) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (context) => EditAccountScreen(account: account)),
    );
    if (result == true && mounted) {
      _accountRepository.refreshData();
    }
  }

  Future<void> _handleDeleteAccount(Account account) async {
    if (account.balance != 0) {
      NotificationHelper.show(
        message: 'No se puede eliminar. La cuenta aún tiene saldo.',
        type: NotificationType.error,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Iconsax.trash,
                  color: Theme.of(dialogContext).colorScheme.error,
                ),
              ),
              const SizedBox(width: 12),
              const Text('Eliminar cuenta'),
            ],
          ),
          content: Text(
              '¿Seguro que quieres eliminar "${account.name}"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
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
        _accountRepository.refreshData();
        EventService.instance.fire(AppEvent.accountUpdated);
        NotificationHelper.show(
          message: 'Cuenta eliminada',
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

  List<Account> _filterAccounts(List<Account> accounts) {
    if (_selectedFilter == 'Todas') return accounts;

    switch (_selectedFilter) {
      case 'Efectivo':
        return accounts.where((a) => a.type == 'Efectivo').toList();
      case 'Bancarias':
        return accounts.where((a) => a.type == 'Cuenta Bancaria').toList();
      case 'Crédito':
        return accounts.where((a) => a.type == 'Tarjeta de Crédito').toList();
      case 'Ahorros':
        return accounts
            .where((a) => a.type == 'Ahorros' || a.type == 'Inversión')
            .toList();
      default:
        return accounts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                'Mis Cuentas',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: colorScheme.onSurface,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primaryContainer.withOpacity(0.3),
                      colorScheme.surface,
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Iconsax.arrow_swap_horizontal),
                tooltip: 'Transferir',
                onPressed: _navigateToAddTransfer,
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _navigateToAddAccount,
                icon: const Icon(Iconsax.add, size: 20),
                label: const Text('Nueva'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
        ],
        body: StreamBuilder<List<Account>>(
          stream: _accountsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return _buildSkeletonLoader();
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            }

            final allAccounts = snapshot.data!;
            // --- NUEVA LÓGICA DE SEPARACIÓN ---
            final activeAccounts = allAccounts
                .where((acc) => acc.status == AccountStatus.active)
                .toList();
            final archivedAccounts = allAccounts
                .where((acc) => acc.status == AccountStatus.archived)
                .toList();

            return _buildContent(activeAccounts, archivedAccounts);
          },
        ),
      ),
    );
  }

  Widget _buildContent(
      List<Account> activeAccounts, List<Account> archivedAccounts) {
    // El filtro de tipo solo se aplica a las cuentas activas
    final filteredActiveAccounts = _filterAccounts(activeAccounts);
    // El balance total solo considera las cuentas activas
    final totalBalance =
        activeAccounts.fold<double>(0, (sum, acc) => sum + acc.balance);

    return RefreshIndicator(
      onRefresh: () => _accountRepository.refreshData(),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
              child:
                  _buildTotalBalanceCard(totalBalance, activeAccounts.length)),
          SliverToBoxAdapter(child: _buildFilters(archivedAccounts.isNotEmpty)),

          // --- LISTA DE CUENTAS ACTIVAS (FILTRADAS) ---
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: _buildGroupedAccountsList(filteredActiveAccounts),
          ),

          // --- SECCIÓN DE CUENTAS ARCHIVADAS (SI SE MUESTRAN) ---
          if (_showArchived && archivedAccounts.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
                child: Text(
                  'Cuentas Archivadas',
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver:
                  _buildGroupedAccountsList(archivedAccounts, isArchived: true),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildFilters(bool hasArchivedAccounts) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        children: [
          ..._filterOptions.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter),
                selected: isSelected,
                onSelected: (selected) =>
                    setState(() => _selectedFilter = filter),
              ),
            );
          }).toList(),

          // --- NUEVO FILTRO PARA ARCHIVADAS ---
          if (hasArchivedAccounts)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: FilterChip(
                label: Text('Ver Archivadas'),
                selected: _showArchived,
                avatar: Icon(_showArchived ? Iconsax.eye_slash : Iconsax.eye),
                onSelected: (selected) =>
                    setState(() => _showArchived = selected),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTotalBalanceCard(double totalBalance, int accountCount) {
    final currencyFormat =
        NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final isNegative = totalBalance < 0;

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isNegative
              ? [
                  Colors.red.withOpacity(0.15),
                  Colors.orange.withOpacity(0.1),
                ]
              : [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.secondaryContainer,
                ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Iconsax.wallet_money,
                  color: isNegative
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance Total',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer
                            .withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(totalBalance),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isNegative
                            ? Colors.red
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Iconsax.card,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  '$accountCount cuenta${accountCount != 1 ? 's' : ''} activa${accountCount != 1 ? 's' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  Future<void> _handleArchiveAccount(Account account) async {
    try {
      await _accountRepository.archiveAccount(account.id);
      // AÑADIDO: Notifica al stream que los datos han cambiado para refrescar la UI.
      _accountRepository.refreshData();
      // AÑADIDO (Buena práctica): Dispara un evento por si otros widgets necesitan actualizarse.
      EventService.instance.fire(AppEvent.accountUpdated);
      NotificationHelper.show(message: '"${account.name}" archivada.', type: NotificationType.info);
    } catch (e) {
      NotificationHelper.show(message: e.toString(), type: NotificationType.error);
    }
  }

  Future<void> _handleUnarchiveAccount(Account account) async {
    try {
      await _accountRepository.unarchiveAccount(account.id);
      // AÑADIDO: Notifica al stream que los datos han cambiado para refrescar la UI.
      _accountRepository.refreshData();
      // AÑADIDO (Buena práctica): Dispara un evento por si otros widgets necesitan actualizarse.
      EventService.instance.fire(AppEvent.accountUpdated);
      NotificationHelper.show(message: '"${account.name}" restaurada.', type: NotificationType.success);
    } catch (e) {
      NotificationHelper.show(message: e.toString(), type: NotificationType.error);
    }
  }

  Widget _buildGroupedAccountsList(List<Account> accounts,
      {bool isArchived = false}) {
    if (accounts.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Iconsax.search_status,
                  size: 80,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withOpacity(0.5),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sin resultados',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No hay cuentas en esta categoría',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Agrupar por tipo
    final Map<String, List<Account>> groupedAccounts = {};
    for (final account in accounts) {
      groupedAccounts.putIfAbsent(account.type, () => []).add(account);
    }

    final types = groupedAccounts.keys.toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final type = types[index];
          final typeAccounts = groupedAccounts[type]!;

          return _AccountTypeGroup(
            type: type,
            accounts: typeAccounts,
            icon: _accountIcons[type] ?? _accountIcons['default']!,
            color: _accountColors[type] ?? _accountColors['default']!,
            onEditAccount: _navigateToEditAccount,
            onDeleteAccount: _handleDeleteAccount,
            onArchiveAccount: _handleArchiveAccount,
            onUnarchiveAccount: _handleUnarchiveAccount,
            isArchived: isArchived,
          )
              .animate()
              .fadeIn(duration: 400.ms, delay: (100 * index).ms)
              .slideX(begin: -0.1, curve: Curves.easeOutCubic);
        },
        childCount: types.length,
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/add_account_animation.json',
              width: 280,
              height: 280,
            ),
            const SizedBox(height: 24),
            Text(
              'Comienza aquí',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Añade tu primera cuenta para empezar a organizar tus finanzas de forma inteligente',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _navigateToAddAccount,
              icon: const Icon(Iconsax.add_circle),
              label: const Text('Añadir mi primera cuenta'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                textStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms);
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.danger,
              size: 80,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 24),
            Text(
              'Algo salió mal',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _handleRefresh,
              icon: const Icon(Iconsax.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGET PARA GRUPO DE CUENTAS POR TIPO
// ============================================================================
class _AccountTypeGroup extends StatefulWidget {
  final String type;
  final List<Account> accounts;
  final IconData icon;
  final Color color;
  final Function(Account) onEditAccount;
  final Function(Account) onDeleteAccount;
  final Function(Account) onArchiveAccount;
  final Function(Account) onUnarchiveAccount;
  final bool isArchived;

  const _AccountTypeGroup({
    required this.type,
    required this.accounts,
    required this.icon,
    required this.color,
    required this.onEditAccount,
    required this.onDeleteAccount,
    required this.onArchiveAccount,
    required this.onUnarchiveAccount,
    this.isArchived = false,
  });

  @override
  State<_AccountTypeGroup> createState() => _AccountTypeGroupState();
}

class _AccountTypeGroupState extends State<_AccountTypeGroup> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final totalBalance =
        widget.accounts.fold<double>(0, (sum, acc) => sum + acc.balance);
    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded
              ? widget.color.withOpacity(0.3)
              : colorScheme.outlineVariant,
          width: _isExpanded ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Header del tipo
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              widget.type,
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${widget.accounts.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total: ${currencyFormat.format(totalBalance)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: totalBalance < 0 ? Colors.red : widget.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Iconsax.arrow_down_1,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contenido expandible
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.accounts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final account = widget.accounts[index];
                    return Opacity(
                      opacity: widget.isArchived ? 0.65 : 1.0,
                      child: _AccountCard(
                        account: account,
                        icon: widget.icon,
                        color: widget.color,
                        onEdit: () => widget.onEditAccount(account),
                        onArchive: () => widget.onArchiveAccount(account),
                        onUnarchive: () => widget.onUnarchiveAccount(account),
                        onDelete: () => widget.onDeleteAccount(account),
                      ),
                    );
                  },
                ),
              ],
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET PARA TARJETA DE CUENTA INDIVIDUAL
// ============================================================================
class _AccountCard extends StatelessWidget {
  final Account account;
  final IconData icon;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  const _AccountCard({
    required this.account,
    required this.icon,
    required this.color,
    required this.onEdit,
    required this.onDelete,
    required this.onArchive,
    required this.onUnarchive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AccountDetailsScreen(accountId: account.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(account.balance),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: account.balance < 0 ? colorScheme.error : color,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'archive') onArchive();
                  if (value == 'unarchive') onUnarchive();
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) {
                  // --- LÓGICA CONDICIONAL CLAVE ---
                  if (account.status == AccountStatus.active) {
                    // Opciones para cuentas ACTIVAS
                    return [
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(leading: Icon(Iconsax.edit), title: Text('Editar')),
                      ),
                      const PopupMenuItem(
                        value: 'archive',
                        child: ListTile(leading: Icon(Iconsax.archive), title: Text('Archivar')),
                      ),
                    ];
                  } else {
                    // Opciones para cuentas ARCHIVADAS
                    return [
                      const PopupMenuItem(
                        value: 'unarchive',
                        child: ListTile(leading: Icon(Iconsax.undo), title: Text('Desarchivar')),
                      ),
                      // Solo mostramos "Eliminar" si el saldo es cero, incluso para archivadas
                      if (account.balance == 0)
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(leading: Icon(Iconsax.trash, color: Colors.red), title: Text('Eliminar', style: TextStyle(color: Colors.red))),
                        ),
                    ];
                  }
                },
                icon: Icon(
                  Iconsax.more,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
