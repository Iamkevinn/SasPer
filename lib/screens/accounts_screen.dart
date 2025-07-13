// lib/screens/accounts_screen.dart

import 'dart:async'; // Importante para StreamController
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'add_account_screen.dart';
import 'add_transfer_screen.dart';
import '../widgets/accounts/projection_card.dart';
import '../widgets/shared/empty_state_card.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => AccountsScreenState();
}

class AccountsScreenState extends State<AccountsScreen> {
  // CAMBIO 1: Usamos un StreamController para tener control total.
  final _streamController = StreamController<List<Map<String, dynamic>>>.broadcast();
  
  // Guardamos las suscripciones de Supabase para poder cancelarlas.
  late final List<RealtimeChannel> _subscriptions;

  final Map<String, IconData> _accountIcons = {
    'Efectivo': Iconsax.money,
    'Cuenta Bancaria': Iconsax.building,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros': Iconsax.safe_home,
    'Inversión': Iconsax.chart_1,
  };

  @override
  void initState() {
    super.initState();
    _setupSubscriptions();
    // Cargamos los datos por primera vez.
    _fetchData();
  }
  
  void _setupSubscriptions() {
    // Función que se llamará cuando haya un cambio en CUALQUIERA de las tablas.
    void onDbChange(payload) => _fetchData();
    
    // CAMBIO 2: Escuchamos cambios en 'accounts' Y 'transactions'.
    final accountsChannel = Supabase.instance.client
      .channel('public:accounts:accounts_screen')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'accounts', callback: onDbChange)
      .subscribe();
      
    final transactionsChannel = Supabase.instance.client
      .channel('public:transactions:accounts_screen')
      .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'transactions', callback: onDbChange)
      .subscribe();
      
    _subscriptions = [accountsChannel, transactionsChannel];
  }

  // CAMBIO 3: Función para obtener los datos y meterlos en el stream.
  Future<void> _fetchData() async {
    try {
      final response = await Supabase.instance.client.rpc('get_accounts_with_balance');
      final data = (response as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      if (mounted) {
        _streamController.add(data);
      }
    } catch (e) {
      if (mounted) {
        _streamController.addError(e);
      }
    }
  }

  @override
  void dispose() {
    // Limpiamos todo al salir de la pantalla.
    for (var sub in _subscriptions) {
      sub.unsubscribe();
    }
    _streamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Mis Cuentas'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.arrow_swap_horizontal),
            tooltip: 'Nueva Transferencia',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddTransferScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Iconsax.add_square, size: 28),
            tooltip: 'Añadir Cuenta',
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const AddAccountScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        // CAMBIO 4: Escuchamos nuestro controlador, no directamente Supabase.
        stream: _streamController.stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildLoadingShimmer();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar cuentas: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: EmptyStateCard(
                title: 'Aún no tienes cuentas',
                message: '¡Añade una para empezar!',
                icon: Iconsax.wallet_add,
            ));
          }
          return _buildContent(snapshot.data!);
        },
      ),
    );
  }
  
  Widget _buildContent(List<Map<String, dynamic>> accounts) {
    return RefreshIndicator(
      // CAMBIO 5: onRefresh ahora llama a nuestra función de carga de datos.
      onRefresh: _fetchData,
      child: AnimationLimiter(
        child: ListView.builder(
          padding: const EdgeInsets.only(bottom: 150, left: 16, right: 16),
          itemCount: accounts.length,
          itemBuilder: (context, index) {
            final account = accounts[index];
            final accountId = account['id']?.toString();

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
                      if (accountId != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: ProjectionCard(accountId: accountId),
                        ),
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
  
  // El resto de tus widgets (_buildAccountTile y _buildLoadingShimmer) están perfectos
  // y no necesitan cambios.
  Widget _buildAccountTile(Map<String, dynamic> account) {
    final balance = (account['current_balance'] as num? ?? 0).toDouble();
    final type = account['type']?.toString() ?? 'Sin tipo';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(_accountIcons[type] ?? Iconsax.wallet, size: 30),
        title: Text(account['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(type),
        trailing: Text(
          NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0).format(balance),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: balance < 0 ? Colors.redAccent : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
  
  Widget _buildLoadingShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;
    
    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 6,
          itemBuilder: (_, __) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.white, radius: 24),
              title: Container(height: 16, width: 120, color: Colors.white),
              subtitle: Container(height: 12, width: 80, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}


  


  