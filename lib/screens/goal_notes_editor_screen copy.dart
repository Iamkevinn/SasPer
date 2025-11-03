// ignore_for_file: file_names

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sasper/models/goal_model.dart';
import 'package:sasper/data/goal_repository.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';

class GoalNotesEditorScreen extends StatefulWidget {
  final Goal goal;
  const GoalNotesEditorScreen({super.key, required this.goal});

  @override
  State<GoalNotesEditorScreen> createState() => _GoalNotesEditorScreenState();
}

class _GoalNotesEditorScreenState extends State<GoalNotesEditorScreen> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isToolbarVisible = true;
  bool _hasUnsavedChanges = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  void _loadDocument() {
    try {
      final notesJson = widget.goal.notesContent;

      Document doc;
      
      if (notesJson == null || (notesJson is String && notesJson.isEmpty)) {
        // Si no hay contenido, crear documento vacío
        doc = Document();
      } else {
        // Decodificar el JSON si es String
        final dynamic decodedJson =
            (notesJson is String) ? jsonDecode(notesJson) : notesJson;
        
        // Crear documento desde JSON
        doc = Document.fromJson(decodedJson);
      }

      _controller = QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );

      _controller.addListener(_onContentChanged);
      
      setState(() => _isLoading = false);
    } catch (e) {
      if (kDebugMode) {
        print('Error loading document: $e');
      }
      // En caso de error, crear controlador básico con documento vacío
      _controller = QuillController(
        document: Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );
      _controller.addListener(_onContentChanged);
      
      setState(() => _isLoading = false);
    }
  }

  void _onContentChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onContentChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text(
          'Tienes cambios sin guardar. ¿Estás seguro de que quieres salir?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  Future<void> _saveNotes() async {
    setState(() => _hasUnsavedChanges = false);

    try {
      final contentJson = _controller.document.toDelta().toJson();
      final updatedGoal = widget.goal.copyWith(notesContent: contentJson);
      await GoalRepository.instance.updateGoal(updatedGoal);

      if (mounted) {
        Navigator.pop(context, updatedGoal);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          NotificationHelper.show(
            message: 'Notas guardadas con éxito',
            type: NotificationType.success,
          );
        });
      }
    } catch (e) {
      setState(() => _hasUnsavedChanges = true);
      NotificationHelper.show(
        message: 'Error al guardar las notas: ${e.toString()}',
        type: NotificationType.error,
      );
    }
  }

  void _toggleToolbar() {
    setState(() => _isToolbarVisible = !_isToolbarVisible);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Text('Notas para "${widget.goal.name}"'),
          backgroundColor: colorScheme.surfaceContainerLowest,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: colorScheme.surfaceContainerLowest,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notas para "${widget.goal.name}"',
                  overflow: TextOverflow.ellipsis),
              if (_hasUnsavedChanges)
                Text(
                  'Cambios sin guardar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          backgroundColor: colorScheme.surfaceContainerLowest,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(
                  _isToolbarVisible ? Icons.keyboard_hide : Icons.keyboard),
              tooltip: _isToolbarVisible
                  ? 'Ocultar herramientas'
                  : 'Mostrar herramientas',
              onPressed: _toggleToolbar,
            ),
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Guardar',
              onPressed: _hasUnsavedChanges ? _saveNotes : null,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                switch (value) {
                  case 'clear':
                    _showClearDialog();
                    break;
                  case 'export':
                    _showExportOptions();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'clear',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 12),
                      Text('Limpiar todo'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.share_outlined),
                      SizedBox(width: 12),
                      Text('Exportar'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Toolbar
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isToolbarVisible
                  ? Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: QuillSimpleToolbar(
                          controller: _controller,
                          config: QuillSimpleToolbarConfig(
                            decoration: const BoxDecoration(),
                            multiRowsDisplay: false,
                            showAlignmentButtons: true,
                            showBoldButton: true,
                            showItalicButton: true,
                            showUnderLineButton: true,
                            showStrikeThrough: true,
                            showColorButton: true,
                            showBackgroundColorButton: true,
                            showListNumbers: true,
                            showListBullets: true,
                            showListCheck: true,
                            showQuote: true,
                            showIndent: true,
                            showUndo: true,
                            showRedo: true,
                            showClearFormat: true,
                            showCodeBlock: false,
                            showInlineCode: false,
                            showLink: false,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Imprimimos las restricciones para depurar. Revisa tu consola.
                  if (kDebugMode) {
                    print('LayoutBuilder Constraints: $constraints');
                  }

                  // Ahora construimos el editor dentro de un contenedor
                  // que tiene el tamaño EXACTO que nos dio LayoutBuilder.
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: QuillEditor(
                      controller: _controller,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      config: QuillEditorConfig(
                        placeholder:
                            "✍️ Escribe tus ideas, metas y objetivos aquí...",
                        padding: const EdgeInsets.all(16),
                        autoFocus: false,
                        expands: false, // Importante que siga en false
                        scrollable: true,
                        customStyles: DefaultStyles(
                          // ... Tus customStyles se quedan igual ...
                           placeHolder: DefaultTextBlockStyle(
                              GoogleFonts.inter(
                                fontSize: 16,
                                color: colorScheme.onSurfaceVariant
                                    .withOpacity(0.5),
                                height: 1.6,
                              ),
                              HorizontalSpacing.zero,
                              VerticalSpacing.zero,
                              VerticalSpacing.zero,
                              null,
                            ),
                            paragraph: DefaultTextBlockStyle(
                              GoogleFonts.inter(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                                height: 1.6,
                              ),
                              HorizontalSpacing.zero,
                              const VerticalSpacing(8, 0),
                              VerticalSpacing.zero,
                              null,
                            ),
                            h1: DefaultTextBlockStyle(
                              GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                height: 1.4,
                              ),
                              HorizontalSpacing.zero,
                              const VerticalSpacing(16, 8),
                              VerticalSpacing.zero,
                              null,
                            ),
                            h2: DefaultTextBlockStyle(
                              GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                                height: 1.4,
                              ),
                              HorizontalSpacing.zero,
                              const VerticalSpacing(14, 6),
                              VerticalSpacing.zero,
                              null,
                            ),
                            h3: DefaultTextBlockStyle(
                              GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                                height: 1.4,
                              ),
                              HorizontalSpacing.zero,
                              const VerticalSpacing(12, 4),
                              VerticalSpacing.zero,
                              null,
                            ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            
            // Barra inferior
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getWordCount(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (_hasUnsavedChanges)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Sin guardar',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getWordCount() {
    final plainText = _controller.document.toPlainText();
    final words = plainText.trim().split(RegExp(r'\s+'));
    final wordCount = plainText.trim().isEmpty ? 0 : words.length;
    final charCount = plainText.length;
    return '$wordCount palabras • $charCount caracteres';
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Limpiar todo?'),
        content: const Text(
          'Esta acción eliminará todo el contenido. ¿Estás seguro?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              _controller.clear();
              setState(() => _hasUnsavedChanges = true);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Exportar como texto'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Compartir'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}