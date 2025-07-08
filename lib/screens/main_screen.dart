import 'dart:ui';
import 'budgets_screen.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_screen.dart'; 
import 'dashboard_screen.dart';
import 'add_transaction_screen.dart';
import 'add_account_screen.dart';

// --- PANTALLA DE CUENTAS (Estable y funcional) ---
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  late Future<List<Map<String, dynamic>>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = _fetchAccounts();
  }

  Future<List<Map<String, dynamic>>> _fetchAccounts() async {
    final data = await Supabase.instance.client.rpc('get_accounts_with_balance');
    return List<Map<String, dynamic>>.from(data);
  }

  final Map<String, IconData> _accountIcons = {
    'Efectivo': Iconsax.money,
    'Cuenta Bancaria': Iconsax.building,
    'Tarjeta de Crédito': Iconsax.card,
    'Ahorros': Iconsax.safe_home,
    'Inversión': Iconsax.chart_1,
  };

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(top: mediaQuery.padding.top),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mis Cuentas', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Iconsax.add_square),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddAccountScreen()));
                    setState(() { _accountsFuture = _fetchAccounts(); });
                  },
                )
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _accountsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError) return Center(child: Text('Error al cargar cuentas: ${snapshot.error}'));
                final accounts = snapshot.data!;
                if (accounts.isEmpty) return const Center(child: Text('Aún no tienes cuentas. ¡Añade una!'));
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 150, left: 16, right: 16),
                  itemCount: accounts.length,
                  itemBuilder: (context, index) => _buildAccountTile(accounts[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

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
        trailing: Text(NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(balance), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: balance < 0 ? Colors.redAccent : Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}

// --- PANTALLA PRINCIPAL (CONTROLADOR DE NAVEGACIÓN) ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late final Future<FragmentProgram> _shaderProgram;

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    AccountsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _shaderProgram = FragmentProgram.fromAsset('shaders/noise.frag');
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          _widgetOptions.elementAt(_selectedIndex),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: _selectedIndex == 0 ? 56.0 : 0,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 300),
                    scale: _selectedIndex == 0 ? 1.0 : 0.0,
                    child: FloatingActionButton(
                      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => const AddTransactionScreen())),
                      child: const Icon(Iconsax.add),
                    ),
                  ),
                ),
                SizedBox(height: _selectedIndex == 0 ? 12 : 0),
                FutureBuilder<FragmentProgram>(
                  future: _shaderProgram,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SizedBox(height: 60);
                    return _buildLiquidGlassNavBar(context, snapshot.data!);
                  },
                ),
                SizedBox(height: mediaQuery.padding.bottom + 8),
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- El Widget de la barra de navegación, REFINADO Y PERFECCIONADO ---
  Widget _buildLiquidGlassNavBar(BuildContext context, FragmentProgram noiseShader) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(50.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
        child: Container(
          // La decoración crea el efecto de cristal con resplandor, sin borde ni sombra.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withAlpha(25), // Reflejo superior
                Colors.white.withAlpha(10), // Tono general del cristal
              ],
            ),
          ),
          // Usamos una Row que se encoge para ajustarse al contenido.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildNavItem(index: 0, selectedIcon: Iconsax.home_15, regularIcon: Iconsax.home),
              _buildNavItem(index: 1, selectedIcon: Iconsax.wallet_money, regularIcon: Iconsax.wallet_3),
              _buildNavItem(index: 2, selectedIcon: Iconsax.setting_4, regularIcon: Iconsax.setting_2),
            ],
          ),
        ),
      ),
    );
  }

  // El componente de cada ícono, ahora con tamaño fijo para controlar la proporción.
  Widget _buildNavItem({required int index, required IconData selectedIcon, required IconData regularIcon}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = _selectedIndex == index;
    return SizedBox(
      width: 68,
      height: 60,
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeIn,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer.withAlpha(200),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Icon(isSelected ? selectedIcon : regularIcon, color: isSelected ? colorScheme.onSecondaryContainer : colorScheme.onSurfaceVariant.withAlpha(200)),
          ],
        ),
      ),
    );
  }
}

// Clase helper para el shader de ruido (sin cambios)
class NoisePainter extends CustomPainter {
  final FragmentProgram shaderProgram;
  NoisePainter(this.shaderProgram);
  @override
  void paint(Canvas canvas, Size size) {
    final shader = shaderProgram.fragmentShader();
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
