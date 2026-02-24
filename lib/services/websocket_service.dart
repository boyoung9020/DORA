import 'dart:async';
import 'dart:convert';
import 'dart:math' show pow;

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../utils/api_client.dart';

/// WebSocket service for realtime events.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;

  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  bool _manualDisconnect = false;

  Function(String eventType, Map<String, dynamic> data)? onEvent;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected && _channel != null) {
      return;
    }

    _manualDisconnect = false;

    try {
      final token = await ApiClient.getToken();
      if (token == null) {
        print('[WebSocket] No token. Skip connect.');
        return;
      }

      String wsBaseUrl;
      if (ApiClient.baseUrl.startsWith('https://')) {
        wsBaseUrl = ApiClient.baseUrl.replaceFirst('https://', 'wss://');
      } else if (ApiClient.baseUrl.startsWith('http://')) {
        wsBaseUrl = ApiClient.baseUrl.replaceFirst('http://', 'ws://');
      } else {
        wsBaseUrl = 'ws://${ApiClient.baseUrl}';
      }

      // 웹에서 HTTPS로 서빙되는 경우 ws:// → wss:// 강제 업그레이드
      if (kIsWeb && Uri.base.scheme == 'https') {
        wsBaseUrl = wsBaseUrl.replaceFirst('ws://', 'wss://');
      }

      final uri = Uri.parse(wsBaseUrl);
      final wsUrl = Uri(
        scheme: uri.scheme, // 이미 ws 또는 wss로 변환됨
        host: uri.host,
        port: uri.port,
        path: '/api/ws',
        queryParameters: {'token': token},
      );

      print('[WebSocket] Connecting: $wsUrl');

      await _subscription?.cancel();
      await _channel?.sink.close();
      _channel = WebSocketChannel.connect(wsUrl);

      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final eventType = data['type'] as String;
            final eventData = data['data'] as Map<String, dynamic>;

            print('[WebSocket] Event: $eventType');

            if (onEvent != null) {
              onEvent!(eventType, eventData);
            }
          } catch (e) {
            print('[WebSocket] Parse error: $e');
          }
        },
        onError: (error) {
          print('[WebSocket] Error: $error');
          _isConnected = false;
          _channel = null;
          _subscription = null;
          _scheduleReconnect();
        },
        onDone: () {
          print('[WebSocket] Closed');
          _isConnected = false;
          _channel = null;
          _subscription = null;
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      print('[WebSocket] Connected');
    } catch (e, stackTrace) {
      print('[WebSocket] Connect failed: $e');
      print('[WebSocket] Stacktrace: $stackTrace');
      _isConnected = false;
      _channel = null;
      _subscription = null;
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();

    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _isConnected = false;
    print('[WebSocket] Disconnected');
  }

  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    if (_isConnected) return;

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      print('[WebSocket] Max reconnect attempts reached. Stop.');
      return;
    }

    final delaySec = pow(2, _reconnectAttempts).toInt();
    print(
      '[WebSocket] Reconnect in ${delaySec}s ($_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySec), () async {
      if (_manualDisconnect || _isConnected) return;
      _reconnectAttempts++;
      await connect();
    });
  }

  void sendPing() {
    if (_isConnected && _channel != null) {
      _channel!.sink.add('ping');
    }
  }
}
