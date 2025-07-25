// lib/screens/transactions_screen.dart (ACTUALIZADO CON BÚSQUEDA)

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/account_repository.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/config/app_constants.dart';

class TransactionsScreen extends StatefulWidget {
  final TransactionRepository transactionRepository;
  final AccountRepository accountRepository;

  const TransactionsScreen({
    super.key,
    required this.transactionRepository,
    required this.accountRepository,
  });

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  // --- 1. GESTIÓN DEL ESTADO DE LA BÚSQUEDA ---
  late Future<List<Transaction>> _transactionsFuture;
  final TextEditingController _searchController = TextEditingController();
  // --- 1. AÑADIMOS ESTADO PARA EL FILTRO DE CATEGORÍA ---
  List<String> _selectedCategories = []; 
  bool _isSearching = false;
  String _searchQuery = '';

  // La suscripción a eventos se mantiene para recargar si hay cambios desde otras pantallas
  late final StreamSubscription<AppEvent> _eventSubscription;

  @override
  void initState() {
    super.initState();
    // Cargamos las transacciones iniciales
    _fetchTransactions();

    // Listener para el campo de búsqueda
    _searchController.addListener(_onSearchChanged);

    // Listener para eventos globales (como un borrado o creación)
    _eventSubscription = EventService.instance.eventStream.listen((event) {
      if ({
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted
      }.contains(event)) {
        // Si ocurre un cambio, simplemente volvemos a pedir los datos.
        _fetchTransactions();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _eventSubscription.cancel();
    super.dispose();
  }

  // --- 2. LÓGICA PARA CARGAR Y FILTRAR DATOS ---
  void _fetchTransactions() {
    setState(() {
      _transactionsFuture = widget.transactionRepository.getFilteredTransactions(
        searchQuery: _searchQuery,
        categoryFilter: _selectedCategories, // Pasamos las categorías seleccionadas
      );
    });
  }

  // --- 3. NUEVA FUNCIÓN PARA MOSTRAR EL PANEL DE FILTROS ---
  void _showFilterBottomSheet() {
    // Usamos una copia temporal para que los cambios solo se apliquen al presionar "Aceptar"
    List<String> tempSelectedCategories = List.from(_selectedCategories);
    
    // Unimos las categorías de gastos e ingresos y eliminamos duplicados
    final allCategories = {...AppConstants.expenseCategories.keys, ...AppConstants.incomeCategories.keys}.toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Permite que el sheet ocupe más altura
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        // Usamos un StatefulWidget para que los checkboxes se puedan actualizar visualmente
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6, // Ocupa el 60% de la pantalla inicialmente
              maxChildSize: 0.9,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    // Handle para arrastrar
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Container(
                        width: 40, height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    Text('Filtrar por Categoría', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    // Lista de categorías con checkboxes
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
                    // Botones de acción
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                setModalState(() => tempSelectedCategories.clear());
                              },
                              child: const Text('Limpiar'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () {
                                setState(() {
                                  _selectedCategories = tempSelectedCategories;
                                });
                                _fetchTransactions(); // Aplicamos el filtro
                                Navigator.pop(context); // Cerramos el BottomSheet
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

  void _onSearchChanged() {
    if (_searchController.text != _searchQuery) {
      setState(() {
        _searchQuery = _searchController.text;
      });
      // Volvemos a buscar cada vez que el texto cambia.
      // En una app real, aquí se podría añadir un "debounce" para no hacer tantas llamadas.
      _fetchTransactions();
    }
  }
  
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        // Si se cancela la búsqueda, limpiamos el query y recargamos todo.
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  // --- La lógica de navegación y borrado se mantiene igual ---
  void _navigateToEdit(Transaction transaction) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditTransactionScreen(
        transaction: transaction,
        transactionRepository: widget.transactionRepository,
        accountRepository: widget.accountRepository,
      ),
    ));
  }

  // --- CORREGIDO: Lógica de borrado completa traída desde el Dashboard ---
  Future<bool> _handleDelete(Transaction transaction) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.0)),
          backgroundColor:
              Theme.of(context).colorScheme.surface.withOpacity(0.85),
          title: const Text('Confirmar eliminación'),
          content:
              const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancelar')),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.errorContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onErrorContainer),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true) {
      try {
        await widget.transactionRepository.deleteTransaction(transaction.id);
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Transacción eliminada correctamente.',
            type: NotificationType.success,
          );
          // Disparamos el evento para que la UI se actualice automáticamente
          // gracias al StreamSubscription que ya teníamos en initState.
          EventService.instance.fire(AppEvent.transactionDeleted);
        }
        return true; // Se borró con éxito
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            context: context,
            message: 'Error al eliminar la transacción.',
            type: NotificationType.error,
          );
        }
        return false; // Hubo un error
      }
    }
    return false; // No se confirmó el borrado
  }

  // --- 3. CONSTRUCCIÓN DE LA UI ADAPTATIVA ---
  @override
  Widget build(BuildContext context) {
    // El 'badge' que indica si hay filtros activos
    final bool hasActiveFilters = _selectedCategories.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        // El título cambia si estamos buscando o no
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar por descripción, categoría...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(fontSize: 18),
              )
            : Text('Movimientos', style: GoogleFonts.poppins()),
        actions: [
          // Botón de filtro con un 'badge' si está activo
          IconButton(
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              label: Text(_selectedCategories.length.toString()),
              child: const Icon(Iconsax.filter),
            ),
            onPressed: _showFilterBottomSheet,
          ),
          // Botón de búsqueda
          IconButton(
            icon: Icon(_isSearching ? Iconsax.close_square : Iconsax.search_normal),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      // Usamos un FutureBuilder que se reconstruirá cada vez que _transactionsFuture cambie
      body: FutureBuilder<List<Transaction>>(
        future: _transactionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: EmptyStateCard(
                icon: Iconsax.receipt_search,
                title: 'Sin Resultados',
                message: 'No se encontraron movimientos. Prueba con otra búsqueda o añade una nueva transacción.',
              ),
            );
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
              );
            },
          );
        },
      ),
    );
  }
}