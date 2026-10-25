import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';

enum WsConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

/// Service managing authenticated WebSocket connection to /api/v1/ws/security/alarms
class SecurityWebSocketService {
  final SecureStorageService _storageService;
  WebSocket? _socket;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  bool _isDisposed = false;
  bool _isIntentionalDisconnect = false;
  int _connectionGeneration = 0;
  WsConnectionStatus _status = WsConnectionStatus.disconnected;
  final ValueNotifier<WsConnectionStatus> statusNotifier =
      ValueNotifier<WsConnectionStatus>(WsConnectionStatus.disconnected);

  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;
  WsConnectionStatus get status => _status;

  // Deduplication cache: event_id -> DateTime received
  final Map<String, DateTime> _seenEventIds = {};

  SecurityWebSocketService({SecureStorageService? storageService})
      : _storageService = storageService ?? SecureStorageService();

  void _setStatus(WsConnectionStatus newStatus) {
    if (_isDisposed) return;
    _status = newStatus;
    if (statusNotifier.value != newStatus) {
      statusNotifier.value = newStatus;
    }
  }

  /// Connect or re-connect to the Security Alarms WebSocket endpoint
  Future<void> connect() async {
    if (_isDisposed) return;
    if (_status == WsConnectionStatus.connected ||
        _status == WsConnectionStatus.connecting) {
      return;
    }

    _isIntentionalDisconnect = false;
    final int generation = ++_connectionGeneration;

    _setStatus(_status == WsConnectionStatus.disconnected
        ? WsConnectionStatus.connecting
        : WsConnectionStatus.reconnecting);

    final token = await _storageService.getAccessToken();
    if (_isDisposed ||
        _isIntentionalDisconnect ||
        _connectionGeneration != generation) {
      return;
    }

    if (token == null || token.isEmpty) {
      debugPrint('[SecurityWS] No token available for WebSocket connection');
      _setStatus(WsConnectionStatus.disconnected);
      return;
    }

    try {
      final base = ApiConstants.baseUrl;
      final uri = Uri.parse(base);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final wsUri = Uri(
        scheme: wsScheme,
        host: uri.host,
        port: uri.port,
        path: ApiConstants.securityAlarmWs,
        queryParameters: {'token': token},
      );

      debugPrint('[SecurityWS] Connecting to: $wsUri');

      final socket = await WebSocket.connect(
        wsUri.toString(),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      if (_isDisposed ||
          _isIntentionalDisconnect ||
          _connectionGeneration != generation) {
        try {
          socket.close();
        } catch (_) {}
        return;
      }

      _socket = socket;
      _setStatus(WsConnectionStatus.connected);
      _startHeartbeat();

      _subscription = _socket!.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: true,
      );
    } catch (e) {
      if (_isDisposed ||
          _isIntentionalDisconnect ||
          _connectionGeneration != generation) {
        return;
      }
      debugPrint('[SecurityWS] Connection error: $e');
      _handleDisconnectAndScheduleRetry();
    }
  }

  void _onMessage(dynamic data) {
    handleTestMessage(data);
  }

  @visibleForTesting
  void handleTestMessage(dynamic data) {
    try {
      final String text =
          data is String ? data : utf8.decode(data as List<int>);
      final dynamic decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) return;

      final eventId = decoded['event_id'] as String?;
      if (eventId != null && eventId.isNotEmpty) {
        // Deduplication: ignore if processed within last 10 minutes
        final now = DateTime.now();
        _seenEventIds
            .removeWhere((_, time) => now.difference(time).inMinutes > 10);
        if (_seenEventIds.containsKey(eventId)) {
          debugPrint('[SecurityWS] Ignored duplicated event: $eventId');
          return;
        }
        _seenEventIds[eventId] = now;
      }

      _eventController.add(decoded);
    } catch (e) {
      debugPrint('[SecurityWS] Parse message error: $e');
    }
  }

  void _onError(dynamic error) {
    if (_isDisposed || _isIntentionalDisconnect) return;
    debugPrint('[SecurityWS] Socket stream error: $error');
    _handleDisconnectAndScheduleRetry();
  }

  void _onDone() {
    if (_isDisposed || _isIntentionalDisconnect) return;
    debugPrint('[SecurityWS] Socket stream closed');
    _handleDisconnectAndScheduleRetry();
  }

  void _handleDisconnectAndScheduleRetry() {
    _cleanupSocket();
    if (_isDisposed || _isIntentionalDisconnect) return;

    _setStatus(WsConnectionStatus.reconnecting);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed &&
          !_isIntentionalDisconnect &&
          _status != WsConnectionStatus.connected) {
        connect();
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_socket != null && _status == WsConnectionStatus.connected) {
        try {
          _socket!.add(jsonEncode({'type': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _cleanupSocket() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _subscription?.cancel();
    _subscription = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  /// Disconnect cleanly
  void disconnect() {
    _isIntentionalDisconnect = true;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSocket();
    _seenEventIds.clear();
    _setStatus(WsConnectionStatus.disconnected);
  }

  void dispose() {
    _isDisposed = true;
    disconnect();
    statusNotifier.dispose();
    _eventController.close();
  }
}
