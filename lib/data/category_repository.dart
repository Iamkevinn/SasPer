// lib/data/category_repository.dart

import 'dart:async';
import 'package:sasper/models/category_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:developer' as developer;

class CategoryRepository {
  // --- PATRÓN DE INICIALIZACIÓN PEREZOSA ---

  SupabaseClient? _supabase;
  bool _isInitialized = false;

  // Constructor privado para forzar el uso del Singleton `instance`.
  CategoryRepository._internal();
  static final CategoryRepository instance = CategoryRepository._internal();

  /// Se asegura de que el repositorio esté inicializado.
  /// Se ejecuta automáticamente la primera vez que se accede al cliente de Supabase.
  void _ensureInitialized() {
    // Esta lógica solo se ejecuta una vez en todo el ciclo de vida de la app.
    if (!_isInitialized) {
      _supabase = Supabase.instance.client;
      _isInitialized = true;
      developer.log('✅ CategoryRepository inicializado PEREZOSAMENTE.', name: 'CategoryRepository');
    }
  }

  /// Getter público para el cliente de Supabase.
  /// Activa la inicialización perezosa cuando es necesario.
  SupabaseClient get client {
    _ensureInitialized();
    if (_supabase == null) {
      throw Exception("¡ERROR FATAL! Supabase no está disponible para CategoryRepository.");
    }
    return _supabase!;
  }

  /// Obtiene una lista de categorías de GASTO (llamada única).
  /// Ideal para dropdowns en la creación de presupuestos o gastos.
  Future<List<Category>> getExpenseCategories() async {
    try {
      final data = await client
          .from('categories')
          .select()
          .eq('user_id', client.auth.currentUser!.id) // Siempre filtra por usuario
          .eq('type', 'expense') // La clave: solo tipo 'expense'
          .order('name', ascending: true);
          
      final categories = (data as List)
          .map((item) => Category.fromMap(item as Map<String, dynamic>))
          .toList();
      developer.log('✅ [Repo] Obtenidas ${categories.length} categorías de GASTO.', name: 'CategoryRepository');
      return categories;
    } catch (e, st) {
      developer.log('🔥 Error al obtener categorías de GASTO: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudieron cargar las categorías de gasto.');
    }
  }
  
  // Se elimina el método `initialize()` público.
  // void initialize(SupabaseClient supabaseClient) { ... } // <-- ELIMINADO

  // --- MÉTODOS PÚBLICOS DEL REPOSITORIO ---

  /// Devuelve un stream de las categorías del usuario desde un RPC.
  Stream<List<Category>> getCategoriesStream() {
    try {
      // Usa el getter `client` que asegura la inicialización.
      final rawStream = client.rpc('get_user_categories').asStream();

      return rawStream.map((dynamicRawList) {
        if (dynamicRawList is! List) {
          developer.log('⚠️ [RPC Stream] Se recibió un tipo de dato inesperado (no es una lista).', name: 'CategoryRepository');
          return <Category>[]; // Devolver lista vacía en caso de datos inválidos.
        }

        final List<Category> categoryList = dynamicRawList
            .map((item) => Category.fromMap(item as Map<String, dynamic>))
            .toList();
        
        developer.log('✅ [RPC Stream] Datos transformados: ${categoryList.length} categorías.', name: 'CategoryRepository');
        
        return categoryList;
      }).handleError((error, stackTrace) {
        developer.log('🔥 Error en el stream de categorías: $error', name: 'CategoryRepository', error: error, stackTrace: stackTrace);
        // Propagar el error por el stream para que la UI pueda reaccionar.
        return Stream.error(Exception('No se pudieron cargar las categorías en tiempo real.'));
      });

    } catch (e, st) {
      developer.log('🔥 Error al suscribirse al RPC stream: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      // Devolver un stream que emite un solo error.
      return Stream.error(Exception('No se pudieron cargar las categorías en tiempo real.'));
    }
  }

  /// Obtiene una lista de categorías (llamada única).
  Future<List<Category>> getCategories() async {
    try {
      final data = await client.rpc('get_user_categories');
      final categories = (data as List)
          .map((item) => Category.fromMap(item as Map<String, dynamic>))
          .toList();
      developer.log('✅ [Repo] Obtenidas ${categories.length} categorías vía RPC.', name: 'CategoryRepository');
      return categories;
    } catch (e, st) {
      developer.log('🔥 Error al obtener categorías vía RPC: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudieron cargar las categorías.');
    }
  }
  
  /// Añade una nueva categoría para el usuario actual.
  Future<void> addCategory(Category category) async {
    try {
      final data = category.toMap();
      // Asegurarse de que el user_id esté presente.
      data['user_id'] = client.auth.currentUser!.id;
      await client.from('categories').insert(data);
    } catch (e, st) {
      developer.log('🔥 Error al añadir categoría: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo crear la categoría.');
    }
  }

  /// Actualiza una categoría existente.
  Future<void> updateCategory(Category category) async {
    try {
      await client.from('categories').update(category.toMap()).eq('id', category.id);
    } catch (e, st) {
      developer.log('🔥 Error al actualizar categoría: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo actualizar la categoría.');
    }
  }

  /// Elimina una categoría por su ID.
  Future<void> deleteCategory(String categoryId) async {
    try {
      await client.from('categories').delete().eq('id', categoryId);
    } catch (e, st) {
      developer.log('🔥 Error al eliminar categoría: $e', name: 'CategoryRepository', error: e, stackTrace: st);
      throw Exception('No se pudo eliminar la categoría.');
    }
  }
}