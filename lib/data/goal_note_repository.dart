// lib/data/goal_note_repository.dart

import 'package:sasper/models/goal_note_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class GoalNoteRepository {
  // Usamos el patrón Singleton para asegurar que solo haya una instancia
  // de este repositorio en toda la app.
  GoalNoteRepository._();
  static final instance = GoalNoteRepository._();

  final _supabase = Supabase.instance.client;
  final String _tableName = 'goal_notes';

  /// Obtiene una lista de todas las notas y enlaces para una meta específica.
  ///
  /// [goalId] El ID de la meta de la que se quieren obtener las notas.
  Future<List<GoalNote>> getNotesForGoal(String goalId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .eq('goal_id', goalId)
          .order('created_at', ascending: false); // Las más nuevas primero

      // Supabase devuelve una lista de mapas. Usamos nuestro método .fromJson
      // para convertir cada mapa en un objeto GoalNote.
      final notes = response.map((json) => GoalNote.fromJson(json)).toList();
      return notes;

    } on PostgrestException catch (e) {
      developer.log('PostgrestException fetching goal notes: ${e.message}', name: 'GoalNoteRepository');
      throw Exception('Error en la base de datos: ${e.message}');
    } catch (e) {
      developer.log('Error fetching goal notes: $e', name: 'GoalNoteRepository');
      throw Exception('No se pudieron cargar las notas.');
    }
  }

  /// Añade una nueva nota o enlace a una meta.
  ///
  /// [goalId] El ID de la meta a la que se asocia la nota.
  /// [type] El tipo de nota (GoalNoteType.note o GoalNoteType.link).
  /// [content] El texto de la nota o la URL del enlace.
  Future<void> addNote({
    required String goalId,
    required GoalNoteType type,
    required String content,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado. No se puede guardar la nota.');

      await _supabase.from(_tableName).insert({
        'goal_id': goalId,
        'user_id': userId,
        // Convertimos nuestro enum de Dart al texto que Supabase espera ('note' o 'link').
        'type': type.name,
        'content': content,
      });

    } on PostgrestException catch (e) {
      developer.log('PostgrestException adding goal note: ${e.message}', name: 'GoalNoteRepository');
      throw Exception('Error en la base de datos: ${e.message}');
    } catch (e) {
      developer.log('Error adding goal note: $e', name: 'GoalNoteRepository');
      throw Exception('No se pudo guardar la nota.');
    }
  }

  /// Borra una nota específica usando su ID.
  ///
  /// [noteId] El ID único de la nota a borrar.
  Future<void> deleteNote(int noteId) async {
    try {
      await _supabase
        .from(_tableName)
        .delete()
        .eq('id', noteId);

    } on PostgrestException catch (e) {
      developer.log('PostgrestException deleting goal note: ${e.message}', name: 'GoalNoteRepository');
      throw Exception('Error en la base de datos: ${e.message}');
    } catch (e) {
      developer.log('Error deleting goal note: $e', name: 'GoalNoteRepository');
      throw Exception('No se pudo borrar la nota.');
    }
  }
}