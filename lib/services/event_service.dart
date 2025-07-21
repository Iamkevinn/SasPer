// lib/services/event_service.dart
import 'dart:async';

enum AppEvent {
  transactionsChanged,
  transactionDeleted,
  accountCreated,
  accountUpdated,
  budgetsChanged,
  debtsChanged,
  goalUpdated,
  goalCreated,
  transactionUpdated, goalsChanged,
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