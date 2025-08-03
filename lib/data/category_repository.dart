// lib/data/category_repository.dart

import 'dart:async';
import 'package:sasper/models/category_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class CategoryRepository {
  // --- INICIO DE LOS CAMBIOS CRUCIALES ---
  
  // 1. El cliente ahora es privado y nullable.
  SupabaseClient? _supabase;

  // 2. Un getter público que PROTEGE el acceso al cliente.
  SupabaseClient get client {
    if (_supabase == null) {
      throw Exception("¡ERROR! CategoryRepository no ha sido inicializado. Llama a .initialize() en SplashScreen.");
    }
    return _supabase!;
  }

  // --- FIN DE LOS CAMBIOS CRUCIALES ---
  
  CategoryRepository._privateConstructor();
  static final CategoryRepository instance = CategoryRepository._privateConstructor();
  bool _isInitialized = false;

  void initialize(SupabaseClient supabaseClient) {
    if (_isInitialized) return;
    _supabase = supabaseClient;
    _isInitialized = true;
    developer.log('✅ [Repo] CategoryRepository Initialized', name: 'CategoryRepository');
  }

  // Ahora, todos los métodos usan el getter `client` en lugar de `_client`

  Stream<List<Category>> getCategoriesStream() {
    try {
      final rawStream = client.rpc('get_user_categories').asStream();

      return rawStream.map((dynamicRawList) {
        if (dynamicRawList == null || dynamicRawList is! List) {
          return <Category>[];
        }

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

  Future<List<Category>> getCategories() async {
    try {
      final data = await client.rpc('get_user_categories');
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
  
  Future<void> addCategory(Category category) async {
    try {
      final data = category.toMap();
      data['user_id'] = client.auth.currentUser!.id;
      await client.from('categories').insert(data);
    } catch (e, st) {
      developer.log('🔥 Error al añadir categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo crear la categoría.');
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      await client.from('categories').update(category.toMap()).eq('id', category.id);
    } catch (e, st) {
      developer.log('🔥 Error al actualizar categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo actualizar la categoría.');
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    try {
      await client.from('categories').delete().eq('id', categoryId);
    } catch (e, st) {
      developer.log('🔥 Error al eliminar categoría', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo eliminar la categoría.');
    }
  }
}