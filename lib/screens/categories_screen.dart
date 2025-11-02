import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/screens/add_edit_category_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_dialog.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late Stream<List<Category>> _categoriesStream;
  final CategoryRepository _repository = CategoryRepository.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _categoriesStream = _repository.getCategoriesStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- Lógica de Datos (se mantiene igual, ya es robusta) ---
  void _navigateToAddCategory() async {
    final type =
        _tabController.index == 0 ? CategoryType.expense : CategoryType.income;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditCategoryScreen(type: type),
    ));
    // Refrescamos al volver para asegurar que la lista esté actualizada
    if (mounted) {
      setState(() => _categoriesStream = _repository.getCategoriesStream());
    }
  }

  void _navigateToEditCategory(Category category) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditCategoryScreen(categoryToEdit: category),
    ));
    if (mounted) {
      setState(() => _categoriesStream = _repository.getCategoriesStream());
    }
  }

  void _handleDeleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => CustomDialog(
        title: '¿Eliminar Categoría?',
        content:
            'Si eliminas "${category.name}", las transacciones existentes no se verán afectadas, pero tendrás que re-categorizarlas si lo deseas.',
        confirmText: 'Sí, Eliminar',
        onConfirm: () async {
          Navigator.of(dialogContext).pop();
          try {
            await _repository.deleteCategory(category.id);
            if (mounted) {
              NotificationHelper.show(
                  message: 'Categoría eliminada.',
                  type: NotificationType.success);
              setState(
                  () => _categoriesStream = _repository.getCategoriesStream());
            }
          } catch (e) {
            if (mounted) {
              NotificationHelper.show(
                  message: e.toString(), type: NotificationType.error);
            }
          }
        },
      ),
    );
  }

  // --- UI Rediseñada ---
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: StreamBuilder<List<Category>>(
        stream: _categoriesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return _buildSkeletonScreen();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allCategories = snapshot.data ?? [];

          if (allCategories.isEmpty) {
            return _buildLottieEmptyState();
          }

          final expenseCategories = allCategories
              .where((c) => c.type == CategoryType.expense)
              .toList();
          final incomeCategories = allCategories
              .where((c) => c.type == CategoryType.income)
              .toList();

          return _buildContentScreen(
              context, expenseCategories, incomeCategories);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddCategory,
        label: Text('Nueva Categoría',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        icon: const Icon(Iconsax.add),
      )
          .animate()
          .scale(delay: 500.ms, duration: 400.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildContentScreen(BuildContext context,
      List<Category> expenseCategories, List<Category> incomeCategories) {
    final colorScheme = Theme.of(context).colorScheme;

    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverAppBar(
          title: Text('Gestionar Categorías',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          pinned: true,
          floating: true,
          snap: true,
          forceElevated: innerBoxIsScrolled,
          bottom: TabBar(
            controller: _tabController,
            // --- CAMBIO 1: Haz que el indicador ocupe toda la pestaña ---
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4), // Espacio alrededor del indicador
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.primary,
            ),
            labelColor: colorScheme.onPrimary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            // --- CAMBIO 2: Añade padding a las etiquetas para darles más espacio ---
            labelPadding: const EdgeInsets.symmetric(
                horizontal: 16), // Espacio horizontal dentro de cada tab
            tabs: [
              Tab(text: 'Gastos (${expenseCategories.length})'),
              Tab(text: 'Ingresos (${incomeCategories.length})'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCategoryList(expenseCategories,
              'Define tus categorías de gastos para un mejor control.'),
          _buildCategoryList(incomeCategories,
              'Define tus fuentes de ingresos para ver de dónde viene tu dinero.'),
        ],
      ),
    );
  }

  Widget _buildCategoryList(List<Category> categories, String emptyMessage) {
    if (categories.isEmpty) {
      return _buildTabEmptyState(emptyMessage);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _CategoryCard(
          category: category,
          onEdit: () => _navigateToEditCategory(category),
          onDelete: () => _handleDeleteCategory(category),
        )
            .animate()
            .fadeIn(duration: 500.ms, delay: (100 * index).ms)
            .slideY(begin: 0.2, curve: Curves.easeOutCubic);
      },
    );
  }

  // --- Widgets de Estados ---

  Widget _buildSkeletonScreen() {
    return Scaffold(
      appBar: AppBar(
          title: Text('Gestionar Categorías',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
      body: Skeletonizer(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: 8,
          itemBuilder: (context, index) => _CategoryCard(
            category: Category.empty, // Usa un modelo vacío como placeholder
          ),
        ),
      ),
    );
  }

  Widget _buildLottieEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/categories_animation.json',
                width: 280, height: 280),
            const SizedBox(height: 24),
            Text(
              'Organiza tus Finanzas',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                  fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no tienes categorías. Crea tu primera para personalizar la app y tomar control de tu dinero.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5),
            ),
          ],
        ),
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildTabEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.folder_open,
                size: 80,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
            const SizedBox(height: 24),
            Text(
              'Sin Categorías Aquí',
              style: GoogleFonts.poppins(
                  fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

// --- Widget de Tarjeta de Categoría Rediseñado ---

class _CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CategoryCard({required this.category, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Material(
        color: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                  child: Icon(
                    category.icon,
                    color: category.type == CategoryType.expense
                        ? colorScheme.error
                        : Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    category.name,
                    style: GoogleFonts.inter(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Iconsax.edit),
                  onPressed: onEdit,
                  tooltip: 'Editar',
                ),
                IconButton(
                  icon: Icon(Iconsax.trash, color: colorScheme.error),
                  onPressed: onDelete,
                  tooltip: 'Eliminar',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
