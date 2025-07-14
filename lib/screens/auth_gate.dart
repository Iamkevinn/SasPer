import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'package:sas_per/services/updateUserFCMToken.dart'; // Asegúrate de que la ruta es correcta

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en el estado de autenticación
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Mientras el stream se está conectando, es buena idea mostrar un loader.
        // Si no, puede haber un "parpadeo" a la pantalla de login antes de detectar la sesión.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Si hay un error en el stream, mostramos la pantalla de login
        if (snapshot.hasError) {
          return const LoginScreen();
        }

        // Si el stream tiene datos y hay una sesión activa...
        if (snapshot.hasData && snapshot.data?.session != null) {
          
          // --- ¡AQUÍ ESTÁ LA LÓGICA CLAVE! ---
          // El usuario está autenticado, así que intentamos actualizar su token de FCM.
          // Llamamos a la función aquí. No usamos 'await' porque no queremos
          // detener la construcción de la UI. La función se ejecutará en segundo plano.
          updateUserFCMToken();

          // ...mostramos la MainScreen
          return const MainScreen();
        } else {
          // ...de lo contrario, mostramos la pantalla de Login
          return const LoginScreen();
        }
      },
    );
  }
}