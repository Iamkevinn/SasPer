// lib/screens/accounts_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'account_details_screen.dart'; 
import '../data/account_repository.dart';
import '../data/transaction_repository.dart';
import '../models/account_model.dart';
import 'add_account_screen.dart';
import 'add_transfer_screen.dart';
import '../widgets/accounts/projection_card.dart';
import '../widgets/shared/empty_state_card.dart';

class AccountsScreen extends StatefulWidget {
  // CORRECTO: Recibe las dependencias, no crea las suyas.
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
  // --- ¡CORRECCIÓN DE ARQUITECTURA! ---
  // Se elimina la línea: `final _accountRepository = AccountRepository();`
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
    // CORRECTO: Usamos el repositorio que nos llega a través del widget.
    _accountsStream = widget.repository.getAccountsWithBalanceStream();
  }

  // Se elimina `dispose` ya que MainScreen maneja el ciclo de vida del repositorio.

  Future<void> _handleRefresh() async {
    // CORRECTO: Usamos la instancia del widget.
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
              )
            );
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildAccountTile(account),
                      FutureBuilder<double>(
                        key: ValueKey(account.id),
                        // CORRECTO: Usamos la instancia del widget.
                        future: widget.repository.getAccountProjectionInDays(account.id),
                        builder: (context, projectionSnapshot) {
                          if (projectionSnapshot.connectionState == ConnectionState.waiting) return ProjectionCard.buildShimmer(context);
                          if (projectionSnapshot.hasError || !projectionSnapshot.hasData || projectionSnapshot.data! <= 0) return const SizedBox.shrink();
                          return ProjectionCard(daysLeft: projectionSnapshot.data!);
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
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
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16))),
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
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Icon(_accountIcons[account.type] ?? _accountIcons['default'], size: 30),
          title: Text(account.name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          subtitle: Text(account.type),
          trailing: Text(
            NumberFormat.currency(locale: 'es_MX', symbol: '\$', decimalDigits: 0).format(account.balance),
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: account.balance < 0 ? Colors.redAccent : Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        itemBuilder: (_, __) => Column(
          children: [
            const Card(
              margin: EdgeInsets.only(bottom: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.white, radius: 24),
                title: Text(""),
                subtitle: Text(""),
              ),
            ),
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.white,
                 borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


