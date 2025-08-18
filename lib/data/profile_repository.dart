// lib/data/profile_repository.dart

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sasper/models/profile_model.dart';
import 'package:image_picker/image_picker.dart';

class ProfileRepository {
  ProfileRepository._internal();
  static final ProfileRepository instance = ProfileRepository._internal();
  final _supabase = Supabase.instance.client;

  /// Obtiene los datos del perfil del usuario actual en un stream para actualizaciones en tiempo real.
  Stream<Profile> getUserProfileStream() {
    final userId = _supabase.auth.currentUser?.id;
    
    // Si no hay usuario logueado, devolvemos un stream con un perfil vacío y cerramos.
    if (userId == null) {
      // Usamos Stream.value para emitir un único valor y cerrar el stream.
      return Stream.value(Profile.empty());
    }

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((listOfMaps) {
          // --- CORRECCIÓN CLAVE AQUÍ ---
          // Si por alguna razón la lista está vacía (ej. perfil aún no creado),
          // devolvemos un objeto Profile con los datos mínimos necesarios (el ID)
          // en lugar de un Profile.empty() genérico.
          if (listOfMaps.isEmpty) {
            return Profile(id: userId, xpPoints: 0, fullName: 'Nuevo Usuario');
          }
          
          // Si hay datos, los parseamos como antes.
          return Profile.fromMap(listOfMaps.first);
        });
  }

  /// Permite al usuario seleccionar una imagen de la galería, subirla a Supabase Storage
  /// y actualizar la URL del avatar en su perfil.
  Future<void> uploadAvatar() async {
    final picker = ImagePicker();
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // 1. Permite al usuario seleccionar una imagen de la galería.
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      // El usuario canceló la selección.
      return;
    }

    // 2. Sube la imagen a Supabase Storage.
    // Creamos una ruta única para cada usuario, ej: 'avatars/USER_ID/avatar.png'
    final file = File(pickedFile.path);
    final fileExtension = pickedFile.path.split('.').last;
    final filePath = '$userId/avatar.$fileExtension';

    await _supabase.storage.from('avatars').upload(
      filePath,
      file,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: true), // 'upsert: true' sobrescribe la imagen si ya existe
    );

    // 3. Obtenemos la URL pública de la imagen que acabamos de subir.

    // 3. Obtenemos la URL pública...
    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

    // --- ¡AQUÍ ESTÁ LA MAGIA! ---
    // 4. Añadimos un timestamp a la URL para "romper" el caché.
    // Usamos `Uri.parse` para manipular la URL de forma segura.
    final urlWithTimestamp = Uri.parse(publicUrl).replace(queryParameters: {
      't': DateTime.now().millisecondsSinceEpoch.toString(),
    }).toString();

    // 5. Actualizamos la tabla 'profiles' con la nueva URL con el timestamp.
    await _supabase
        .from('profiles')
        .update({'avatar_url': urlWithTimestamp}) // Usamos la nueva URL
        .eq('id', userId);
  }
}