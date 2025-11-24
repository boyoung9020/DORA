import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/api_client.dart';

/// WebSocket 서비스 클래스
/// 실시간 이벤트 수신 및 데이터 동기화
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  
  // 이벤트 콜백
  Function(String eventType, Map<String, dynamic> data)? onEvent;
  
  bool get isConnected => _isConnected;
  
  /// WebSocket 연결
  Future<void> connect() async {
    if (_isConnected && _channel != null) {
      return;
    }
    
    try {
      final token = await ApiClient.getToken();
      if (token == null) {
        print('[WebSocket] 토큰이 없어 연결할 수 없습니다.');
        return;
      }
      
      // WebSocket URL 생성
      // 토큰을 URL 인코딩하여 특수 문자 문제 방지
      final encodedToken = Uri.encodeComponent(token);
      
      // baseUrl에서 프로토콜 추출 및 변환
      String wsBaseUrl;
      if (ApiClient.baseUrl.startsWith('https://')) {
        wsBaseUrl = ApiClient.baseUrl.replaceFirst('https://', 'wss://');
      } else if (ApiClient.baseUrl.startsWith('http://')) {
        wsBaseUrl = ApiClient.baseUrl.replaceFirst('http://', 'ws://');
      } else {
        // 프로토콜이 없으면 ws:// 추가
        wsBaseUrl = 'ws://${ApiClient.baseUrl}';
      }
      
      // URI를 사용하여 안전하게 URL 생성
      final uri = Uri.parse(wsBaseUrl);
      final wsUrl = Uri(
        scheme: uri.scheme == 'https' ? 'wss' : 'ws',
        host: uri.host,
        port: uri.port,
        path: '/api/ws',
        queryParameters: {'token': token}, // Uri.encodeComponent는 queryParameters에서 자동 처리됨
      );
      
      print('[WebSocket] 연결 시도: $wsUrl');
      
      _channel = WebSocketChannel.connect(wsUrl);
      
      _subscription = _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String) as Map<String, dynamic>;
            final eventType = data['type'] as String;
            final eventData = data['data'] as Map<String, dynamic>;
            
            print('[WebSocket] 이벤트 수신: $eventType');
            
            // 이벤트 콜백 호출
            if (onEvent != null) {
              onEvent!(eventType, eventData);
            }
          } catch (e) {
            print('[WebSocket] 메시지 파싱 오류: $e');
          }
        },
        onError: (error) {
          print('[WebSocket] 오류: $error');
          _isConnected = false;
        },
        onDone: () {
          print('[WebSocket] 연결 종료');
          _isConnected = false;
        },
      );
      
      _isConnected = true;
      print('[WebSocket] 연결 성공');
    } catch (e, stackTrace) {
      print('[WebSocket] 연결 실패: $e');
      print('[WebSocket] 스택 트레이스: $stackTrace');
      _isConnected = false;
    }
  }
  
  /// WebSocket 연결 해제
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _isConnected = false;
    print('[WebSocket] 연결 해제됨');
  }
  
  /// 하트비트 전송 (연결 유지)
  void sendPing() {
    if (_isConnected && _channel != null) {
      _channel!.sink.add('ping');
    }
  }
}

