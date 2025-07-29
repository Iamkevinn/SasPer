// lib/screens/debts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

// Importamos la arquitectura limpia
import 'package:sasper/data/debt_repository.dart';
import 'package:sasper/models/debt_model.dart';
import 'package:sasper/screens/add_debt_screen.dart';
import 'package:sasper/widgets/debts/debt_card.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'register_payment_screen.dart';

class DebtsScreen extends StatefulWidget {
  // El constructor ahora es simple y constante. No recibe ningún parámetro.
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final Stream<List<Debt>> _debtsStream;

  // Accedemos a la única instancia (Singleton) del repositorio.
  final DebtRepository _repository = DebtRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Obtenemos el stream del Singleton.
    _debtsStream = _repository.getDebtsStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToAddDebt() {
    Navigator.of(context).push(MaterialPageRoute(
      // La pantalla de "Añadir" tampoco necesita repositorios en el constructor.
      // Ella misma obtendrá los Singletons que necesite.
      builder: (_) => const AddDebtScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Deudas y Préstamos', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.poppins(),
          tabs: const [
            Tab(text: 'Yo Debo (Deudas)'),
            Tab(text: 'Me Deben (Préstamos)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Iconsax.add_square, size: 28),
            tooltip: 'Añadir Deuda/Préstamo',
            onPressed: _navigateToAddDebt,
          ),
        ],
      ),
      body: StreamBuilder<List<Debt>>(
        stream: _debtsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyStateForAll();
          }
          
          final allDebts = snapshot.data!;
          final myDebts = allDebts.where((d) => d.type == DebtType.debt).toList();
          final loansToOthers = allDebts.where((d) => d.type == DebtType.loan).toList();
          
          return TabBarView(
            controller: _tabController,
            children: [
              _buildDebtsList(myDebts, isMyDebt: true),
              _buildDebtsList(loansToOthers, isMyDebt: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDebtsList(List<Debt> debts, {required bool isMyDebt}) {
    if (debts.isEmpty) {
      return _buildEmptyStateForTab(isMyDebt: isMyDebt);
    }
    
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 150),
        itemCount: debts.length,
        itemBuilder: (context, index) {
          final debt = debts[index];
          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 375),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: DebtCard(
                  debt: debt,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        // La pantalla de registro de pago ahora tampoco necesita repositorios.
                        builder: (context) => RegisterPaymentScreen(debt: debt),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildEmptyStateForAll() {
    return const Center(
      child: EmptyStateCard(
        title: 'Todo en Orden',
        message: 'No tienes deudas ni préstamos registrados. ¡Usa el botón (+) para añadir uno nuevo!',
        icon: Iconsax.safe_home,
      ),
    );
  }

  Widget _buildEmptyStateForTab({required bool isMyDebt}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMyDebt ? Iconsax.wallet_minus : Iconsax.wallet_add_1,
              size: 60,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              isMyDebt ? '¡Sin deudas pendientes!' : '¡Nadie te debe!',
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isMyDebt ? 'Aquí aparecerán los préstamos que has recibido.' : 'Cuando le prestes dinero a alguien, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}