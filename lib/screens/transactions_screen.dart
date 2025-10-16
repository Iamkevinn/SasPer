// lib/screens/transactions_screen.dart

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'dart:developer' as developer;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';
import 'package:sasper/data/transaction_repository.dart';
import 'package:sasper/models/transaction_models.dart';
import 'package:sasper/screens/edit_transaction_screen.dart';
import 'package:sasper/widgets/shared/transaction_tile.dart';
import 'package:sasper/services/event_service.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/config/app_constants.dart';
import 'package:sasper/main.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final TransactionRepository _transactionRepository = TransactionRepository.instance;
  late Stream<List<Transaction>> _transactionsStream;
  StreamSubscription<AppEvent>? _eventSubscription;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _selectedCategories = [];
  DateTimeRange? _selectedDateRange;
  bool _isSearching = false;
  String _selectedTimeFilter = 'Todos';

  final List<String> _timeFilters = ['Hoy', 'Esta Semana', 'Este Mes', 'Todos'];

  @override
  void initState() {
    super.initState();
    _transactionsStream = _transactionRepository.getTransactionsStream();
    _searchController.addListener(_onSearchChanged);

    _eventSubscription = EventService.instance.eventStream.listen((event) {
      final refreshEvents = {
        AppEvent.transactionCreated,
        AppEvent.transactionUpdated,
        AppEvent.transactionDeleted,
        AppEvent.transactionsChanged,
      };
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

  bool _isFilteringActive() {
    return _searchQuery.isNotEmpty ||
        _selectedCategories.isNotEmpty ||
        _selectedDateRange != null ||
        _selectedTimeFilter != 'Todos';
  }

  void _applyFilters() {
    developer.log('Applying filters...', name: 'TransactionsScreen');
    
    DateTimeRange? effectiveDateRange = _selectedDateRange;
    
    // Aplicar filtro de tiempo rápido
    if (_selectedTimeFilter != 'Todos' && _selectedDateRange == null) {
      final now = DateTime.now();
      switch (_selectedTimeFilter) {
        case 'Hoy':
          effectiveDateRange = DateTimeRange(
            start: DateTime(now.year, now.month, now.day),
            end: now,
          );
          break;
        case 'Esta Semana':
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
          effectiveDateRange = DateTimeRange(
            start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
            end: now,
          );
          break;
        case 'Este Mes':
          effectiveDateRange = DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          );
          break;
      }
    }

    setState(() {
      if (!_isFilteringActive()) {
        _transactionsStream = _transactionRepository.getTransactionsStream();
      } else {
        _transactionsStream = _transactionRepository
            .getFilteredTransactions(
              searchQuery: _searchQuery,
              categoryFilter: _selectedCategories.isNotEmpty ? _selectedCategories : null,
              dateRange: effectiveDateRange,
            )
            .asStream();
      }
    });
  }

  void _onSearchChanged() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && _searchController.text != _searchQuery) {
        _searchQuery = _searchController.text;
        _applyFilters();
      }
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _resetToDefaultStream();
      }
    });
  }

  void _resetToDefaultStream() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedCategories.clear();
      _selectedDateRange = null;
      _selectedTimeFilter = 'Todos';
      _transactionsStream = _transactionRepository.getTransactionsStream();
    });
  }

  void _navigateToEdit(Transaction transaction) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditTransactionScreen(transaction: transaction),
      ),
    );
    if (result == true && mounted) {
      _transactionRepository.refreshData();
    }
  }

  Future<bool> _handleDelete(Transaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: navigatorKey.currentContext!,
      builder: (dialogContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
              const Text('Eliminar'),
            ],
          ),
          content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
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

    if (confirmed == true) {
      try {
        await _transactionRepository.deleteTransaction(transaction.id);
        EventService.instance.fire(AppEvent.transactionDeleted);
        if (mounted) {
          NotificationHelper.show(
            message: 'Transacción eliminada',
            type: NotificationType.success,
          );
        }
        return true;
      } catch (e) {
        if (mounted) {
          NotificationHelper.show(
            message: 'Error al eliminar',
            type: NotificationType.error,
          );
        }
        return false;
      }
    }
    return false;
  }

  void _showFilterBottomSheet() {
    List<String> tempSelectedCategories = List.from(_selectedCategories);
    DateTimeRange? tempDateRange = _selectedDateRange;
    final allCategories = {
      ...AppConstants.expenseCategories.keys,
      ...AppConstants.incomeCategories.keys
    }.toList()..sort();

    Future<void> pickDateRange(StateSetter setModalState) async {
      final newDateRange = await showDateRangePicker(
        context: context,
        initialDateRange: tempDateRange,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        locale: const Locale('es'),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              dialogBackgroundColor: Theme.of(context).colorScheme.surface,
            ),
            child: child!,
          );
        },
      );
      if (newDateRange != null) {
        setModalState(() => tempDateRange = newDateRange);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.7,
                maxChildSize: 0.9,
                minChildSize: 0.5,
                builder: (_, scrollController) {
                  return Column(
                    children: [
                      // Handle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Icon(Iconsax.filter, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              'Filtros',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Iconsax.close_circle),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Filtro de fecha
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: const Icon(Iconsax.calendar_1),
                          title: const Text('Rango de Fechas'),
                          subtitle: Text(
                            tempDateRange == null
                                ? 'Cualquier fecha'
                                : '${DateFormat.yMMMd('es').format(tempDateRange!.start)} - ${DateFormat.yMMMd('es').format(tempDateRange!.end)}',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          trailing: const Icon(Iconsax.arrow_right_3),
                          onTap: () => pickDateRange(setModalState),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Sección de categorías
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            Icon(Iconsax.category, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Categorías',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (tempSelectedCategories.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${tempSelectedCategories.length}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Lista de categorías
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          itemCount: allCategories.length,
                          itemBuilder: (context, index) {
                            final category = allCategories[index];
                            final isSelected = tempSelectedCategories.contains(category);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CheckboxListTile(
                                title: Text(
                                  category,
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                                value: isSelected,
                                activeColor: Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onChanged: (bool? value) {
                                  setModalState(() {
                                    if (value == true) {
                                      tempSelectedCategories.add(category);
                                    } else {
                                      tempSelectedCategories.remove(category);
                                    }
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Botones de acción
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _selectedCategories.clear();
                                    _selectedDateRange = null;
                                    _resetToDefaultStream();
                                  });
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Iconsax.refresh, size: 18),
                                label: const Text('Limpiar'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton.icon(
                                onPressed: () {
                                  _selectedCategories = tempSelectedCategories;
                                  _selectedDateRange = tempDateRange;
                                  _applyFilters();
                                  Navigator.pop(context);
                                },
                                icon: const Icon(Iconsax.tick_circle, size: 18),
                                label: const Text('Aplicar'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool hasActiveFilters = _isFilteringActive();

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: _isSearching
                  ? null
                  : Text(
                      'Movimientos',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        color: colorScheme.onSurface,
                      ),
                    ),
            ),
            actions: [
              if (_isSearching)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar movimientos...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        prefixIcon: const Icon(Iconsax.search_normal_1),
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.2),
                  ),
                )
              else ...[
                IconButton(
                  icon: Badge(
                    isLabelVisible: hasActiveFilters,
                    label: Text('${_getActiveFiltersCount()}'),
                    child: const Icon(Iconsax.filter),
                  ),
                  onPressed: _showFilterBottomSheet,
                  tooltip: 'Filtros',
                ),
                IconButton(
                  icon: const Icon(Iconsax.search_normal),
                  onPressed: _toggleSearch,
                  tooltip: 'Buscar',
                ),
              ],
              if (_isSearching)
                IconButton(
                  icon: const Icon(Iconsax.close_circle),
                  onPressed: _toggleSearch,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ],
        body: Column(
          children: [
            // Filtros rápidos de tiempo
            _buildQuickTimeFilters(),
            
            // Resumen de filtros activos
            if (hasActiveFilters) _buildActiveFiltersChips(),
            
            // Lista de transacciones
            Expanded(
              child: StreamBuilder<List<Transaction>>(
                stream: _transactionsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildSkeletonLoader();
                  }
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error.toString());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  final transactions = snapshot.data!;
                  return _buildTransactionsList(transactions);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeFilters() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _timeFilters.length,
        itemBuilder: (context, index) {
          final filter = _timeFilters[index];
          final isSelected = _selectedTimeFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedTimeFilter = filter;
                  _applyFilters();
                });
              },
              labelStyle: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveFiltersChips() {
    final chips = <Widget>[];

    if (_selectedDateRange != null) {
      chips.add(_buildFilterChip(
        label: '${DateFormat.MMMd('es').format(_selectedDateRange!.start)} - ${DateFormat.MMMd('es').format(_selectedDateRange!.end)}',
        icon: Iconsax.calendar_1,
        onRemove: () {
          setState(() {
            _selectedDateRange = null;
            _applyFilters();
          });
        },
      ));
    }

    if (_selectedCategories.isNotEmpty) {
      chips.add(_buildFilterChip(
        label: '${_selectedCategories.length} categoría${_selectedCategories.length > 1 ? 's' : ''}',
        icon: Iconsax.category,
        onRemove: () {
          setState(() {
            _selectedCategories.clear();
            _applyFilters();
          });
        },
      ));
    }

    if (_searchQuery.isNotEmpty) {
      chips.add(_buildFilterChip(
        label: '"$_searchQuery"',
        icon: Iconsax.search_normal_1,
        onRemove: () {
          setState(() {
            _searchQuery = '';
            _searchController.clear();
            _applyFilters();
          });
        },
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...chips,
          if (chips.isNotEmpty)
            TextButton.icon(
              onPressed: _resetToDefaultStream,
              icon: const Icon(Iconsax.refresh, size: 16),
              label: const Text('Limpiar todo'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2);
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Icon(
              Iconsax.close_circle,
              size: 16,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedDateRange != null) count++;
    if (_selectedCategories.isNotEmpty) count++;
    if (_searchQuery.isNotEmpty) count++;
    if (_selectedTimeFilter != 'Todos') count++;
    return count;
  }

  Widget _buildTransactionsList(List<Transaction> transactions) {
    return RefreshIndicator(
      onRefresh: () => _transactionRepository.refreshData(),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
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
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 8,
        itemBuilder: (context, index) => TransactionTile(
          transaction: Transaction.empty(),
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
              'assets/animations/empty_box.json',
              width: 250,
              height: 250,
            ),
            const SizedBox(height: 24),
            Text(
              hasActiveFilters ? 'Sin resultados' : 'Sin movimientos',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isFilteringActive()
                  ? 'No se encontraron movimientos con estos filtros. Intenta ajustarlos.'
                  : 'Aún no tienes movimientos registrados. ¡Empieza añadiendo tu primera transacción!',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
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
              onPressed: () => _transactionRepository.refreshData(),
              icon: const Icon(Iconsax.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  bool get hasActiveFilters => _isFilteringActive();
}