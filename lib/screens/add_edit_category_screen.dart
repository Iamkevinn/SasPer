// lib/screens/add_edit_category_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_iconpicker/Models/configuration.dart';
import 'package:flutter_iconpicker/flutter_iconpicker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/category_repository.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final Category? categoryToEdit;
  final CategoryType? type; // Requerido solo si se crea una nueva

  const AddEditCategoryScreen({super.key, this.categoryToEdit, this.type})
      : assert(categoryToEdit != null || type != null,
            'Debes proveer una categoría para editar o un tipo para crear una nueva.');

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  IconData? _selectedIcon;
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;

  final CategoryRepository _repository = CategoryRepository.instance;
  bool get _isEditing => widget.categoryToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.categoryToEdit!;
      _nameController = TextEditingController(text: c.name);
      _selectedIcon = c.icon;
      _selectedColor = c.colorAsObject;
    } else {
      _nameController = TextEditingController();
      _selectedIcon = Iconsax.category; // Icono por defecto
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    // 1. Guarda una referencia al FocusScope ANTES del await.
    // La comprobación 'mounted' aquí sigue siendo una buena práctica.
    if (!mounted) return;
    final focusScope = FocusScope.of(context);

    // 2. Llama al picker. Pasarle el 'context' aquí es seguro
    //    porque ocurre ANTES del 'await'. El 'showIconPicker' usa el
    //    context para encontrar el Navigator y el Theme en ese instante.
    final IconPickerIcon? icon = await showIconPicker(
      context,
      configuration: const SinglePickerConfiguration(
        iconPackModes: [
          IconPack.material,
          IconPack.cupertino,
        ],
        showTooltips: true,
        showSearchBar: true,
      ),
    );

    // 3. Cuando el código se reanuda, volvemos a comprobar si el widget
    //    sigue montado. Esta es la comprobación de seguridad más importante.
    if (!mounted || icon == null) return;

    // 4. Si todo está bien, actualizamos el estado y usamos la referencia
    //    guardada de FocusScope, lo cual es 100% seguro.
    setState(() => _selectedIcon = icon.data);
    focusScope.unfocus();
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Selecciona un color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _selectedColor,
            onColorChanged: (color) => setState(() => _selectedColor = color),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      if (_isEditing) {
        final updatedCategory = Category(
          id: widget.categoryToEdit!.id,
          userId: widget.categoryToEdit!.userId, // No cambia
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color:
              '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          type: widget.categoryToEdit!.type, // No se puede cambiar el tipo
          createdAt: widget.categoryToEdit!.createdAt, // No cambia
        );
        await _repository.updateCategory(updatedCategory);
      } else {
        final newCategory = Category(
          id: '', // Supabase lo genera
          userId: '', // El repositorio lo añade
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          color:
              '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
          type: widget.type!,
          createdAt: DateTime.now(),
        );
        await _repository.addCategory(newCategory);
      }
      if (!mounted) return;
      NotificationHelper.show(
          message: 'Categoría guardada!', type: NotificationType.success);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      NotificationHelper.show(
          message: e.toString(), type: NotificationType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Categoría' : 'Nueva Categoría',
            style: GoogleFonts.poppins()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                    labelText: 'Nombre de la Categoría',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Iconsax.text)),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'El nombre es obligatorio'
                    : null,
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline)),
                leading: Icon(_selectedIcon ?? Iconsax.category,
                    color: _selectedColor),
                title: const Text('Icono'),
                trailing: const Icon(Iconsax.arrow_right_3),
                onTap: _pickIcon,
              ),
              const SizedBox(height: 16),
              ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.outline)),
                leading:
                    CircleAvatar(backgroundColor: _selectedColor, radius: 12),
                title: const Text('Color'),
                trailing: const Icon(Iconsax.arrow_right_3),
                onTap: _pickColor,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitForm,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Iconsax.save_2),
                  label: Text(_isLoading ? 'Guardando...' : 'Guardar'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: GoogleFonts.poppins(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
