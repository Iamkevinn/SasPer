// lib/screens/add_edit_category_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:sasper/screens/icon_picker_screen.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final Category? categoryToEdit;
  final CategoryType? type;

  const AddEditCategoryScreen({super.key, this.categoryToEdit, this.type})
      : assert(categoryToEdit != null || type != null,
            'Debes proveer una categoría para editar o un tipo para crear una nueva.');

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  IconData? _selectedIcon;
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;
  bool _hasChanges = false;

  late AnimationController _saveButtonController;
  late Animation<double> _saveButtonScale;

  final CategoryRepository _repository = CategoryRepository.instance;
  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    
    // Animación del botón
    _saveButtonController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _saveButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveButtonController, curve: Curves.easeInOut),
    );

    if (_isEditing) {
      final c = widget.categoryToEdit!;
      _nameController = TextEditingController(text: c.name);
      _selectedIcon = c.icon;
      _selectedColor = c.colorAsObject;
    } else {
      _nameController = TextEditingController();
      _selectedIcon = Iconsax.category;
    }

    _nameController.addListener(() {
      if (!_hasChanges && mounted) {
        setState(() => _hasChanges = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _saveButtonController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    if (!mounted) return;

    // CRÍTICO: Esperar a que el frame actual termine antes de navegar
    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!mounted) return;

    try {
      final IconData? selected = await Navigator.push<IconData>(
        context,
        MaterialPageRoute(
          builder: (_) => IconPickerScreen(currentIcon: _selectedIcon),
          // Agregado: configuración para mejor manejo de memoria
          maintainState: false,
        ),
      );

      if (selected != null && mounted) {
        setState(() {
          _selectedIcon = selected;
          _hasChanges = true;
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar icono: $e');
      if (mounted) {
        NotificationHelper.show(
          message: 'Error al seleccionar icono',
          type: NotificationType.error,
        );
      }
    }
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Selecciona un color',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) {
              setState(() {
                _selectedColor = color;
                _hasChanges = true;
              });
            },
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'Cancelar',
              style: GoogleFonts.poppins(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
          ElevatedButton(
            child: Text(
              'Seleccionar',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    _saveButtonController.forward().then((_) => _saveButtonController.reverse());
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updatedCategory = Category(
          id: widget.categoryToEdit!.id,
          userId: widget.categoryToEdit!.userId,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          type: widget.categoryToEdit!.type,
          createdAt: widget.categoryToEdit!.createdAt,
        );
        await _repository.updateCategory(updatedCategory);
      } else {
        final newCategory = Category(
          id: '',
          userId: '',
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color: '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          type: widget.type!,
          createdAt: DateTime.now(),
        );
        await _repository.addCategory(newCategory);
      }
      
      if (!mounted) return;
      Navigator.of(context).pop();
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        NotificationHelper.show(
          message: '✨ Categoría guardada correctamente',
          type: NotificationType.success,
        );
      });
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
        message: 'Error: ${e.toString()}',
        type: NotificationType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // App Bar estilo Apple
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: colorScheme.surface,
            leading: IconButton(
              icon: const Icon(Iconsax.arrow_left),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                _isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
            ),
          ),

          // Contenido
          SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre
                    _buildSectionLabel('Nombre', colorScheme),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        hintText: 'Ej: Comida, Transporte',
                        prefixIcon: const Icon(Iconsax.text),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Colors.red),
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'El nombre es obligatorio'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // Icono
                    _buildSectionLabel('Icono', colorScheme),
                    const SizedBox(height: 8),
                    _buildIconSelector(colorScheme),

                    const SizedBox(height: 24),

                    // Color
                    _buildSectionLabel('Color', colorScheme),
                    const SizedBox(height: 8),
                    _buildColorSelector(colorScheme),

                    const SizedBox(height: 32),

                    // Preview
                    _buildPreview(colorScheme),

                    const SizedBox(height: 32),

                    // Botón guardar
                    ScaleTransition(
                      scale: _saveButtonScale,
                      child: _buildSaveButton(colorScheme),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildIconSelector(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _pickIcon,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _selectedIcon != null
                      ? _selectedColor.withOpacity(0.15)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _selectedIcon ?? Iconsax.category,
                  size: 28,
                  color: _selectedIcon != null ? _selectedColor : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Icono seleccionado',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedIcon != null
                          ? 'Toca para cambiar'
                          : 'Toca para elegir',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorSelector(ColorScheme colorScheme) {
    return Material(
      color: colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: _pickColor,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.3),
                    width: 2,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Color de la categoría',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Iconsax.arrow_right_3,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _selectedColor.withOpacity(0.1),
            _selectedColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _selectedColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _selectedIcon ?? Iconsax.category,
              size: 32,
              color: _selectedColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vista Previa',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _nameController.text.isEmpty
                      ? 'Tu categoría'
                      : _nameController.text,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _selectedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 60,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isLoading || !_hasChanges
              ? [Colors.grey, Colors.grey.shade600]
              : [_selectedColor, _selectedColor.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _hasChanges && !_isLoading
            ? [
                BoxShadow(
                  color: _selectedColor.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading || !_hasChanges ? null : _submitForm,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Iconsax.tick_circle,
                          color: Colors.white, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        _hasChanges
                            ? (_isEditing ? 'Actualizar Categoría' : 'Crear Categoría')
                            : 'Sin Cambios',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}