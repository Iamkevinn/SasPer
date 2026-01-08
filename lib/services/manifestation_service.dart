import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManifestationService {
  final supabase = Supabase.instance.client;

  // --- Función principal para crear una nueva manifestación ---
  Future<void> createManifestation({
    required String title,
    String? description,
    String? linkedGoalId,
  }) async {
    try {
      // 1. SELECCIONAR LA IMAGEN DESDE LA GALERÍA
      final ImagePicker picker = ImagePicker();
      final XFile? imageFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024, // Reducimos el tamaño para optimizar la subida
        imageQuality: 85, // Comprimimos la calidad ligeramente
      );

      if (imageFile == null) {
        // El usuario canceló la selección de imagen
        if (kDebugMode) {
          print("El usuario no seleccionó ninguna imagen.");
        }
        return; 
      }

      // 2. PREPARAR LA IMAGEN PARA LA SUBIDA
      final imageBytes = await imageFile.readAsBytes();
      final userId = supabase.auth.currentUser!.id;
      // Creamos un nombre de archivo único para evitar colisiones
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      // Esta es la ruta que respeta nuestras políticas de Storage
      final filePath = '$userId/$fileName'; 

      // 3. SUBIR LA IMAGEN A SUPABASE STORAGE
      await supabase.storage
          .from('manifestation_images') // Nombre de nuestro bucket
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: FileOptions(
              upsert: true, // Si por alguna razón existiera un archivo con el mismo nombre, lo sobrescribe
              contentType: 'image/$fileExtension',
            ),
          );

      // 4. OBTENER LA URL PÚBLICA DE LA IMAGEN SUBIDA
      final imageUrl = supabase.storage
          .from('manifestation_images')
          .getPublicUrl(filePath);

      // 5. GUARDAR LOS DATOS EN LA TABLA 'manifestations'
      await supabase.from('manifestations').insert({
        'user_id': userId,
        'title': title,
        'description': description,
        'image_url': imageUrl,
        'linked_goal_id': linkedGoalId, // Será null si no se proporciona
      });

      if (kDebugMode) {
        print("¡Manifestación creada con éxito!");
      }

    } catch (e) {
      // Manejo de errores
      if (kDebugMode) {
        print("Error creando la manifestación: $e");
      }
      // Aquí podrías mostrar un snackbar o dialog al usuario
      throw Exception("No se pudo crear la manifestación.");
    }
  }
}