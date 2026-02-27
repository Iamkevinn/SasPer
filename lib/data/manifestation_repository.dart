import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart'; // Asegúrate de importar 'package:path/path.dart'
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../models/manifestation_model.dart'; // Importa tu nuevo modelo

class ManifestationRepository {
  final _supabase = Supabase.instance.client;
  final _imagePicker = ImagePicker();

  // Obtener todas las manifestaciones de un usuario
  Future<List<Manifestation>> getManifestations() async {
  try {
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      // No hay usuario autenticado en este momento
      if (kDebugMode) {
        print('ManifestationRepository: currentUser is null — returning empty list');
      }
      return [];
    }
    final userId = currentUser.id;

    final response = await _supabase
        .from('manifestations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List).map((item) => Manifestation.fromMap(item)).toList();
  } catch (e, st) {
    if (kDebugMode) {
      print('Error en getManifestations(): $e\n$st');
    }
    return [];
  }
}

  // Crear una nueva manifestación (lógica completa)
  Future<void> createManifestation({
    required String title,
    required XFile imageFile, // Pasamos el archivo directamente
    String? description,
    String? linkedGoalId,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final fileExtension = extension(imageFile.path).toLowerCase();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
    final filePath = '$userId/$fileName';

    // 1. Subir la imagen
    await _supabase.storage
        .from('manifestation_images')
        .upload(filePath, File(imageFile.path),
            fileOptions: FileOptions(contentType: 'image/${fileExtension.substring(1)}'));

    // 2. Obtener la URL
    final imageUrl = _supabase.storage
        .from('manifestation_images')
        .getPublicUrl(filePath);

    // 3. Insertar en la base de datos
    await _supabase.from('manifestations').insert({
      'user_id': userId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'linked_goal_id': linkedGoalId,
    });
  }
  
  // Función auxiliar para seleccionar la imagen
  Future<XFile?> pickImage() async {
    return await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
  }

  // --- NUEVA FUNCIÓN DE ACTUALIZACIÓN ---
  Future<void> updateManifestation({
    required String manifestationId,
    required String title,
    String? description,
    XFile? newImageFile, // La nueva imagen es opcional
    String? oldImageUrl, // Necesario para borrar la imagen vieja si se cambia
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final Map<String, dynamic> updateData = {
      'title': title,
      'description': description,
    };

    // Si el usuario seleccionó una nueva imagen...
    if (newImageFile != null) {
      // 1. Borramos la imagen antigua del storage para no dejar basura
      if (oldImageUrl != null && oldImageUrl.isNotEmpty) {
        try {
          final oldImagePath = Uri.parse(oldImageUrl).pathSegments.last;
          await _supabase.storage.from('manifestation_images').remove(['$userId/$oldImagePath']);
        } catch (e) {
          // Loggear el error pero continuar, es posible que el archivo ya no existiera
          if (kDebugMode) {
            print('Error al borrar imagen antigua: $e');
          }
        }
      }

      // 2. Subimos la nueva imagen
      final fileExtension = extension(newImageFile.path).toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = '$userId/$fileName';
      await _supabase.storage.from('manifestation_images').upload(
        filePath,
        File(newImageFile.path),
        fileOptions: FileOptions(contentType: 'image/${fileExtension.substring(1)}'),
      );
      
      // 3. Obtenemos la nueva URL y la añadimos a los datos a actualizar
      final newImageUrl = _supabase.storage.from('manifestation_images').getPublicUrl(filePath);
      updateData['image_url'] = newImageUrl;
    }

    // 4. Actualizamos el registro en la base de datos
    await _supabase
        .from('manifestations')
        .update(updateData)
        .eq('id', manifestationId);
  }

  // --- NUEVA FUNCIÓN DE ELIMINACIÓN ---
  Future<void> deleteManifestation({
    required String manifestationId,
    required String imageUrl,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    // 1. Borrar la imagen del Storage primero
    try {
      // Extraemos la ruta del archivo desde la URL pública
      final imagePath = Uri.parse(imageUrl).pathSegments.last;
      await _supabase.storage.from('manifestation_images').remove(['$userId/$imagePath']);
    } catch (e) {
      // Es importante loggear el error, pero no detener el proceso.
      // Si la imagen no existe, aún queremos borrar el registro de la DB.
      if (kDebugMode) {
        print('No se pudo borrar la imagen del storage (puede que ya no exista): $e');
      }
    }

    // 2. Borrar el registro de la tabla 'manifestations'
    await _supabase
        .from('manifestations')
        .delete()
        .eq('id', manifestationId);
  }
}