import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'dashboard_screen.dart';
import 'main_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Escuchamos los cambios en el estado de autenticación
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Si hay un error en el stream, mostramos la pantalla de login
        if (snapshot.hasError) {
          return const LoginScreen();
        }

        // Si el stream tiene datos y hay una sesión activa...
        if (snapshot.hasData && snapshot.data?.session != null) {
          // ...mostramos el Dashboard
          //return const DashboardScreen();
          return const MainScreen();
        } else {
          // ...de lo contrario, mostramos la pantalla de Login
          return const LoginScreen();
        }
      },
    );
  }
}