import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import '../services/dcmiws_service.dart';

/// DCMIWS 실시간 이벤트 Provider
/// 
/// WebSocket을 통해 수신되는 실시간 이벤트를 관리하고 전파합니다.
/// - 통화 상태 이벤트
/// - 서버 알림
/// - 착신전환 변경 알림
class DCMIWSEventProvider extends ChangeNotifier {
  final DCMIWSService _wsService = DCMIWSService();
  
  // 이벤트 구독
  StreamSubscription? _eventSubscription;
  StreamSubscription? _connectionSubscription;
  
  // 연결 상태
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  // 최근 이벤트 목록 (최대 100개)
  final List<DCMIWSEvent> _recentEvents = [];
  List<DCMIWSEvent> get recentEvents => List.unmodifiable(_recentEvents);
  
  // 통화 상태 맵 (extensionId -> CallState)
  final Map<String, CallState> _callStates = {};
  Map<String, CallState> get callStates => Map.unmodifiable(_callStates);
  
  // 알림 콜백
  final List<Function(DCMIWSEvent)> _eventCallbacks = [];

  /// WebSocket 연결 및 이벤트 구독 시작
  Future<bool> connect({
    required String serverAddress,
    required int port,
    bool useSSL = false,
  }) async {
    try {
      // WebSocket 연결
      final connected = await _wsService.connect(
        serverAddress: serverAddress,
        port: port,
        useSSL: useSSL,
      );

      if (!connected) {
        return false;
      }

      // 연결 상태 구독
      _connectionSubscription = _wsService.connectionState.listen((isConnected) {
        _isConnected = isConnected;
        notifyListeners();
        
        if (kDebugMode) {
          debugPrint('🔌 DCMIWS Connection: ${isConnected ? "Connected" : "Disconnected"}');
        }
      });

      // 이벤트 구독
      _eventSubscription = _wsService.events.listen(_handleEvent);
      
      _isConnected = true;
      notifyListeners();
      
      if (kDebugMode) {
        debugPrint('✅ DCMIWS EventProvider: Connected and subscribed');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS EventProvider: Connection failed - $e');
      }
      return false;
    }
  }

