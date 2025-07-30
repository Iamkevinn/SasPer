// lib/config/global_state.dart

// Este booleano será compartido entre todos los Isolates.
// Lo usaremos como una bandera para asegurarnos de que solo
// inicializamos Supabase una vez.
class GlobalState {
  static bool supabaseInitialized = false;
}