import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../screens/call/incoming_call_screen.dart';

/// DCMIWS WebSocket 서비스
/// 
/// DIPCAST DCMIWS API를 위한 WebSocket 통신 관리 서비스
/// - 연결 관리 (연결, 재연결, 종료)
/// - 메시지 송수신 (착신전환 조회/설정, 클릭투콜)
/// - 에러 처리 및 로깅
class DCMIWSService {
  // Singleton 패턴
  static final DCMIWSService _instance = DCMIWSService._internal();
  factory DCMIWSService() => _instance;
  DCMIWSService._internal();

  // WebSocket 연결
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  // 연결 상태
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // 재연결 로직
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);
  
  // 응답 대기 맵 (ActionID -> Completer)
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  
  // 연결 상태 스트림
  final StreamController<bool> _connectionStateController = 
      StreamController<bool>.broadcast();
  Stream<bool> get connectionState => _connectionStateController.stream;
  
  // 이벤트 스트림 (서버 푸시 이벤트)
  final StreamController<Map<String, dynamic>> _eventController = 
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventController.stream;
  
  // BuildContext 저장 (수신 전화 화면 표시용)
  static BuildContext? _context;
  
  /// BuildContext 설정 (main.dart에서 호출)
  static void setContext(BuildContext context) {
    _context = context;
  }

  /// WebSocket 연결
  /// 
  /// [serverAddress] - WebSocket 서버 주소 (예: 'makecall.io')
  /// [port] - WebSocket 포트 (예: 7099)
  /// [useSSL] - SSL 사용 여부 (기본값: false)
  Future<bool> connect({
    required String serverAddress,
    required int port,
    bool useSSL = false,
  }) async {
    if (_isConnected) {
      if (kDebugMode) {
        debugPrint('🔌 DCMIWS: Already connected');
      }
      return true;
    }

    try {
      final protocol = useSSL ? 'wss' : 'ws';
      final uri = Uri.parse('$protocol://$serverAddress:$port');
      
      if (kDebugMode) {
        debugPrint('🔌 DCMIWS: Connecting to $uri');
      }

      _channel = WebSocketChannel.connect(uri);
      
      // 연결 성공 대기 (타임아웃 10초)
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Connection timeout');
        },
      );
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      
      if (kDebugMode) {
        debugPrint('✅ DCMIWS: Connected successfully');
      }

      // 메시지 수신 리스너
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Connection failed: $e');
      }
      _isConnected = false;
      _connectionStateController.add(false);
      _scheduleReconnect(serverAddress, port, useSSL);
      return false;
    }
  }

  /// 연결 종료
  Future<void> disconnect() async {
    if (kDebugMode) {
      debugPrint('🔌 DCMIWS: Disconnecting');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    await _subscription?.cancel();
    _subscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    _isConnected = false;
    _connectionStateController.add(false);
    
    // 대기 중인 요청 취소
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError('Connection closed');
      }
    }
    _pendingRequests.clear();
    
    if (kDebugMode) {
      debugPrint('✅ DCMIWS: Disconnected');
    }
  }

  /// 재연결 스케줄링
  void _scheduleReconnect(String serverAddress, int port, bool useSSL) {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Max reconnect attempts reached');
      }
      return;
    }

    _reconnectAttempts++;
    
    if (kDebugMode) {
      debugPrint('🔄 DCMIWS: Scheduling reconnect (attempt $_reconnectAttempts/$_maxReconnectAttempts)');
    }

    _reconnectTimer = Timer(_reconnectDelay, () {
      connect(
        serverAddress: serverAddress,
        port: port,
        useSSL: useSSL,
      );
    });
  }

  /// 메시지 수신 핸들러
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = json.decode(message as String);
      
      if (kDebugMode) {
        debugPrint('📨 DCMIWS: Received message: $data');
      }

      // 🔔 수신 전화 이벤트 감지 (Newchannel)
      _checkIncomingCall(data);

      // ActionID로 대기 중인 요청 찾기
      final actionId = data['data']?['ActionID'] as String?;
      if (actionId != null && _pendingRequests.containsKey(actionId)) {
        final completer = _pendingRequests.remove(actionId);
        if (!completer!.isCompleted) {
          completer.complete(data);
        }
      } else {
        // 이벤트 메시지 (ActionID 없음 또는 요청하지 않은 응답)
        _eventController.add(data);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Failed to parse message: $e');
      }
    }
  }
  
  /// 수신 전화 이벤트 체크 및 처리
  void _checkIncomingCall(Map<String, dynamic> data) {
    try {
      // type이 3인지 확인 (Call Event)
      if (data['type'] != 3) return;
      
      final eventData = data['data'] as Map<String, dynamic>?;
      if (eventData == null) return;
      
      // Event가 "Newchannel"인지 확인
      final event = eventData['Event'] as String?;
      if (event != 'Newchannel') return;
      
      // Context가 "trk"로 시작하는지 확인
      final context = eventData['Context'] as String?;
      if (context == null || !context.startsWith('trk')) return;
      
      // CallerIDNum과 Exten 추출
      final callerIdNum = eventData['CallerIDNum'] as String?;
      final exten = eventData['Exten'] as String?;
      
      if (callerIdNum == null || exten == null) return;
      
      if (kDebugMode) {
        debugPrint('📞 수신 전화 감지!');
        debugPrint('  발신번호: $callerIdNum');
        debugPrint('  수신번호: $exten');
        debugPrint('  Context: $context');
      }
      
      // 수신 전화 화면 표시
      _showIncomingCallScreen(callerIdNum, exten, data);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 수신 전화 체크 오류: $e');
      }
    }
  }
  
  /// 수신 전화 풀스크린 표시
  void _showIncomingCallScreen(
    String callerNumber,
    String receiverNumber,
    Map<String, dynamic> callEventData,
  ) {
    if (_context == null) {
      if (kDebugMode) {
        debugPrint('❌ BuildContext가 설정되지 않았습니다');
      }
      return;
    }
    
    // CallerIDName이 있으면 사용, 없으면 번호 사용
    final eventData = callEventData['data'] as Map<String, dynamic>;
    final callerName = (eventData['CallerIDName'] as String?)?.isNotEmpty == true
        ? eventData['CallerIDName'] as String
        : callerNumber;
    
    if (kDebugMode) {
      debugPrint('📞 수신 전화 화면 표시:');
      debugPrint('  발신자: $callerName');
      debugPrint('  발신번호: $callerNumber');
      debugPrint('  수신번호: $receiverNumber');
    }
    
    Navigator.of(_context!).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => IncomingCallScreen(
          callerName: callerName,
          callerNumber: callerNumber,
          callerAvatar: null,
          onAccept: () {
            Navigator.of(context).pop();
            // TODO: 전화 수락 로직 (SIP 연결 등)
            if (kDebugMode) {
              debugPrint('✅ 전화 수락됨: $callerNumber → $receiverNumber');
            }
          },
          onReject: () {
            Navigator.of(context).pop();
            // TODO: 전화 거절 로직 (서버 통신 등)
            if (kDebugMode) {
              debugPrint('❌ 전화 거절됨: $callerNumber → $receiverNumber');
            }
          },
        ),
      ),
    );
  }

  /// 에러 핸들러
  void _handleError(dynamic error) {
    if (kDebugMode) {
      debugPrint('❌ DCMIWS: WebSocket error: $error');
    }
    _isConnected = false;
    _connectionStateController.add(false);
  }

  /// 연결 해제 핸들러
  void _handleDisconnection() {
    if (kDebugMode) {
      debugPrint('🔌 DCMIWS: Connection closed by server');
    }
    _isConnected = false;
    _connectionStateController.add(false);
  }

  /// 메시지 전송 (응답 대기)
  /// 
  /// [amiServerId] - AMI 서버 ID (1, 2, ...)
  /// [action] - Action 타입 ('Command', 'Originate', 'ping')
  /// [actionId] - 고유 ActionID
  /// [data] - 추가 데이터 (Command, Variable 등)
  /// [timeout] - 응답 대기 시간 (기본 10초)
  Future<Map<String, dynamic>> sendRequest({
    required int amiServerId,
    required String action,
    required String actionId,
    Map<String, dynamic>? data,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isConnected) {
      throw Exception('Not connected to WebSocket server');
    }

    // 요청 데이터 구성
    final requestData = {
      'AMIServerID': amiServerId,
      'data': {
        'Action': action,
        'ActionID': actionId,
        ...?data,
      },
    };

    if (kDebugMode) {
      debugPrint('📤 DCMIWS: Sending request: $requestData');
    }

    // Completer 생성 및 등록
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[actionId] = completer;

    try {
      // 메시지 전송
      _channel!.sink.add(json.encode(requestData));

      // 응답 대기 (타임아웃 처리)
      final response = await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingRequests.remove(actionId);
          throw TimeoutException('Request timeout: $actionId');
        },
      );

      return response;
    } catch (e) {
      _pendingRequests.remove(actionId);
      rethrow;
    }
  }

  /// Ping 테스트 (서버 상태 확인)
  Future<Map<String, dynamic>> ping({
    required int amiServerId,
  }) async {
    final actionId = 'DIPCAST-CoreServiceCheck-$amiServerId-${DateTime.now().millisecondsSinceEpoch}';
    
    return sendRequest(
      amiServerId: amiServerId,
      action: 'ping',
      actionId: actionId,
    );
  }

  /// 착신전환 활성화 여부 조회
  /// 
  /// [amiServerId] - AMI 서버 ID
  /// [tenantId] - 테넌트 ID
  /// [extensionId] - 단말번호
  /// [diversionType] - 착신전환 타입 (CFI, CFB, CFN, CFU)
  Future<bool> getCallForwardEnabled({
    required int amiServerId,
    required String tenantId,
    required String extensionId,
    String diversionType = 'CFI',
  }) async {
    final actionId = 'DIPCAST-$amiServerId-$tenantId-$extensionId-$diversionType-get-${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final response = await sendRequest(
        amiServerId: amiServerId,
        action: 'Command',
        actionId: actionId,
        data: {
          'Command': 'database get $tenantId diversions/$extensionId/$diversionType/enable',
        },
      );

      // 응답 파싱: Output: "Value: yes" or "Value: no"
      final output = response['data']?['Output'] as String?;
      if (output != null && output.contains('Value:')) {
        final value = output.split('Value:').last.trim();
        return value.toLowerCase() == 'yes';
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Failed to get call forward status: $e');
      }
      return false;
    }
  }

  /// 착신번호 조회
  /// 
  /// [amiServerId] - AMI 서버 ID
  /// [tenantId] - 테넌트 ID
  /// [extensionId] - 단말번호
  /// [diversionType] - 착신전환 타입 (CFI, CFB, CFN, CFU)
  /// 
  /// Returns: 착신번호 (예: "01099552471") 또는 null
  Future<String?> getCallForwardDestination({
    required int amiServerId,
    required String tenantId,
    required String extensionId,
    String diversionType = 'CFI',
  }) async {
    final actionId = 'DIPCAST-$amiServerId-$tenantId-$extensionId-$diversionType-destination-${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final response = await sendRequest(
        amiServerId: amiServerId,
        action: 'Command',
        actionId: actionId,
        data: {
          'Command': 'database get $tenantId diversions/$extensionId/$diversionType/destination',
        },
      );

      // 응답 파싱: Output: "Value: sub-custom-numbers,01099552471,1"
      final output = response['data']?['Output'] as String?;
      if (output != null && output.contains('Value:')) {
        final value = output.split('Value:').last.trim();
        // 형식: sub-custom-numbers,전화번호,1
        if (value.contains(',')) {
          final parts = value.split(',');
          if (parts.length >= 2) {
            return parts[1].trim();
          }
        }
      }

      // Database entry not found인 경우
      if (output != null && output.contains('Database entry not found')) {
        return null;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Failed to get call forward destination: $e');
      }
      return null;
    }
  }

  /// 착신전환 활성화/비활성화
  Future<bool> setCallForwardEnabled({
    required int amiServerId,
    required String tenantId,
    required String extensionId,
    required bool enabled,
    String diversionType = 'CFI',
  }) async {
    final value = enabled ? 'yes' : 'no';
    final actionId = 'DIPCAST-$amiServerId-$tenantId-$extensionId-$diversionType-$value-${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final response = await sendRequest(
        amiServerId: amiServerId,
        action: 'Command',
        actionId: actionId,
        data: {
          'Command': 'database put $tenantId diversions/$extensionId/$diversionType/enable $value',
        },
      );

      // 성공 확인: Output: "Updated database successfully"
      final output = response['data']?['Output'] as String?;
      return output != null && output.contains('Updated database successfully');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Failed to set call forward status: $e');
      }
      return false;
    }
  }

  /// 착신번호 설정
  Future<bool> setCallForwardDestination({
    required int amiServerId,
    required String tenantId,
    required String extensionId,
    required String destination,
    String diversionType = 'CFI',
  }) async {
    final actionId = 'DIPCAST-$amiServerId-$tenantId-$extensionId-$diversionType-set-$destination-${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final response = await sendRequest(
        amiServerId: amiServerId,
        action: 'Command',
        actionId: actionId,
        data: {
          'Command': 'database put $tenantId diversions/$extensionId/$diversionType/destination sub-custom-numbers,$destination,1',
        },
      );

      // 성공 확인
      final output = response['data']?['Output'] as String?;
      return output != null && output.contains('Updated database successfully');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Failed to set call forward destination: $e');
      }
      return false;
    }
  }

  /// 클릭투콜 (WebSocket 방식)
  Future<bool> originateCall({
    required int amiServerId,
    required String extensionId,
    required String callee,
    required String accountCode,
    String? callerIdName,
    String? callerIdNumber,
  }) async {
    final actionId = 'DIPCAST-C2C-$extensionId-$callee-${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final response = await sendRequest(
        amiServerId: amiServerId,
        action: 'Originate',
        actionId: actionId,
        data: {
          'Channel': 'Local/$extensionId@T2_cos-all',
          'Context': 'T2_cos-all',
          'Exten': callee,
          'Priority': '1',
          'Timeout': '30000',
          'Variables': [
            'EXEC_AA=yes',
            'CHANNEL(language)=ko',
            'CHANNEL(accountcode)=$accountCode',
          ],
          if (callerIdName != null || callerIdNumber != null)
            'Callerid': '${callerIdName ?? ""} <${callerIdNumber ?? ""}>',
          'EarlyMedia': 'true',
          'Async': 'yes',
        },
      );

      // 성공 확인
      final responseStatus = response['data']?['Response'] as String?;
      return responseStatus == 'Success';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS: Failed to originate call: $e');
      }
      return false;
    }
  }

  /// 서비스 정리
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _eventController.close();
  }
}
