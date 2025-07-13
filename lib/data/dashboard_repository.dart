import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_data_model.dart';
import '../services/widget_service.dart';
import 'dart:developer' as developer;

class DashboardRepository {
  final SupabaseClient _client;
  final _controller = StreamController<DashboardData>.broadcast();

  // Guardamos las suscripciones para poder cancelarlas después.
  final List<RealtimeChannel> _subscriptions = [];

  DashboardRepository(this._client) {
    _controller.onListen = () {
      developer.log('Stream is being listened to. Subscribing to DB changes...', name: 'DashboardRepository');
      _subscribeToChanges();
    };
    _controller.onCancel = () {
      developer.log('Stream is no longer listened to. Unsubscribing...', name: 'DashboardRepository');
      _unsubscribeFromChanges();
    };
  }

  Stream<DashboardData> getDashboardDataStream() {
    // La primera vez que alguien escucha, cargamos los datos.
    _fetchAndEmitData();
    return _controller.stream;
  }
  
  Future<void> _fetchAndEmitData() async {
    try {
      final data = await fetchDashboardData();
      if (!_controller.isClosed) {
        _controller.add(data);
      }
    } catch (e, stackTrace) {
      developer.log('Error fetching dashboard data', error: e, stackTrace: stackTrace, name: 'DashboardRepository');
      if (!_controller.isClosed) {
        _controller.addError(e, stackTrace);
      }
    }
  }

  Future<DashboardData> fetchDashboardData() async {
    final response = await _client.rpc('get_dashboard_data');
    WidgetService.updateBalanceWidget(); 
    developer.log("✅ RAW JSON from get_dashboard_data: $response", name: 'DashboardRepository');
    return DashboardData.fromJson(response as Map<String, dynamic>);
  }

  // --- MÉTODO CORREGIDO ---
  void _subscribeToChanges() {
    // Limpiamos suscripciones anteriores por si acaso
    _unsubscribeFromChanges();

    // CAMBIO: Usamos la nueva sintaxis con .onPostgresChanges
    final accountsChannel = _client
        .channel('public:accounts')
        .onPostgresChanges(
            event: PostgresChangeEvent.all, // Escucha INSERT, UPDATE, DELETE
            schema: 'public',
            table: 'accounts',
            callback: (payload) => _handleDbChange(payload, 'accounts'))
        .subscribe();

    final transactionsChannel = _client
        .channel('public:transactions')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'transactions',
            callback: (payload) => _handleDbChange(payload, 'transactions'))
        .subscribe();
        
    final budgetsChannel = _client
        .channel('public:budgets')
        .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'budgets',
            callback: (payload) => _handleDbChange(payload, 'budgets'))
        .subscribe();

    // Añadimos los canales a nuestra lista para poder gestionarlos
    _subscriptions.addAll([accountsChannel, transactionsChannel, budgetsChannel]);
  }

  void _handleDbChange(PostgresChangePayload payload, String table) {
      developer.log('DB Change detected on table: $table. Payload: ${payload.eventType}', name: 'DashboardRepository');
      // Cuando hay un cambio, simplemente volvemos a llamar a nuestra función RPC.
      _fetchAndEmitData();
  }

  void _unsubscribeFromChanges() {
    // Nos desuscribimos de todos los canales a los que nos conectamos
    for (final channel in _subscriptions) {
      channel.unsubscribe();
    }
    _subscriptions.clear();
  }
  
  Future<void> deleteTransaction(String transactionId) async {
    await _client.from('transactions').delete().match({'id': transactionId});
    // No necesitamos llamar a refresh manualmente, el stream lo detectará.
  }

  // Método para cerrar el controlador cuando el objeto ya no se use (buena práctica)
  void dispose() {
    _unsubscribeFromChanges();
    _controller.close();
  }
}