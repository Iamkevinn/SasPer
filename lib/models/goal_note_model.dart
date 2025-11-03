// lib/models/goal_note_model.dart

// 1. Enum para el tipo de nota.
//    Debe coincidir exactamente con el tipo ENUM que creamos en Supabase.
enum GoalNoteType { note, link }

class GoalNote {
  final int id;
  final String goalId; // Es un UUID en Supabase, lo manejamos como String en Dart
  final String userId;
  final GoalNoteType type;
  final String content;
  final DateTime createdAt;

  GoalNote({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  // 2. Factory constructor para crear una instancia de GoalNote desde un JSON.
  //    Esto es lo que usaremos para convertir los datos que vienen de Supabase
  //    a un objeto que nuestra app pueda entender.
  factory GoalNote.fromJson(Map<String, dynamic> json) {
    // Validamos que los campos requeridos no sean nulos para evitar errores.
    if (json['id'] == null ||
        json['goal_id'] == null ||
        json['user_id'] == null ||
        json['type'] == null ||
        json['content'] == null ||
        json['created_at'] == null) {
      throw FormatException("Invalid JSON for GoalNote: Missing required fields");
    }

    return GoalNote(
      id: json['id'],
      goalId: json['goal_id'],
      userId: json['user_id'],
      
      // Convertimos el texto 'link' o 'note' que viene de la base de datos
      // a nuestro enum GoalNoteType.
      type: json['type'] == 'link' ? GoalNoteType.link : GoalNoteType.note,
      
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}