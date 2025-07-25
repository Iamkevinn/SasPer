// lib/services/event_service.dart (CORREGIDO)

import 'dart:async';

enum AppEvent {
  transactionCreated, // <-- AÑADIDO: Más específico
  transactionUpdated,
  transactionDeleted,
  transactionsChanged, // Genérico por si acaso
  accountCreated,
  accountUpdated,
  budgetsChanged,
  debtsChanged,
  goalCreated,
  goalUpdated,
  goalsChanged,
  recurringTransactionChanged,
}

class EventService {
  EventService._internal();
  static final EventService _instance = EventService._internal();
  static EventService get instance => _instance;

  final _eventController = StreamController<AppEvent>.broadcast();
  Stream<AppEvent> get eventStream => _eventController.stream;

  void fire(AppEvent event) {
    _eventController.add(event);
  }

  void dispose() {
    _eventController.close();
  }
}