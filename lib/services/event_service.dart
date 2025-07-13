// lib/services/event_service.dart

import 'dart:async';

// Definimos los tipos de eventos que pueden ocurrir.
enum AppEvent { transactionCreated,transactionDeleted, accountCreated, accountDeleted,transactionsChanged }

class EventService {
  // Hacemos la clase un Singleton para tener una única instancia.
  EventService._privateConstructor();
  static final EventService instance = EventService._privateConstructor();

  // El StreamController que manejará los eventos.
  final _eventController = StreamController<AppEvent>.broadcast();

  // Stream público para que los widgets se suscriban.
  Stream<AppEvent> get eventStream => _eventController.stream;

  // Método para emitir un evento.
  void emit(AppEvent event) {
    _eventController.add(event);
  }

  // Método para cerrar el controller cuando la app se cierre (buena práctica).
  void dispose() {
    _eventController.close();
  }
}