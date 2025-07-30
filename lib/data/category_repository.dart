import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/category_model.dart';
import 'package:sasper/services/event_service.dart'; 
import 'dart:developer' as developer;

class CategoryRepository {
  late final SupabaseClient _client;
  
  CategoryRepository._privateConstructor();
  static final CategoryRepository instance = CategoryRepository._privateConstructor();

  void initialize(SupabaseClient client) {
    _client = client;
    developer.log('✅ [Repo] CategoryRepository Initialized', name: 'CategoryRepository');
  }

  /// Obtiene un stream de todas las categorías del usuario.
  Stream<List<Category>> getCategoriesStream() {
    try {
      final stream = _client
          .from('categories')
          .stream(primaryKey: ['id'])
          .order('name', ascending: true)
          .map((listOfMaps) => listOfMaps.map((data) => Category.fromMap(data)).toList());
      
      return stream.handleError((error, stackTrace) {
        developer.log('🔥 Error en stream de categorías: $error', name: 'CategoryRepository', error: error, stackTrace: stackTrace);
      });
    } catch (e) {
      developer.log('🔥 No se pudo suscribir al stream de categorías: $e', name: 'CategoryRepository');
      return Stream.value([]);
    }
  }

  /// Añade una nueva categoría.
  Future<void> addCategory(Category category) async {
    try {
      final data = category.toMap();
      data['user_id'] = _client.auth.currentUser!.id; // Aseguramos el user_id
      await _client.from('categories').insert(data);
      //EventService.instance.fire(AppEvent.categoriesChanged);
    } catch (e, st) {
      developer.log('🔥 Error al añadir categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo crear la categoría.');
    }
  }

  /// Actualiza una categoría existente.
  Future<void> updateCategory(Category category) async {
    try {
      await _client.from('categories').update(category.toMap()).eq('id', category.id);
      //EventService.instance.fire(AppEvent.categoriesChanged);
    } catch (e, st) {
      developer.log('🔥 Error al actualizar categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo actualizar la categoría.');
    }
  }

  /// Elimina una categoría.
  Future<void> deleteCategory(String categoryId) async {
    try {
      await _client.from('categories').delete().eq('id', categoryId);
      //EventService.instance.fire(AppEvent.categoriesChanged);
    } catch (e, st) {
      developer.log('🔥 Error al eliminar categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo eliminar la categoría.');
    }
  }
}