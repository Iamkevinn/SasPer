// lib/data/category_repository.dart (CÓDIGO CON TIPADO FORZADO Y CORRECTO)

import 'dart:async';
import 'package:sasper/models/category_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class CategoryRepository {
  late final SupabaseClient _client;
  
  CategoryRepository._privateConstructor();
  static final CategoryRepository instance = CategoryRepository._privateConstructor();

  void initialize(SupabaseClient client) {
    _client = client;
    developer.log('✅ [Repo] CategoryRepository Initialized', name: 'CategoryRepository');
  }

  /// Obtiene un stream de las categorías del usuario usando una función RPC.
  Stream<List<Category>> getCategoriesStream() {
    try {
      // 1. Obtenemos el stream crudo que devuelve List<dynamic>
      final rawStream = _client.rpc('get_user_categories').asStream();

      // 2. Usamos .asyncMap para transformar el tipo de manera segura.
      // Esto crea un nuevo stream con el tipo de dato correcto.
      return rawStream.map((dynamicRawList) {
        
        // Se asegura de que la lista no sea nula.
        if (dynamicRawList == null || dynamicRawList is! List) {
          return <Category>[];
        }

        // Convierte la List<dynamic> a List<Category>
        final List<Category> categoryList = dynamicRawList
            .map((item) => Category.fromMap(item as Map<String, dynamic>))
            .toList();
        
        developer.log('✅ [RPC Stream] Datos transformados: ${categoryList.length} categorías.', name: 'CategoryRepository');
        
        return categoryList;
      });

    } catch (e, st) {
      developer.log('🔥 Error al suscribirse al RPC stream: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudieron cargar las categorías en tiempo real.');
    }
  }


  /// Obtiene una lista única de categorías usando una función RPC.
  Future<List<Category>> getCategories() async {
    try {
      final data = await _client.rpc('get_user_categories');
      final categories = (data as List)
          .map((item) => Category.fromMap(item as Map<String, dynamic>))
          .toList();
      developer.log('✅ [Repo] Obtenidas ${categories.length} categorías vía RPC.', name: 'CategoryRepository');
      return categories;
    } catch (e, st) {
      developer.log('🔥 Error al obtener la lista de categorías vía RPC', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudieron cargar las categorías.');
    }
  }
  
  // --- El resto de los métodos no cambian ---

  Future<void> addCategory(Category category) async {
    try {
      final data = category.toMap();
      data['user_id'] = _client.auth.currentUser!.id;
      await _client.from('categories').insert(data);
    } catch (e, st) {
      developer.log('🔥 Error al añadir categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo crear la categoría.');
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await _client.from('categories').update(category.toMap()).eq('id', category.id);
    } catch (e, st) {
      developer.log('🔥 Error al actualizar categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo actualizar la categoría.');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await _client.from('categories').delete().eq('id', categoryId);
    } catch (e, st) {
      developer.log('🔥 Error al eliminar categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo eliminar la categoría.');
    }
  }
}