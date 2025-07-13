import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para HapticFeedback
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart'; // Para el Shimmer
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; // Para la lista animada

import 'add_account_screen.dart'; // Asegúrate de tener este import

// La clase AccountsScreen no cambia
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

// --- TODA LA LÓGICA ESTÁ AQUÍ, EN LA CLASE DE ESTADO ---
class _AccountsScreenState extends State<AccountsScreen> {
  late Future<List<Map<String, dynamic>>> _accountsFuture;

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
    _accountsFuture = _fetchAccounts();
  }

  Future<List<Map<String, dynamic>>> _fetchAccounts() async {
    final data = await Supabase.instance.client.rpc('get_accounts_with_balance');
    return List<Map<String, dynamic>>.from(data);
  }

  // --- NUEVO: Shimmer para la pantalla de carga ---
  Widget _buildAccountsShimmer() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDarkMode ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDarkMode ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6, // Muestra 6 placeholders
        itemBuilder: (_, __) => Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: const CircleAvatar(backgroundColor: Colors.white, radius: 24),
            title: Container(height: 16, width: 120, color: Colors.white),
            subtitle: Container(height: 12, width: 80, color: Colors.white),
            trailing: Container(height: 20, width: 90, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // --- NUEVO: Contenido real, extraído para la animación ---
  Widget _buildAccountsContent(AsyncSnapshot<List<Map<String, dynamic>>> snapshot, {required bool showContent}) {
    final accounts = snapshot.data!;
    
    // Caso especial cuando no hay cuentas
    if (accounts.isEmpty) {
      return AnimatedOpacity(
        opacity: showContent ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 500),
        child: const Center(child: Text('Aún no tienes cuentas. ¡Añade una!')),
      );
    }

    // Contenido principal con la lista animada
    return AnimatedOpacity(
      opacity: showContent ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 500),
      child: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.mediumImpact(); // Feedback al refrescar
          setState(() {
            _accountsFuture = _fetchAccounts();
          });
        },
        child: AnimationLimiter(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 150, left: 16, right: 16),
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredList(
                position: index,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: _buildAccountTile(accounts[index]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Widget para cada tarjeta de cuenta (tu código original con la corrección de localización)
  Widget _buildAccountTile(Map<String, dynamic> account) {
    final balance = (account['current_balance'] as num).toDouble();
    final type = account['account_type'] as String;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(_accountIcons[type] ?? Iconsax.wallet, size: 30),
        title: Text(account['account_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(type),
        trailing: Text(
          // --- CORRECCIÓN DE LOCALIZACIÓN ---
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

  // --- MÉTODO BUILD PRINCIPAL - TOTALMENTE REESTRUCTURADO ---
  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El header se queda fuera para estar siempre visible
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mis Cuentas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Iconsax.add_square, size: 28),
                  onPressed: () async {
                    HapticFeedback.selectionClick(); // Feedback al presionar
                    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddAccountScreen()));
                    // Refresca si se añadió algo
                    if (result == true) {
                      setState(() { _accountsFuture = _fetchAccounts(); });
                    }
                  },
                )
              ],
            ),
          ),
          // La lista es la que se carga y anima
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                final bool isDataReady = snapshot.connectionState == ConnectionState.done;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Contenido (ocupa todo el espacio)
                    if (snapshot.hasData)
                      _buildAccountsContent(snapshot, showContent: isDataReady)
                    else if (snapshot.hasError)
                      Center(child: Text('Error: ${snapshot.error}')),

                    // Shimmer de carga (encima, desaparece cuando está listo)
                    Visibility(
                      visible: !isDataReady,
                      child: _buildAccountsShimmer(),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}