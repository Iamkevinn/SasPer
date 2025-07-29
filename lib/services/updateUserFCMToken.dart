import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> updateUserFCMToken() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user != null) {
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          // Actualiza el perfil del usuario con el nuevo token
          await supabase
              .from('profiles')
              .update({'fcm_token': token})
              .eq('id', user.id); // 'id' es la columna que vincula al usuario de auth
              
          if (kDebugMode) {
            print('Token FCM actualizado en Supabase para el usuario: ${user.id}');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error al actualizar el token FCM en Supabase: $e');
        }
      }
    }
  }