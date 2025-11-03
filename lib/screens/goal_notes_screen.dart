// lib/screens/goal_notes_screen.dart

import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sasper/data/goal_note_repository.dart';
import 'package:sasper/models/goal_note_model.dart';
import 'package:sasper/utils/NotificationHelper.dart';
import 'package:sasper/widgets/shared/custom_notification_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class GoalNotesScreen extends StatefulWidget {
  final String goalId;
  final String goalName;

  const GoalNotesScreen({
    super.key,
    required this.goalId,
    required this.goalName,
  });

  @override
  State<GoalNotesScreen> createState() => _GoalNotesScreenState();
}

class _GoalNotesScreenState extends State<GoalNotesScreen> {
  final _noteRepository = GoalNoteRepository.instance;
  late Future<List<GoalNote>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  void _loadNotes() {
    setState(() {
      _notesFuture = _noteRepository.getNotesForGoal(widget.goalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      // <-- CORRECCIÓN VISUAL 1: Usamos un color de fondo más claro y agradable
      backgroundColor: colorScheme.surfaceContainerLowest, 
      appBar: AppBar(
        // <-- CORRECCIÓN VISUAL 2: Hacemos la AppBar consistente con el fondo
        backgroundColor: colorScheme.surfaceContainerLowest,
        elevation: 0,
        title: Text('Notas para "${widget.goalName}"'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddNoteDialog,
        tooltip: 'Añadir nota o enlace',
        child: const Icon(Iconsax.add),
      ),
      body: FutureBuilder<List<GoalNote>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            // Un mensaje más amigable y con mejor estilo
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Iconsax.note_add,
                        size: 48, color: colorScheme.primary.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'No hay notas todavía',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toca el botón + para añadir tu primera nota o enlace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: colorScheme.onSurface.withOpacity(0.7)),
                    ),
                  ],
                ),
              ),
            );
          }

          final notes = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              return _buildNoteCard(
                  notes[index]); // Reutilizamos el mismo widget de tarjeta
            },
          );
        },
      ),
    );
  }

  // --- WIDGET PARA LA TARJETA DE NOTA (idéntico al de EditGoalScreen) ---
  Widget _buildNoteCard(GoalNote note) {
    final isLink = note.type == GoalNoteType.link;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainer,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outline.withOpacity(0.2)),
      ),
      child: ListTile(
        leading: Icon(
          isLink ? Iconsax.link_21 : Iconsax.note_text,
          color: colorScheme.primary,
        ),
        title: Text(
          note.content,
          style: TextStyle(color: isLink ? Colors.blueAccent : null),
        ),
        trailing: IconButton(
          icon: Icon(Iconsax.trash, color: Colors.grey.shade600, size: 20),
          tooltip: 'Borrar nota',
          onPressed: () async {
            await _noteRepository.deleteNote(note.id);
            _loadNotes();
          },
        ),
        onTap: isLink
            ? () async {
                final uri = Uri.tryParse(note.content);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  NotificationHelper.show(
                    message: 'No se pudo abrir el enlace',
                    type: NotificationType.error,
                  );
                }
              }
            : null,
      ),
    );
  }

  // --- DIÁLOGO PARA AÑADIR NOTA (idéntico al de EditGoalScreen) ---
  void _showAddNoteDialog() {
    final textController = TextEditingController();
    var noteType = GoalNoteType.note;

    showDialog(
      context: context,
      builder: (context) {
        final navigator = Navigator.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Añadir Nota o Enlace'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToggleButtons(
                    isSelected: [
                      noteType == GoalNoteType.note,
                      noteType == GoalNoteType.link
                    ],
                    onPressed: (index) {
                      setDialogState(() {
                        noteType =
                            index == 0 ? GoalNoteType.note : GoalNoteType.link;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    children: const [
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Nota')),
                      Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text('Enlace')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: noteType == GoalNoteType.note
                          ? 'Escribe tu nota...'
                          : 'Pega el enlace (URL)',
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    minLines: 1,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (textController.text.trim().isNotEmpty) {
                      await _noteRepository.addNote(
                        goalId: widget.goalId,
                        type: noteType,
                        content: textController.text.trim(),
                      );
                      navigator.pop();
                      _loadNotes();
                    }
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
