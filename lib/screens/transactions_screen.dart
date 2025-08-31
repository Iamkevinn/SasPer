// lib/screens/transactions_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;

// --- NUEVAS IMPORTACIONES ---
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';

// --- DEPENDENCIAS EXISTENTES ---
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/config/app_constants.dart';
import 'package:sasper/main.dart';

class TransactionsScreen extends StatefulWidget {
  // Los repositorios ya no se pasan en el constructor.
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  // Accedemos a las únicas instancias (Singletons) de los repositorios.
  final TransactionRepository _transactionRepository = TransactionRepository.instance;

  // Stream principal que escuchará el StreamBuilder
  late Stream<List<Transaction>> _transactionsStream;

  StreamSubscription<AppEvent>? _eventSubscription;

  // Variables de estado para los filtros
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedCategories = [];
  DateTimeRange? _selectedDateRange;
  
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    // Inicializamos el stream que mostrará los datos por defecto (en tiempo real).
    _transactionsStream = _transactionRepository.getTransactionsStream();

    // Listener para la búsqueda en tiempo real
    _searchController.addListener(_onSearchChanged);

    // Nos suscribimos a los eventos de la app.
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted,
        AppEvent.transactionsChanged, // Evento genérico
      };
      // Si ocurre un evento relevante Y no estamos en modo filtro, refrescamos.
      if (refreshEvents.contains(event) && !_isFilteringActive()) {
        _transactionRepository.refreshData();
      }
    });
    
  }

  @override
  void dispose() {
     _eventSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }
  
  // Pequeño helper para saber si hay filtros activos
  bool _isFilteringActive() {
    return _searchQuery.isNotEmpty || _selectedCategories.isNotEmpty || _selectedDateRange != null;
  }

  /// Reemplaza el stream actual por uno nuevo basado en los filtros aplicados.
  void _applyFilters() {
    developer.log('Applying filters...', name: 'TransactionsScreen');
    setState(() {
      // Si todos los filtros están limpios, vuelve al stream en tiempo real.
      if (!_isFilteringActive()) {
        _transactionsStream = _transactionRepository.getTransactionsStream();
      } else {
        // Si hay filtros, crea un stream a partir del Future.
        _transactionsStream = _transactionRepository.getFilteredTransactions(
          searchQuery: _searchQuery,
          categoryFilter: _selectedCategories.isNotEmpty ? _selectedCategories : null,
          dateRange: _selectedDateRange,
        ).asStream();
      }
    });
  }
  
  /// Se activa cada vez que el texto en el campo de búsqueda cambia.
  void _onSearchChanged() {
    // Usamos un pequeño delay (debounce) para no hacer una búsqueda en cada letra.
    // En una app real, se usaría un paquete como rxdart, pero un Timer es suficiente aquí.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text != _searchQuery) {
        _searchQuery = _searchController.text;
        _applyFilters();
      }
    });
  }
  
  /// Activa o desactiva el modo de búsqueda.
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _resetToDefaultStream(); // Volvemos al stream en tiempo real
      }
    });
  }

  /// Vuelve al stream principal que escucha los cambios en tiempo real.
  void _resetToDefaultStream() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategories.clear();
      _selectedDateRange = null;
      _transactionsStream = _transactionRepository.getTransactionsStream();
    });
  }

  /// Navega a la pantalla de edición y espera un resultado para refrescar.
  void _navigateToEdit(Transaction transaction) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(transaction: transaction),
      ),
    );
    // Si volvemos con 'true', le damos el "empujón" al repositorio.
    if (result == true && mounted) {
      _transactionRepository.refreshData();
    }
  }

  /// Maneja la lógica de borrado de una transacción.
  Future<bool> _handleDelete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      // 1. Usamos el context del Navigator global, que siempre es válido.
      context: navigatorKey.currentContext!,
      
      // 2. Usamos 'dialogContext' para el builder para evitar confusiones.
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          // 3. Usamos 'dialogContext' para obtener el tema y colores.
          backgroundColor: Theme.of(dialogContext).colorScheme.surface.withOpacity(0.9),
          title: const Text('Confirmar Acción'),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            // 4. Usamos 'dialogContext' para cerrar el diálogo.
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar')
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.errorContainer,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onErrorContainer),
              // 5. Y para cerrar el diálogo.
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      try {
        await _transactionRepository.deleteTransaction(transaction.id);
        // El listener de Supabase debería actuar aquí, pero un "nudge" manual
        // asegura que la UI es 100% inmediata.
        //_transactionRepository.refreshData();
        
        // Disparamos el evento global para el Dashboard, etc.
        EventService.instance.fire(AppEvent.transactionDeleted);
        
        if (mounted) {
          NotificationHelper.show(
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
        }
        return false;
      }
    }
    return false;
  }
  
  /// Muestra el panel inferior para seleccionar los filtros.
  void _showFilterBottomSheet() {
    List<String> tempSelectedCategories = List.from(_selectedCategories);
    DateTimeRange? tempDateRange = _selectedDateRange;
    final allCategories = {...AppConstants.expenseCategories.keys, ...AppConstants.incomeCategories.keys}.toList();

    Future<void> pickDateRange(StateSetter setModalState) async {
      final newDateRange = await showDateRangePicker(
        context: context,
        initialDateRange: tempDateRange,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('es'),
      );
      if (newDateRange != null) {
        setModalState(() => tempDateRange = newDateRange);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) { 
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(12))),
                    ),
                    Text('Filtrar Movimientos', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Iconsax.calendar_1),
                      title: const Text('Rango de Fechas'),
                      subtitle: Text(
                        tempDateRange == null
                            ? 'Cualquier fecha'
                            : '${DateFormat.yMMMd('es').format(tempDateRange!.start)} - ${DateFormat.yMMMd('es').format(tempDateRange!.end)}',
                      ),
                      trailing: const Icon(Iconsax.arrow_right_3),
                      onTap: () => pickDateRange(setModalState),
                    ),
                    const Divider(height: 1),
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Align(alignment: Alignment.centerLeft, child: Text('Categorías', style: TextStyle(fontWeight: FontWeight.bold))),
                    ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: allCategories.length,
                        itemBuilder: (context, index) {
                          final category = allCategories[index];
                          final isSelected = tempSelectedCategories.contains(category);
                          return CheckboxListTile(
                            title: Text(category),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setModalState(() {
                                if (value == true) {
                                  tempSelectedCategories.add(category);
                                } else {
                                  tempSelectedCategories.remove(category);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                 setState(() {
                                  _selectedCategories.clear();
                                  _selectedDateRange = null;
                                  _resetToDefaultStream();
                                });
                                Navigator.pop(context);
                              },
                              child: const Text('Limpiar Filtros'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                _selectedCategories = tempSelectedCategories;
                                _selectedDateRange = tempDateRange;
                                _applyFilters();
                                Navigator.pop(context);
                              },
                              child: const Text('Aplicar Filtro'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasActiveFilters = _selectedCategories.isNotEmpty || _selectedDateRange != null || _searchQuery.isNotEmpty;
    
    return Scaffold(
      appBar: AppBar(
  // --- TÍTULO (Tu código aquí ya es perfecto) ---
  title: _isSearching
      ? TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar...',
            border: InputBorder.none,
          ),
          style: GoogleFonts.poppins(),
        )
          .animate()
          // ---- CORRECCIÓN AQUÍ: Eliminamos `const` de la duración ----
          .fadeIn(duration: 200.ms) 
          .scaleX(begin: 0.8, duration: 200.ms, curve: Curves.easeOut)
      : Text(
          'Movimientos',
          style: GoogleFonts.poppins(),
        )
          .animate()
          // ---- CORRECCIÓN AQUÍ: Eliminamos `const` de la duración ----
          .fadeIn(duration: 200.ms),

  // --- ACCIONES (Usando AnimatedSwitcher, que no tiene este problema) ---
  actions: [
    IconButton(
      icon: Badge(isLabelVisible: hasActiveFilters, child: const Icon(Iconsax.filter)),
      onPressed: _showFilterBottomSheet,
    ),
    IconButton(
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300), // Usamos el constructor `const` estándar
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: _isSearching
            ? const Icon(Iconsax.close_square, key: ValueKey('close_icon'))
            : const Icon(Iconsax.search_normal, key: ValueKey('search_icon')),
      ),
      onPressed: _toggleSearch,
    ),
  ],
),

      body: StreamBuilder<List<Transaction>>(
        stream: _transactionsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // AHORA: Usamos Skeletonizer para un estado de carga más realista.
            return Skeletonizer(
              child: ListView.builder(
                itemCount: 10, // Muestra 10 elementos esqueleto
                itemBuilder: (context, index) => TransactionTile(
                  transaction: Transaction.empty(), // Usamos un modelo vacío como molde
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildLottieEmptyState();
          }
          final transactions = snapshot.data!;
          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              return TransactionTile(
          transaction: transaction,
          onTap: () => _navigateToEdit(transaction),
          onDeleted: () => _handleDelete(transaction),
        )
        .animate()
        .fadeIn(duration: 400.ms, delay: (50 * index).ms)
        .slideX(begin: 0.1, duration: 400.ms, delay: (50 * index).ms);
            },
          );
        },
      ),
    );
  }

  /// Construye el widget que se muestra cuando no hay transacciones, usando Lottie.
  Widget _buildLottieEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset(
                'assets/animations/empty_box.json',
                width: 200,
                height: 200,
              ),
              const SizedBox(height: 24),
              Text(
                'Sin Resultados',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'No se encontraron movimientos que coincidan con tu búsqueda. Prueba a cambiar los filtros o añade una nueva transacción.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 400.ms);
  }
}