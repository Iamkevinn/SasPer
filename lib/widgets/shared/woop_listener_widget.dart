// lib/widgets/shared/woop_listener_widget.dart

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sasper/services/woop_constants.dart';
import 'package:sasper/services/notification_service.dart' show kWoopIsolatePort;
import 'package:sasper/widgets/shared/woop_victory_sheet.dart';
import 'package:sasper/main.dart'; // 👇 IMPORTANTE: Para acceder al navigatorKey global

class WoopListenerWidget extends StatefulWidget {
  final Widget child;
  const WoopListenerWidget({super.key, required this.child});

  @override
  State<WoopListenerWidget> createState() => _WoopListenerWidgetState();
}

class _WoopListenerWidgetState extends State<WoopListenerWidget>
    with WidgetsBindingObserver {

  DateTime? _sheetOpenedAt;
  bool get _sheetVisible {
    if (_sheetOpenedAt == null) return false;
    if (DateTime.now().difference(_sheetOpenedAt!) > const Duration(seconds: 30)) {
      _sheetOpenedAt = null;
      developer.log('⚠️ Safety-net: _sheetOpenedAt reseteado por timeout', name: 'WoopListener');
      return false;
    }
    return true;
  }

  String? _lastProcessedTapId;
  final ReceivePort _receivePort = ReceivePort();
  StreamSubscription? _portSub;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _registerPort();

    _portSub = _receivePort.listen((message) {
      developer.log('⚡ Mensaje recibido via IsolateNameServer: $message', name: 'WoopListener');
      _handlePayloadString(message as String);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _pullPending());
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) => _pullPending());
  }

  void _registerPort() {
    IsolateNameServer.removePortNameMapping(kWoopIsolatePort);
    final ok = IsolateNameServer.registerPortWithName(
      _receivePort.sendPort,
      kWoopIsolatePort,
    );
    developer.log('✅ Puerto WOOP registrado: $ok', name: 'WoopListener');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      developer.log('▶️ App resumed — revisando payload pendiente...', name: 'WoopListener');
      _registerPort();
      _pullPending();
    }
  }

  Future<void> _handlePayloadString(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tapId = data['tapId']?.toString() ?? '';

      if (tapId.isEmpty || tapId == _lastProcessedTapId) return;

      // Esperar a que la app esté visible antes de lanzar el sheet
      final state = WidgetsBinding.instance.lifecycleState;
      if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
        return; // Lo procesará _pullPending más tarde al reanudar
      }

      final navContext = navigatorKey.currentContext;
      if (navContext == null) return;

      _lastProcessedTapId = tapId;
      final manifestationId = data['manifestationId']?.toString() ?? '';
      final title = data['title']?.toString() ?? 'Tu meta';

      if (manifestationId.isNotEmpty) {
        _showSheet(manifestationId: manifestationId, title: title, navContext: navContext);
      }
    } catch (e) {
      developer.log('🔥 Error procesando payload: $e', name: 'WoopListener');
    }
  }

  Future<void> _pullPending() async {
    if (_sheetVisible || !mounted) return;

    final state = WidgetsBinding.instance.lifecycleState;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(kPendingWoopPayload);

      if (raw == null || raw.isEmpty) return;

      developer.log('🔍 Payload encontrado en disco: $raw', name: 'WoopListener');

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final tapId = data['tapId']?.toString();

      if (tapId == null || tapId.isEmpty) {
        await prefs.remove(kPendingWoopPayload);
        return;
      }

      if (tapId == _lastProcessedTapId) {
        await prefs.remove(kPendingWoopPayload);
        return;
      }

      final navContext = navigatorKey.currentContext;
      if (navContext == null) {
        developer.log('⚠️ navigatorContext no listo. Reintentando luego...', name: 'WoopListener');
        return;
      }

      // ─── Limpiar el disco ANTES de mostrar el sheet para evitar doble disparo
      await prefs.remove(kPendingWoopPayload);
      _lastProcessedTapId = tapId;

      final manifestationId = data['manifestationId']?.toString() ?? '';
      final title = data['title']?.toString() ?? 'Tu meta';

      if (manifestationId.isNotEmpty && mounted) {
        _showSheet(manifestationId: manifestationId, title: title, navContext: navContext);
      }
    } catch (e) {
      developer.log('🔥 Error en polling: $e', name: 'WoopListener');
    }
  }

  void _showSheet({
    required String manifestationId,
    required String title,
    required BuildContext navContext,
  }) {
    if (_sheetVisible || !mounted) return;

    developer.log('🎉 Mostrando WoopVictorySheet — $title ($manifestationId)', name: 'WoopListener');
    _sheetOpenedAt = DateTime.now();

    showModalBottomSheet(
      context: navContext, // 👇 Usa el navContext global
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WoopVictorySheet(
        manifestationId: manifestationId,
        title: title,
      ),
    ).whenComplete(() {
      _sheetOpenedAt = null;
      developer.log('✅ WoopVictorySheet cerrado', name: 'WoopListener');
    });
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping(kWoopIsolatePort);
    _portSub?.cancel();
    _receivePort.close();
    _pollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}