  /// 이벤트 핸들러
  void _handleEvent(Map<String, dynamic> eventData) {
    try {
      final event = DCMIWSEvent.fromJson(eventData);
      
      // 최근 이벤트 목록에 추가 (최대 100개)
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 100) {
        _recentEvents.removeLast();
      }
      
      // 이벤트 타입별 처리
      _processEvent(event);
      
      // 등록된 콜백 실행
      for (final callback in _eventCallbacks) {
        callback(event);
      }
      
      notifyListeners();
      
      if (kDebugMode) {
        debugPrint('📨 DCMIWS Event: ${event.eventType} - ${event.description}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DCMIWS EventProvider: Failed to parse event - $e');
      }
    }
  }

  /// 이벤트 타입별 처리
  void _processEvent(DCMIWSEvent event) {
    switch (event.eventType) {
      case 'Newchannel':
        _handleNewChannel(event);
        break;
      case 'Hangup':
        _handleHangup(event);
        break;
      case 'DialBegin':
        _handleDialBegin(event);
        break;
      case 'DialEnd':
        _handleDialEnd(event);
        break;
      case 'Bridge':
        _handleBridge(event);
        break;
      default:
        // 기타 이벤트
        break;
    }
  }

  /// 새 채널 생성 이벤트
  void _handleNewChannel(DCMIWSEvent event) {
    final extension = event.data['Exten'] as String?;
    if (extension != null) {
      _callStates[extension] = CallState(
        extension: extension,
        state: 'ringing',
        timestamp: event.timestamp,
        channelId: event.data['Channel'] as String?,
      );
    }
  }

  /// 통화 종료 이벤트
  void _handleHangup(DCMIWSEvent event) {
    final channel = event.data['Channel'] as String?;
    if (channel != null) {
      // 해당 채널의 extension 찾기
      final extension = _callStates.entries
          .where((entry) => entry.value.channelId == channel)
          .firstOrNull
          ?.key;
      
      if (extension != null) {
        _callStates.remove(extension);
      }
    }
  }

  /// 다이얼 시작 이벤트
  void _handleDialBegin(DCMIWSEvent event) {
    final extension = event.data['Exten'] as String?;
    if (extension != null) {
      _callStates[extension] = CallState(
        extension: extension,
        state: 'dialing',
        timestamp: event.timestamp,
        channelId: event.data['Channel'] as String?,
        destinationNumber: event.data['DestExten'] as String?,
      );
    }
  }

  /// 다이얼 종료 이벤트
  void _handleDialEnd(DCMIWSEvent event) {
    final extension = event.data['Exten'] as String?;
    final dialStatus = event.data['DialStatus'] as String?;
    
    if (extension != null) {
      if (dialStatus == 'ANSWER') {
        _callStates[extension] = CallState(
          extension: extension,
          state: 'answered',
          timestamp: event.timestamp,
          channelId: event.data['Channel'] as String?,
        );
      } else {
        _callStates.remove(extension);
      }
    }
  }

  /// 브리지 이벤트 (통화 연결)
  void _handleBridge(DCMIWSEvent event) {
    final channel1 = event.data['Channel1'] as String?;
    final channel2 = event.data['Channel2'] as String?;
    
    // 두 채널이 연결되었음을 표시
    for (final entry in _callStates.entries) {
      if (entry.value.channelId == channel1 || entry.value.channelId == channel2) {
        _callStates[entry.key] = entry.value.copyWith(state: 'connected');
      }
    }
  }

  /// 이벤트 콜백 등록
  void addEventCallback(Function(DCMIWSEvent) callback) {
    _eventCallbacks.add(callback);
  }

  /// 이벤트 콜백 제거
  void removeEventCallback(Function(DCMIWSEvent) callback) {
    _eventCallbacks.remove(callback);
  }

  /// 특정 단말번호의 통화 상태 조회
  CallState? getCallState(String extension) {
    return _callStates[extension];
  }

  /// 연결 해제
  Future<void> disconnect() async {
    await _eventSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _wsService.disconnect();
    
    _eventSubscription = null;
    _connectionSubscription = null;
    _isConnected = false;
    _callStates.clear();
    
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// DCMIWS 이벤트 모델
class DCMIWSEvent {
  final String eventType;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final String? description;

  DCMIWSEvent({
    required this.eventType,
    required this.timestamp,
    required this.data,
    this.description,
  });

  factory DCMIWSEvent.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    final eventType = data['Event'] as String? ?? 'Unknown';
    
    return DCMIWSEvent(
      eventType: eventType,
      timestamp: DateTime.now(),
      data: data,
      description: _generateDescription(eventType, data),
    );
  }

  /// 이벤트 설명 생성
  static String? _generateDescription(String eventType, Map<String, dynamic> data) {
    switch (eventType) {
      case 'Newchannel':
        final exten = data['Exten'] as String?;
        return exten != null ? '$exten 단말에서 전화 수신' : null;
      case 'Hangup':
        return '통화 종료';
      case 'DialBegin':
        final dest = data['DestExten'] as String?;
        return dest != null ? '$dest로 전화 걸기 시작' : '전화 걸기 시작';
      case 'DialEnd':
        final status = data['DialStatus'] as String?;
        return status == 'ANSWER' ? '통화 연결됨' : '통화 연결 실패';
      case 'Bridge':
        return '통화 채널 연결';
      default:
        return null;
    }
  }
}

/// 통화 상태 모델
class CallState {
  final String extension;
  final String state; // ringing, dialing, answered, connected
  final DateTime timestamp;
  final String? channelId;
  final String? destinationNumber;

  CallState({
    required this.extension,
    required this.state,
    required this.timestamp,
    this.channelId,
    this.destinationNumber,
  });

  CallState copyWith({
    String? extension,
    String? state,
    DateTime? timestamp,
    String? channelId,
    String? destinationNumber,
  }) {
    return CallState(
      extension: extension ?? this.extension,
      state: state ?? this.state,
      timestamp: timestamp ?? this.timestamp,
      channelId: channelId ?? this.channelId,
      destinationNumber: destinationNumber ?? this.destinationNumber,
    );
  }

  /// 한글 상태 문자열
  String get stateKorean {
    switch (state) {
      case 'ringing':
        return '수신 중';
      case 'dialing':
        return '발신 중';
      case 'answered':
        return '응답함';
      case 'connected':
        return '통화 중';
      default:
        return state;
    }
  }

  /// 상태 아이콘
  IconData get stateIcon {
    switch (state) {
      case 'ringing':
        return Icons.phone_in_talk;
      case 'dialing':
        return Icons.phone_callback;
      case 'answered':
      case 'connected':
        return Icons.call;
      default:
        return Icons.phone;
    }
  }

  /// 상태 색상
  Color get stateColor {
    switch (state) {
      case 'ringing':
        return Colors.blue;
      case 'dialing':
        return Colors.orange;
      case 'answered':
      case 'connected':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
