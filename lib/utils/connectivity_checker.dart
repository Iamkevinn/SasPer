import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityChecker {
  static final ConnectivityChecker _instance = ConnectivityChecker._();
  static ConnectivityChecker get instance => _instance;
  
  ConnectivityChecker._();

  final Connectivity _connectivity = Connectivity();

  /// Verifica si hay conexión a internet
  Future<bool> hasConnection() async {
    try {
      // El resultado ahora es una lista, por ejemplo: [ConnectivityResult.wifi, ConnectivityResult.mobile]
      final result = await _connectivity.checkConnectivity();

      // SOLUCIÓN: Verificamos si en la lista hay CUALQUIER resultado
      // que sea diferente a 'none'.
      // Esto devuelve 'true' si hay al menos una conexión activa.
      return result.any((connectivity) => connectivity != ConnectivityResult.none);

    } catch (e) {
      // Asume sin conexión en caso de error
      return false;
    }
  }

  /// Espera hasta que haya conexión (con timeout)
  Future<bool> waitForConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      if (await hasConnection()) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    return false;
  }
}