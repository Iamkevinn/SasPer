// lib/screens/categories_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/screens/add_edit_category_screen.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/categories/category_list_item.dart';
import 'package:sasper/widgets/shared/custom_dialog.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/widgets/shared/empty_state_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:lottie/lottie.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late Stream<List<Category>> _categoriesStream;
  final CategoryRepository _repository = CategoryRepository.instance;
  //late StreamSubscription<AppEvent> _eventSubscription;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _categoriesStream = _repository.getCategoriesStream();
  }

  @override
  void dispose() {
    _tabController.dispose();
    //_eventSubscription.cancel();
    super.dispose();
  }

  void _navigateToAddCategory() async {
    // Determinamos el tipo de categoría a crear basado en la pestaña activa.
    final type = _tabController.index == 0 ? CategoryType.expense : CategoryType.income;
    // Esperamos a que la pantalla de añadir/editar se cierre.
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditCategoryScreen(type: type),
    ));

    // Este código SÓLO se ejecuta DESPUÉS de que volvemos a esta pantalla.
    // Ahora es seguro refrescar el estado.
    setState(() {
      _categoriesStream = _repository.getCategoriesStream();
    });
  }
  
  void _navigateToEditCategory(Category category) async {
    // Esperamos a que la pantalla de añadir/editar se cierre.
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddEditCategoryScreen(categoryToEdit: category),
    ));
    // Y refrescamos de forma segura.
    setState(() {
      _categoriesStream = _repository.getCategoriesStream();
    });
  }

  void _handleDeleteCategory(Category category) {
    showDialog(
      context: context,
      builder: (dialogContext) => CustomDialog(
        title: '¿Eliminar Categoría?',
        content: 'Si eliminas "${category.name}", las transacciones existentes no se verán afectadas, pero tendrás que re-categorizarlas si lo deseas.',
        confirmText: 'Sí, Eliminar',
        onConfirm: () async {
          Navigator.of(dialogContext).pop();
          try {
            await _repository.deleteCategory(category.id);
            if (!mounted) return;
            NotificationHelper.show(message: 'Categoría eliminada.', type: NotificationType.success);
            // CAMBIO: Refrescamos aquí también, ya que la eliminación ocurre en esta misma pantalla.
            setState(() {
              _categoriesStream = _repository.getCategoriesStream();
            });
          } catch (e) {
            if (!mounted) return;
            NotificationHelper.show(message: e.toString(), type: NotificationType.error);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestionar Categorías', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gastos'),
            Tab(text: 'Ingresos'),
          ],
        ),
      ),
      body: StreamBuilder<List<Category>>(
        stream: _categoriesStream,
         builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // --- REEMPLAZO DE INDICADOR CON SKELETONIZER ---
            return _buildSkeletonizer();
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final allCategories = snapshot.data ?? [];
          final expenseCategories = allCategories.where((c) => c.type == CategoryType.expense).toList();
          final incomeCategories = allCategories.where((c) => c.type == CategoryType.income).toList();

          if (allCategories.isEmpty) {
            // --- REEMPLAZO DE EMPTYSTATE ESTÁTICO CON LOTTIE ---
            return _buildLottieEmptyState();
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCategoryList(expenseCategories, 'No tienes categorías de gastos.'),
              _buildCategoryList(incomeCategories, 'No tienes categorías de ingresos.'),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddCategory,
        label: const Text('Nueva Categoría'),
        icon: const Icon(Iconsax.add),
      ).animate().scale(delay: 300.ms, duration: 400.ms), // Pequeña animación para el FAB
    );
  }

  Widget _buildCategoryList(List<Category> categories, String emptyMessage) {
    if (categories.isEmpty) {
      return Center(
        child: Text(emptyMessage)
            .animate()
            .fadeIn(duration: 300.ms)
      );
    }

    // --- REEMPLAZO DE STAGGEREDANIMATIONS CON FLUTTER_ANIMATE ---
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return CategoryListItem(
          category: category,
          onEdit: () => _navigateToEditCategory(category),
          onDelete: () => _handleDeleteCategory(category),
        )
        // Animación de entrada en cascada
        .animate()
        .fadeIn(duration: 500.ms, delay: (100 * index).ms)
        .slideY(begin: 0.2, curve: Curves.easeOutCubic);
      },
    );
  }

    Widget _buildSkeletonizer() {
    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: 8, // Muestra 8 elementos esqueleto
        itemBuilder: (context, index) =>   CategoryListItem(
          category: Category.empty, 
          onEdit: () {},
          onDelete: () {},// Usa el modelo vacío como molde
        ),
      ),
    );
  }

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
                'assets/animations/categories_animation.json',
                width: 250,
                height: 250,
              ),
              const SizedBox(height: 16),
              Text(
                'Sin Categorías',
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Usa el botón (+) para crear tu primera categoría de gastos o ingresos y personalizar tu app.',
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