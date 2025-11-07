import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../screens/call/incoming_call_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/contact_helper.dart';

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
  
  // 📝 클릭투콜 임시 저장소 (Newchannel 이벤트 대기용)
  // Key: extensionNumber, Value: 통화 기록 데이터 + 타임스탬프
  final Map<String, Map<String, dynamic>> _pendingClickToCallRecords = {};
  
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
  
  // NavigatorKey 저장 (수신 전화 화면 표시용)
  static GlobalKey<NavigatorState>? _navigatorKey;
  
  /// NavigatorKey 설정 (main.dart에서 호출)
  static void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  // 🔒 연결 중복 방지를 위한 Lock
  bool _isConnecting = false;
  String? _connectedUri; // 현재 연결된 URI 추적

  /// WebSocket 연결 (중복 연결 방지 강화)
  /// 
  /// [serverAddress] - WebSocket 서버 주소 (예: 'makecall.io')
  /// [port] - WebSocket 포트 (예: 7099)
  /// [useSSL] - SSL 사용 여부 (기본값: false)
  Future<bool> connect({
    required String serverAddress,
    required int port,
    bool useSSL = false,
  }) async {
    final protocol = useSSL ? 'wss' : 'ws';
    final targetUri = '$protocol://$serverAddress:$port';
    
    // 🔒 중복 연결 방지 체크 1: 이미 같은 서버에 연결 중인 경우
    if (_isConnected && _connectedUri == targetUri) {
      if (kDebugMode) {
        debugPrint('✅ DCMIWS: Already connected to $targetUri');
      }
      return true;
    }
    
    // 🔒 중복 연결 방지 체크 2: 연결 시도 중인 경우 (Race condition 방지)
    if (_isConnecting) {
      if (kDebugMode) {
        debugPrint('⏳ DCMIWS: Connection already in progress, waiting...');
      }
      
      // 최대 15초 대기하면서 연결 완료 확인
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_isConnecting) {
          // 연결 완료됨
          if (_isConnected && _connectedUri == targetUri) {
            if (kDebugMode) {
              debugPrint('✅ DCMIWS: Connection completed by another request');
            }
            return true;
          }
          break;
        }
      }
      
      // 여전히 연결 중이면 false 반환
      if (_isConnecting) {
        if (kDebugMode) {
          debugPrint('⚠️ DCMIWS: Connection still in progress after timeout');
        }
        return false;
      }
    }
    
    // 🔒 중복 연결 방지 체크 3: 다른 서버에 연결된 경우 먼저 종료
    if (_isConnected && _connectedUri != targetUri) {
      if (kDebugMode) {
        debugPrint('🔄 DCMIWS: Disconnecting from $_connectedUri to connect to $targetUri');
      }
      await disconnect();
    }

    // 🔐 연결 시작 Lock 설정
    _isConnecting = true;
    
    try {
      final uri = Uri.parse(targetUri);
      
      if (kDebugMode) {
        debugPrint('🔌 DCMIWS: Connecting to $uri');
        debugPrint('  Current state: Connected=$_isConnected, Connecting=$_isConnecting');
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
      _connectedUri = targetUri; // 연결된 URI 기록
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      
      if (kDebugMode) {
        debugPrint('✅ DCMIWS: Connected successfully to $targetUri');
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
      _connectedUri = null;
      _connectionStateController.add(false);
      _scheduleReconnect(serverAddress, port, useSSL);
      return false;
    } finally {
      // 🔓 연결 시도 완료, Lock 해제
      _isConnecting = false;
    }
  }

  /// 연결 종료 (중복 종료 방지)
  Future<void> disconnect() async {
    // 🔒 이미 종료된 경우 스킵
    if (!_isConnected && _channel == null && _subscription == null) {
      if (kDebugMode) {
        debugPrint('✅ DCMIWS: Already disconnected');
      }
      return;
    }
    
    if (kDebugMode) {
      debugPrint('🔌 DCMIWS: Disconnecting from $_connectedUri');
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    
    await _subscription?.cancel();
    _subscription = null;
    
    await _channel?.sink.close();
    _channel = null;
    
    _isConnected = false;
    _isConnecting = false; // Lock 해제
    _connectedUri = null; // URI 초기화
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

  // 🔔 활성 수신 전화 추적 (linkedid -> 수신 정보)
  final Map<String, Map<String, dynamic>> _activeIncomingCalls = {};

  /// 메시지 수신 핸들러
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = json.decode(message as String);
      
      if (kDebugMode) {
        debugPrint('📨 DCMIWS: Received message: $data');
      }

      // 🔔 수신 전화 이벤트 감지 (Newchannel) - 비동기 처리
      _checkIncomingCall(data);
      
      // 📞 클릭투콜 linkedid 저장 (UserEvent) - 클릭투콜 통화 기록 추적
      // ⚠️ 주석 처리: 통화상세 조회 기능 비활성화
      // _checkUserEvent(data);
      
      // 📞 통화 연결 이벤트 감지 (BridgeEnter) - 자동 확인 처리
      _checkBridgeEnter(data);

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
  Future<void> _checkIncomingCall(Map<String, dynamic> data) async {
    try {
      // type이 3인지 확인 (Call Event)
      if (data['type'] != 3) return;
      
      final eventData = data['data'] as Map<String, dynamic>?;
      if (eventData == null) return;
      
      // Event가 "Newchannel"인지 확인
      final event = eventData['Event'] as String?;
      if (event != 'Newchannel') return;
      
      // CallerIDNum, Exten, Channel, Linkedid, Context 추출 (클릭투콜 체크를 위해 먼저 추출)
      final callerIdNum = eventData['CallerIDNum'] as String?;
      final exten = eventData['Exten'] as String?;
      final channel = eventData['Channel'] as String?;
      final linkedid = eventData['Linkedid'] as String?;
      final context = eventData['Context'] as String?;
      
      // 🚫 CRITICAL: Click-to-call 체크를 Ring 체크보다 먼저 수행!
      // Click-to-call은 ChannelStateDesc가 "Ring"이 아니므로 먼저 처리해야 함
      if (context != null && context.toLowerCase().contains('click-to-call')) {
        if (exten == null || linkedid == null) {
          if (kDebugMode) {
            debugPrint('⚠️ Click-to-call 이벤트이지만 필수 필드 누락');
            debugPrint('  Exten: $exten');
            debugPrint('  Linkedid: $linkedid');
          }
          return;
        }
        
        if (kDebugMode) {
          debugPrint('📞 Click-to-call 발신 감지 - Linkedid 저장');
          debugPrint('  Channel: $channel');
          debugPrint('  Context: $context');
          debugPrint('  Linkedid: $linkedid');
          debugPrint('  Exten: $exten');
        }
        
        // Linkedid를 클릭투콜 통화 기록에 저장 (재생성)
        await _saveClickToCallLinkedId(linkedid, exten);
        return;
      }
      
      // ChannelStateDesc가 "Ring"인지 확인 (수신 통화만 처리)
      final channelStateDesc = eventData['ChannelStateDesc'] as String?;
      if (channelStateDesc != 'Ring') return;
      
      if (callerIdNum == null || exten == null) return;
      if (channel == null || linkedid == null) return;
      
      if (kDebugMode) {
        debugPrint('📞 수신 전화 감지!');
        debugPrint('  발신번호 (CallerIDNum): $callerIdNum');
        debugPrint('  수신번호 (Exten): $exten');
        debugPrint('  Channel: $channel');
        debugPrint('  Linkedid: $linkedid');
        debugPrint('  Context: $context');
        debugPrint('  ChannelStateDesc: $channelStateDesc');
      }
      
      // 🔐 my_extensions 유효성 검사 (등록된 내선번호인지 확인)
      final isValidExtension = await _validateMyExtension(exten);
      if (!isValidExtension) {
        if (kDebugMode) {
          debugPrint('⚠️ 등록되지 않은 내선번호: $exten');
          debugPrint('  해당 이벤트는 무시됩니다.');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('✅ 등록된 내선번호 확인됨: $exten');
      }
      
      // 🔍 통화 타입 감지 (외부 수신 / 내부 수신)
      final callType = await _detectCallType(exten, context);
      
      if (kDebugMode) {
        debugPrint('📞 통화 타입: $callType');
      }
      
      // 수신 전화 화면 표시 및 활성 통화 추적
      // Note: callerName은 _showIncomingCallScreen 내부에서 결정 후 업데이트됨
      _activeIncomingCalls[linkedid] = {
        'callerNumber': callerIdNum,
        'receiverNumber': exten,
        'channel': channel,
        'callType': callType,
        'callerName': null, // 초기값 (나중에 업데이트)
      };
      
      _showIncomingCallScreen(callerIdNum, exten, channel, linkedid, data, callType);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 수신 전화 체크 오류: $e');
      }
    }
  }
  
  /// UserEvent 이벤트 체크 (클릭투콜 linkedid 저장)
  Future<void> _checkUserEvent(Map<String, dynamic> data) async {
    try {
      // type이 3인지 확인 (Call Event)
      if (data['type'] != 3) return;
      
      final eventData = data['data'] as Map<String, dynamic>?;
      if (eventData == null) return;
      
      // Event가 "UserEvent"인지 확인
      final event = eventData['Event'] as String?;
      if (event != 'UserEvent') return;
      
      // Linkedid 추출
      final linkedid = eventData['Linkedid'] as String?;
      if (linkedid == null) return;
      
      // 📞 클릭투콜 발신 linkedid 저장 로직
      // 필터 조건:
      // 1. CallerIDName="클릭투콜" 포함
      // 2. Channel에 "click-to-call" 텍스트 포함
      final callerIdName = eventData['CallerIDName'] as String?;
      final channel = eventData['Channel'] as String?;
      
      if (callerIdName != null && callerIdName.contains('클릭투콜') &&
          channel != null && channel.contains('click-to-call')) {
        
        // Channel에서 caller 추출: Local/{caller}@click-to-call-{sequence};{ch}
        String? caller;
        final channelMatch = RegExp(r'Local/(\d+)@click-to-call').firstMatch(channel);
        if (channelMatch != null) {
          caller = channelMatch.group(1);
        }
        
        // ConnectedLineNum에서 callee 추출
        final callee = eventData['ConnectedLineNum'] as String?;
        
        if (kDebugMode) {
          debugPrint('');
          debugPrint('='*60);
          debugPrint('📞 클릭투콜 UserEvent 감지!');
          debugPrint('='*60);
          debugPrint('  Event: ${eventData['Event']}');
          debugPrint('  CallerIDName: $callerIdName');
          debugPrint('  Channel: $channel');
          debugPrint('  → Caller (단말번호): ${caller ?? "(추출 실패)"}');
          debugPrint('  → Callee (착신번호): ${callee ?? "(없음)"}');
          debugPrint('  Linkedid: $linkedid');
          debugPrint('  전체 이벤트 데이터: $eventData');
          debugPrint('  → 최근 통화 기록에 linkedid 저장 시작...');
          debugPrint('='*60);
        }
        
        // 최근 클릭투콜 통화 기록에 linkedid 업데이트 (callee로 번호 매칭)
        await _updateRecentClickToCallWithLinkedId(linkedid, callee);
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ UserEvent 체크 오류: $e');
      }
    }
  }
  
  /// BridgeEnter 이벤트 체크 (단말에서 수신 확인)
  Future<void> _checkBridgeEnter(Map<String, dynamic> data) async {
    try {
      // type이 3인지 확인 (Call Event)
      if (data['type'] != 3) return;
      
      final eventData = data['data'] as Map<String, dynamic>?;
      if (eventData == null) return;
      
      // Event가 "BridgeEnter"인지 확인
      final event = eventData['Event'] as String?;
      if (event != 'BridgeEnter') return;
      
      // Linkedid 추출
      final linkedid = eventData['Linkedid'] as String?;
      if (linkedid == null) return;
      
      // 활성 수신 전화 목록에서 해당 linkedid 찾기
      final activeCall = _activeIncomingCalls[linkedid];
      if (activeCall == null) {
        // Click-to-call 통화이거나 이미 처리된 통화 - 조용히 무시
        return;
      }
      
      // 🚫 Click-to-call 이중 체크 (안전장치)
      final channel = activeCall['channel'] as String?;
      if (channel != null && channel.toLowerCase().contains('click-to-call')) {
        if (kDebugMode) {
          debugPrint('🚫 BridgeEnter: Click-to-call 통화 - 저장 제외');
          debugPrint('  Channel: $channel');
        }
        _activeIncomingCalls.remove(linkedid);
        return;
      }
      
      if (kDebugMode) {
        debugPrint('✅ BridgeEnter 감지: 단말에서 수신 확인됨');
        debugPrint('  Linkedid: $linkedid');
        debugPrint('  발신번호: ${activeCall['callerNumber']}');
        debugPrint('  수신번호: ${activeCall['receiverNumber']}');
      }
      
      // 통화 기록 저장 (단말 수신 확인)
      await _saveCallHistoryOnBridgeEnter(
        linkedid: linkedid,
        callerNumber: activeCall['callerNumber'] as String,
        callerName: activeCall['callerName'] as String? ?? activeCall['callerNumber'] as String,
        receiverNumber: activeCall['receiverNumber'] as String,
        channel: activeCall['channel'] as String,
        callType: activeCall['callType'] as String,
      );
      
      // 활성 통화 목록에서 제거
      _activeIncomingCalls.remove(linkedid);
      
      // IncomingCallScreen 자동 닫기 및 최근통화 탭으로 이동
      if (_navigatorKey?.currentState != null) {
        if (kDebugMode) {
          debugPrint('📱 IncomingCallScreen 자동 닫기');
        }
        _navigatorKey!.currentState!.pop({'moveToTab': 1}); // 1 = 최근통화 탭
        
        // 탭 이동 이벤트 전송
        _eventController.add({
          'type': 'MOVE_TO_TAB',
          'tabIndex': 1,
        });
        
        if (kDebugMode) {
          debugPrint('🔄 최근통화 탭 이동 이벤트 전송 (BridgeEnter 자동 확인)');
        }
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BridgeEnter 체크 오류: $e');
      }
    }
  }
  
  /// 클릭투콜 통화 기록에 linkedid 업데이트 (callee 번호 매칭)
  Future<void> _updateRecentClickToCallWithLinkedId(String linkedid, String? callee) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 로그인 정보가 없어 linkedid를 업데이트할 수 없습니다');
        }
        return;
      }
      
      // callee 번호 정규화 (callee가 있을 경우에만)
      final normalizedCallee = callee != null ? _normalizePhoneNumber(callee) : null;
      
      if (kDebugMode) {
        debugPrint('🔍 클릭투콜 통화 기록 검색 시작...');
        if (callee != null) {
          debugPrint('  - Callee (원본): $callee');
          debugPrint('  - Callee (정규화): $normalizedCallee');
        } else {
          debugPrint('  - Callee: (없음 - 시간 기반 매칭만 사용)');
        }
        debugPrint('  - Linkedid: $linkedid');
      }
      
      // 최근 10분 이내의 클릭투콜 통화 기록 조회 (5분 → 10분으로 확장)
      // ⚠️ Firebase Console에서 복합 인덱스 생성 필요
      // 인덱스 URL: https://console.firebase.google.com/v1/r/project/makecallio/firestore/indexes
      final tenMinutesAgo = DateTime.now().subtract(const Duration(minutes: 10));
      final querySnapshot = await firestore
          .collection('call_history')
          .where('userId', isEqualTo: userId)
          .where('callType', isEqualTo: 'outgoing')
          .where('callMethod', isEqualTo: 'extension')
          .orderBy('callTime', descending: true)
          .limit(20)  // 10 → 20으로 증가
          .get();
      
      if (kDebugMode) {
        debugPrint('📋 조회된 통화 기록: ${querySnapshot.docs.length}개');
      }
      
      // linkedid가 없는 최근 통화 기록 찾기
      // callee가 있으면 번호 매칭, 없으면 시간 기반으로만 매칭 (최신 기록 우선)
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final callTime = DateTime.parse(data['callTime'] as String);
        final existingLinkedId = data['linkedid'] as String?;
        final phoneNumber = data['phoneNumber'] as String?;
        final extensionUsed = data['extensionUsed'] as String?;
        
        if (kDebugMode) {
          debugPrint('  📞 확인 중: ${phoneNumber ?? "(번호 없음)"}');
          debugPrint('     - 통화 시간: $callTime');
          debugPrint('     - Linkedid 존재: ${existingLinkedId != null}');
        }
        
        // 기본 조건: 10분 이내 && linkedid가 없음 (5분 → 10분으로 확장)
        bool isMatch = callTime.isAfter(tenMinutesAgo) && existingLinkedId == null;
        
        // callee가 있으면 추가로 번호 매칭 확인
        if (isMatch && normalizedCallee != null && phoneNumber != null) {
          final normalizedPhoneNumber = _normalizePhoneNumber(phoneNumber);
          isMatch = normalizedPhoneNumber == normalizedCallee;
          
          if (kDebugMode) {
            debugPrint('     - 번호 매칭: ${isMatch ? "✅" : "❌"} (정규화: $normalizedPhoneNumber vs $normalizedCallee)');
          }
        } else if (isMatch && kDebugMode) {
          debugPrint('     - 번호 매칭: ⏭️ 건너뜀 (callee 정보 없음, 시간 기반 매칭만 사용)');
        }
        
        if (isMatch) {
          // 🚨 중복 처리 방지: 동일한 linkedid가 이미 있는지 재확인
          final duplicateCheck = await firestore
              .collection('call_history')
              .where('userId', isEqualTo: userId)
              .where('linkedid', isEqualTo: linkedid)
              .limit(1)
              .get();
          
          if (duplicateCheck.docs.isNotEmpty) {
            if (kDebugMode) {
              debugPrint('⚠️ 이미 동일한 Linkedid로 처리된 기록이 있습니다');
              debugPrint('  - Linkedid: $linkedid');
              debugPrint('  - 기존 문서 ID: ${duplicateCheck.docs.first.id}');
              debugPrint('  → 중복 처리 방지를 위해 건너뜁니다');
            }
            return;
          }
          
          // 🆕 임시 저장소 우선 확인
          if (_pendingClickToCallRecords.containsKey(extensionUsed)) {
            if (kDebugMode) {
              debugPrint('✅ 임시 저장소에서 발견! 임시 데이터로 생성');
            }
            await _createCallHistoryFromPending(extensionUsed!, linkedid);
            return; // 임시 데이터로 생성 완료
          }
          
          // 🔥 NEW APPROACH: 기존 문서 삭제 후 linkedid를 포함한 새 문서 생성
          // Linkedid는 통화 시작부터 끝까지 동일하므로 업데이트가 아닌 최초 생성 시 포함해야 함
          
          // 1. 기존 문서의 모든 데이터 복사
          final newDocData = Map<String, dynamic>.from(data);
          
          // 2. linkedid 추가
          newDocData['linkedid'] = linkedid;
          newDocData['updatedAt'] = FieldValue.serverTimestamp();
          
          // 3. 기존 문서 삭제
          await doc.reference.delete();
          
          // 4. linkedid를 포함한 새 문서 생성
          await firestore
              .collection('call_history')
              .add(newDocData);
          
          if (kDebugMode) {
            debugPrint('');
            debugPrint('✅ 클릭투콜 통화 기록 재생성 완료! (Linkedid 포함)');
            debugPrint('  - 기존 문서 ID (삭제됨): ${doc.id}');
            debugPrint('  - Linkedid: $linkedid');
            debugPrint('  - 발신번호 (callee): $phoneNumber');
            debugPrint('  - 통화 시간: $callTime');
            debugPrint('  - 착신전환 활성화: ${data['callForwardEnabled'] ?? false}');
            debugPrint('  - 착신전환 목적지: ${data['callForwardDestination'] ?? "없음"}');
            debugPrint('  → Linkedid는 최초 생성 시 포함되어 업데이트 불필요');
            debugPrint('');
          }
          
          return; // 첫 번째 매칭 기록만 처리
        }
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ 조건에 맞는 클릭투콜 기록을 찾을 수 없습니다');
        debugPrint('   - 최근 10분 이내 (확장됨: 5분 → 10분)');
        debugPrint('   - linkedid가 없음');
        if (normalizedCallee != null) {
          debugPrint('   - phoneNumber == $normalizedCallee');
        } else {
          debugPrint('   - phoneNumber 매칭: 건너뜀 (callee 정보 없음)');
        }
        debugPrint('');
        debugPrint('💡 Linkedid 누락 방지 팁:');
        debugPrint('   1. WebSocket 연결 상태 확인');
        debugPrint('   2. 통화 기록이 Firestore에 정상 저장되었는지 확인');
        debugPrint('   3. Newchannel 이벤트가 정상 수신되는지 확인');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 클릭투콜 linkedid 업데이트 오류: $e');
      }
    }
  }
  
  /// Newchannel 이벤트에서 클릭투콜 Linkedid 저장
  /// 
  /// Newchannel 이벤트 조건:
  /// - Event: "Newchannel"
  /// - ChannelStateDesc: "Ring"
  /// - Context: "click-to-call" 포함
  /// 
  /// 임시 저장소에서 데이터를 가져와 Firestore에 생성
  Future<void> _saveClickToCallLinkedId(String linkedid, String exten) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 로그인 정보가 없어 linkedid를 저장할 수 없습니다');
        }
        return;
      }
      
      if (kDebugMode) {
        debugPrint('🔍 클릭투콜 통화 기록 생성 시작 (Newchannel 이벤트)');
        debugPrint('  - Exten (단말번호): $exten');
        debugPrint('  - Linkedid: $linkedid');
      }
      
      // 🆕 임시 저장소 우선 확인
      if (_pendingClickToCallRecords.containsKey(exten)) {
        if (kDebugMode) {
          debugPrint('✅ 임시 저장소에서 발견! Linkedid와 함께 Firestore에 생성');
        }
        
        // 중복 확인
        final duplicateCheck = await firestore
            .collection('call_history')
            .where('userId', isEqualTo: userId)
            .where('linkedid', isEqualTo: linkedid)
            .limit(1)
            .get();
        
        if (duplicateCheck.docs.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('⚠️ 이미 동일한 Linkedid로 처리된 기록이 있습니다');
            debugPrint('  - Linkedid: $linkedid');
            debugPrint('  → 중복 처리 방지를 위해 건너뜁니다');
          }
          return;
        }
        
        await _createCallHistoryFromPending(exten, linkedid);
        return;
      }
      
      // 임시 저장소에 데이터가 없는 경우 → Fallback: 최근 Firestore 기록 검색
      // 원인: 10초 타임아웃이 먼저 발동하여 이미 Firestore에 저장됨
      if (kDebugMode) {
        debugPrint('⚠️ 임시 저장소에 데이터가 없습니다');
        debugPrint('   단말번호: $exten');
        debugPrint('   → Fallback: 최근 Firestore 기록에서 linkedid 없는 기록 검색');
      }
      
      // 최근 1분 이내의 통화 기록 중 linkedid가 없는 기록 찾기
      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      final querySnapshot = await firestore
          .collection('call_history')
          .where('userId', isEqualTo: userId)
          .where('callType', isEqualTo: 'outgoing')
          .where('callMethod', isEqualTo: 'extension')
          .where('extensionUsed', isEqualTo: exten)
          .orderBy('callTime', descending: true)
          .limit(5)
          .get();
      
      if (kDebugMode) {
        debugPrint('📋 조회된 최근 통화 기록: ${querySnapshot.docs.length}개');
      }
      
      // linkedid가 없고 시간 조건에 맞는 첫 번째 기록 찾기
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final callTime = DateTime.parse(data['callTime'] as String);
        final existingLinkedId = data['linkedid'] as String?;
        
        // 조건: 1분 이내 && linkedid가 없음
        if (callTime.isAfter(oneMinuteAgo) && existingLinkedId == null) {
          if (kDebugMode) {
            debugPrint('✅ 매칭된 기록 발견!');
            debugPrint('   - 문서 ID: ${doc.id}');
            debugPrint('   - 발신번호: ${data['phoneNumber']}');
            debugPrint('   - 통화 시간: $callTime');
            debugPrint('   → Linkedid 추가 업데이트 수행');
          }
          
          // 중복 확인 (이미 다른 이벤트로 처리되었는지)
          final currentData = await doc.reference.get();
          if (currentData.exists && currentData.data()?['linkedid'] != null) {
            if (kDebugMode) {
              debugPrint('⚠️ 다른 이벤트가 이미 처리했습니다 (건너뜀)');
            }
            return;
          }
          
          // Linkedid 추가
          await doc.reference.update({
            'linkedid': linkedid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          if (kDebugMode) {
            debugPrint('✅ Linkedid 추가 완료!');
            debugPrint('   - Linkedid: $linkedid');
          }
          
          return; // 첫 번째 매칭만 처리
        }
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ 조건에 맞는 통화 기록을 찾을 수 없습니다');
        debugPrint('   - 1분 이내 통화');
        debugPrint('   - linkedid 없음');
        debugPrint('   - extensionUsed == $exten');
      }
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 클릭투콜 Linkedid 저장 오류 (Newchannel): $e');
      }
    }
  }
  
  /// 전화번호 정규화 (하이픈 제거, 국가번호 통일)
  String _normalizePhoneNumber(String phoneNumber) {
    // 하이픈, 공백, 괄호 제거
    String normalized = phoneNumber.replaceAll(RegExp(r'[-\s()]'), '');
    
    // 국가번호 처리 (82로 시작하면 0으로 변경)
    if (normalized.startsWith('82')) {
      normalized = '0${normalized.substring(2)}';
    }
    
    // +82로 시작하면 0으로 변경
    if (normalized.startsWith('+82')) {
      normalized = '0${normalized.substring(3)}';
    }
    
    return normalized;
  }
  
  /// BridgeEnter 시 통화 기록 저장
  Future<void> _saveCallHistoryOnBridgeEnter({
    required String linkedid,
    required String callerNumber,
    required String callerName,
    required String receiverNumber,
    required String channel,
    required String callType,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 로그인 정보가 없어 통화 기록을 저장할 수 없습니다');
        }
        return;
      }
      
      // linkedid로 기존 통화 기록 확인
      final existingDoc = await firestore
          .collection('call_history')
          .doc(linkedid)
          .get();
      
      if (existingDoc.exists) {
        // 기존 문서 업데이트 (단말 수신 확인으로 상태 변경)
        await firestore
            .collection('call_history')
            .doc(linkedid)
            .update({
          'status': 'device_answered', // 단말 수신 확인
          'answeredAt': FieldValue.serverTimestamp(),
        });
        
        if (kDebugMode) {
          debugPrint('✅ 통화 기록 업데이트 완료 (단말 수신 확인)');
          debugPrint('  Linkedid: $linkedid');
        }
      } else {
        // 새 통화 기록 생성 (IncomingCallScreen에서 확인 버튼 누르지 않은 경우)
        final callHistory = {
          'userId': userId,
          'callerNumber': callerNumber,
          'callerName': callerName,
          'receiverNumber': receiverNumber,
          'channel': channel,
          'linkedid': linkedid,
          'callType': 'incoming',
          'callSubType': callType, // 'external', 'internal', 'unknown'
          'status': 'device_answered', // 단말 수신 확인
          'timestamp': FieldValue.serverTimestamp(),
          'answeredAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        };
        
        await firestore
            .collection('call_history')
            .doc(linkedid)
            .set(callHistory);
        
        if (kDebugMode) {
          debugPrint('✅ 통화 기록 생성 완료 (단말 수신 확인)');
          debugPrint('  Linkedid: $linkedid');
          debugPrint('  발신: $callerName ($callerNumber) → 수신: $receiverNumber');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ BridgeEnter 통화 기록 저장 오류: $e');
      }
    }
  }
  
  /// 통화 타입 감지 (외부 수신 / 내부 수신)
  /// 
  /// [exten] - Newchannel 이벤트의 Exten 필드
  /// [context] - Newchannel 이벤트의 Context 필드
  /// Returns: 'external' (외부 수신), 'internal' (내부 수신), 'unknown' (알 수 없음)
  Future<String> _detectCallType(String exten, String? context) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return 'unknown';
      
      final firestore = FirebaseFirestore.instance;
      
      // 1️⃣ 외부 수신 통화 감지
      // Context가 "trk"로 시작하고, accountCode == exten인 경우
      if (context != null && context.startsWith('trk')) {
        final accountCodeQuery = await firestore
            .collection('my_extensions')
            .where('userId', isEqualTo: userId)
            .where('accountCode', isEqualTo: exten)
            .limit(1)
            .get();
        
        if (accountCodeQuery.docs.isNotEmpty) {
          if (kDebugMode) {
            debugPrint('✅ 외부 수신 통화 감지');
            debugPrint('  Context: $context (trk로 시작)');
            debugPrint('  accountCode: $exten');
          }
          return 'external';
        }
      }
      
      // 2️⃣ 내부 수신 통화 감지
      // extension == exten인 경우
      final extensionQuery = await firestore
          .collection('my_extensions')
          .where('userId', isEqualTo: userId)
          .where('extension', isEqualTo: exten)
          .limit(1)
          .get();
      
      if (extensionQuery.docs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ 내부 수신 통화 감지');
          debugPrint('  extension: $exten');
        }
        return 'internal';
      }
      
      // 일치하는 조건 없음
      if (kDebugMode) {
        debugPrint('⚠️ 통화 타입을 감지할 수 없습니다');
      }
      return 'unknown';
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 통화 타입 감지 오류: $e');
      }
      return 'unknown';
    }
  }
  
  /// my_extensions 컬렉션에서 내선번호 유효성 검사
  /// 
  /// [exten] - 확인할 내선번호 (Newchannel 이벤트의 Exten 필드)
  /// Returns: true = 등록된 내선번호, false = 미등록 내선번호
  Future<bool> _validateMyExtension(String exten) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;
      
      // 로그인하지 않은 경우 검증 실패
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 로그인 정보가 없어 내선번호 검증을 수행할 수 없습니다');
        }
        return false;
      }
      
      // 1️⃣ extension 필드와 일치하는지 확인
      final extensionQuery = await firestore
          .collection('my_extensions')
          .where('userId', isEqualTo: userId)
          .where('extension', isEqualTo: exten)
          .limit(1)
          .get();
      
      if (extensionQuery.docs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ my_extensions 검증 성공 (extension 필드 일치)');
          debugPrint('  userId: $userId');
          debugPrint('  extension: $exten');
        }
        return true;
      }
      
      // 2️⃣ accountCode 필드와 일치하는지 확인
      final accountCodeQuery = await firestore
          .collection('my_extensions')
          .where('userId', isEqualTo: userId)
          .where('accountCode', isEqualTo: exten)
          .limit(1)
          .get();
      
      if (accountCodeQuery.docs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('✅ my_extensions 검증 성공 (accountCode 필드 일치)');
          debugPrint('  userId: $userId');
          debugPrint('  accountCode: $exten');
        }
        return true;
      }
      
      // 일치하는 내선번호 없음
      if (kDebugMode) {
        debugPrint('❌ my_extensions 검증 실패');
        debugPrint('  userId: $userId');
        debugPrint('  exten: $exten');
        debugPrint('  등록된 내선번호가 아닙니다');
      }
      return false;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ my_extensions 검증 중 오류 발생: $e');
      }
      return false;
    }
  }
  
  /// 수신 전화 풀스크린 표시
  Future<void> _showIncomingCallScreen(
    String callerNumber,
    String receiverNumber,
    String channel,
    String linkedid,
    Map<String, dynamic> callEventData,
    String callType,
  ) async {
    if (_navigatorKey?.currentState == null) {
      if (kDebugMode) {
        debugPrint('❌ NavigatorKey가 설정되지 않았거나 Navigator가 준비되지 않았습니다');
      }
      return;
    }
    
    // 1️⃣ CallerIDName 추출
    final eventData = callEventData['data'] as Map<String, dynamic>;
    String? callerName = eventData['CallerIDName'] as String?;
    
    // 2️⃣ 연락처 조회 (이름 + 사진) - 항상 조회 시도
    String? contactName;
    Uint8List? contactPhoto;
    
    try {
      if (kDebugMode) {
        debugPrint('🔍 기기 연락처에서 조회 중...');
      }
      
      final contactInfo = await ContactHelper().getContactInfoByPhone(callerNumber);
      
      if (contactInfo != null) {
        contactName = contactInfo['name'] as String?;
        contactPhoto = contactInfo['photo'] as Uint8List?;
        
        if (kDebugMode) {
          debugPrint('✅ 연락처 찾음!');
          debugPrint('  이름: $contactName');
          debugPrint('  사진: ${contactPhoto != null ? "${contactPhoto.length} bytes" : "없음"}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('📞 연락처에 없음');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 연락처 조회 실패: $e');
      }
    }
    
    // 3️⃣ CallerIDName 우선순위 결정
    // 연락처에서 찾은 이름 > CallerIDName > 전화번호
    if (contactName != null && contactName.isNotEmpty) {
      // 연락처에서 찾은 이름 사용
      callerName = contactName;
    } else if (callerName == null || callerName.isEmpty || callerName == '<unknown>') {
      // CallerIDName이 없으면 전화번호 사용
      callerName = callerNumber;
    }
    
    // 4️⃣ 최종 callerName 보장 (null 방지)
    final finalCallerName = callerName ?? callerNumber;
    
    // 📝 활성 통화 목록에 callerName 업데이트
    if (_activeIncomingCalls.containsKey(linkedid)) {
      _activeIncomingCalls[linkedid]!['callerName'] = finalCallerName;
      if (kDebugMode) {
        debugPrint('📝 활성 통화 목록 업데이트: $linkedid');
        debugPrint('  발신자: $finalCallerName ($callerNumber)');
      }
    }
    
    // 5️⃣ 내 단말번호 정보 가져오기 (companyName, 외부발신 표시번호, 외부발신 이름/번호)
    String? myCompanyName;
    String? myOutboundCid;
    String? myExternalCidName;
    String? myExternalCidNumber;
    
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        if (kDebugMode) {
          debugPrint('🔍 내 단말번호 정보 조회 시작');
          debugPrint('  receiverNumber (Exten): $receiverNumber');
          debugPrint('  callType: $callType');
        }
        
        // 통화 타입에 따라 다른 필드로 조회
        QuerySnapshot querySnapshot;
        
        if (callType == 'external') {
          // 외부 수신: accountCode로 조회
          if (kDebugMode) {
            debugPrint('  🌍 외부 수신 통화 → accountCode로 조회');
          }
          querySnapshot = await FirebaseFirestore.instance
              .collection('my_extensions')
              .where('userId', isEqualTo: userId)
              .where('accountCode', isEqualTo: receiverNumber)
              .limit(1)
              .get();
        } else {
          // 내부 수신: extension으로 조회
          if (kDebugMode) {
            debugPrint('  🏢 내부 수신 통화 → extension으로 조회');
          }
          querySnapshot = await FirebaseFirestore.instance
              .collection('my_extensions')
              .where('userId', isEqualTo: userId)
              .where('extension', isEqualTo: receiverNumber)
              .limit(1)
              .get();
        }
        
        if (querySnapshot.docs.isNotEmpty) {
          final extensionData = querySnapshot.docs.first.data() as Map<String, dynamic>;
          final docExten = extensionData['extension'] as String?;
          myOutboundCid = extensionData['outboundCID'] as String?;
          myExternalCidName = extensionData['externalCidName'] as String?;
          myExternalCidNumber = extensionData['externalCidNumber'] as String?;
          
          if (kDebugMode) {
            debugPrint('✅ my_extensions 조회 성공!');
            debugPrint('  문서 ID: ${querySnapshot.docs.first.id}');
            debugPrint('  extension: $docExten');
            debugPrint('  accountCode: ${extensionData['accountCode']}');
            debugPrint('  outboundCID: $myOutboundCid');
            debugPrint('  externalCidName: $myExternalCidName');
            debugPrint('  externalCidNumber: $myExternalCidNumber');
          }
        } else {
          if (kDebugMode) {
            debugPrint('❌ my_extensions 조회 실패: 일치하는 문서 없음');
          }
        }
        
        // users 컬렉션에서 companyName 가져오기
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (userDoc.exists) {
          myCompanyName = userDoc.data()?['companyName'] as String?;
          
          if (kDebugMode) {
            debugPrint('  조직명: $myCompanyName');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ 내 단말번호 정보 조회 실패: $e');
      }
    }
    
    if (kDebugMode) {
      debugPrint('📞 수신 전화 화면 표시:');
      debugPrint('  발신자: $finalCallerName');
      debugPrint('  발신번호 (CallerIDNum): $callerNumber');
      debugPrint('  수신번호: $receiverNumber');
      debugPrint('  Channel: $channel');
      debugPrint('  Linkedid: $linkedid');
    }
    
    final result = await _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => IncomingCallScreen(
          callerName: finalCallerName,
          callerNumber: callerNumber, // CallerIDNum 값 사용
          callerAvatar: null,
          contactPhoto: contactPhoto,
          channel: channel,
          linkedid: linkedid,
          receiverNumber: receiverNumber,
          callType: callType,
          myCompanyName: myCompanyName,
          myOutboundCid: myOutboundCid,
          myExternalCidName: myExternalCidName,
          myExternalCidNumber: myExternalCidNumber,
          onAccept: () {
            Navigator.of(context).pop();
            // TODO: 전화 수락 로직 (SIP 연결 등)
            if (kDebugMode) {
              debugPrint('✅ 전화 수락됨: $callerNumber → $receiverNumber');
              debugPrint('  Channel: $channel');
              debugPrint('  Linkedid: $linkedid');
            }
            // 통화 기록 저장
            _saveCallHistory(
              callerNumber: callerNumber,
              callerName: finalCallerName,
              receiverNumber: receiverNumber,
              channel: channel,
              linkedid: linkedid,
              callType: 'incoming',
              status: 'accepted',
            );
          },
          onReject: () {
            Navigator.of(context).pop();
            // TODO: 전화 거절 로직 (서버 통신 등)
            if (kDebugMode) {
              debugPrint('❌ 전화 거절됨: $callerNumber → $receiverNumber');
              debugPrint('  Channel: $channel');
              debugPrint('  Linkedid: $linkedid');
            }
            // 통화 기록 저장
            _saveCallHistory(
              callerNumber: callerNumber,
              callerName: finalCallerName,
              receiverNumber: receiverNumber,
              channel: channel,
              linkedid: linkedid,
              callType: 'incoming',
              status: 'rejected',
            );
          },
        ),
      ),
    );
    
    // IncomingCallScreen 결과 처리
    if (result != null && result is Map && result['moveToTab'] != null) {
      final tabIndex = result['moveToTab'] as int;
      
      if (kDebugMode) {
        debugPrint('');
        debugPrint('🔄 IncomingCallScreen 결과 수신');
        debugPrint('  → 탭 이동 요청: $tabIndex (1=최근통화)');
      }
      
      // 이벤트 스트림으로 탭 이동 요청 전송
      _eventController.add({
        'type': 'MOVE_TO_TAB',
        'tabIndex': tabIndex,
      });
      
      if (kDebugMode) {
        debugPrint('  ✅ 탭 이동 이벤트 전송 완료');
        debugPrint('');
      }
    }
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


  /// 통화 기록 저장 (Firestore)
  Future<void> _saveCallHistory({
    required String callerNumber,
    required String callerName,
    required String receiverNumber,
    required String channel,
    required String linkedid,
    required String callType,
    required String status,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      final userId = auth.currentUser?.uid;
      
      if (userId == null) {
        if (kDebugMode) {
          debugPrint('⚠️ 로그인 정보가 없어 통화 기록을 저장할 수 없습니다');
        }
        return;
      }
      
      // 통화 기록 데이터
      final callHistory = {
        'userId': userId,
        'callerNumber': callerNumber,
        'callerName': callerName,
        'receiverNumber': receiverNumber,
        'channel': channel,
        'linkedid': linkedid,
        'callType': callType,  // 'incoming', 'outgoing', 'missed'
        'status': status,  // 'accepted', 'rejected', 'missed', 'completed'
        'timestamp': FieldValue.serverTimestamp(),
        'duration': 0,  // 통화 시간 (초) - 추후 업데이트
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      // Firestore에 저장 (linkedid를 문서 ID로 사용)
      await firestore
          .collection('call_history')
          .doc(linkedid)
          .set(callHistory, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ 통화 기록 저장 완료');
        debugPrint('  Linkedid: $linkedid');
        debugPrint('  발신: $callerNumber → 수신: $receiverNumber');
        debugPrint('  상태: $status');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 통화 기록 저장 오류: $e');
      }
    }
  }
  /// 클릭투콜 기록을 임시 저장 (Newchannel 이벤트 대기)
  void storePendingClickToCallRecord({
    required String extensionNumber,
    required String phoneNumber,
    required String userId,
    required String mainNumberUsed,
    required bool callForwardEnabled,
    String? callForwardDestination,
  }) {
    final timestamp = DateTime.now();
    
    _pendingClickToCallRecords[extensionNumber] = {
      'phoneNumber': phoneNumber,
      'userId': userId,
      'mainNumberUsed': mainNumberUsed,
      'extensionUsed': extensionNumber,
      'callForwardEnabled': callForwardEnabled,
      'callForwardDestination': callForwardDestination,
      'timestamp': timestamp.toIso8601String(),
      'callTime': timestamp,
    };
    
    if (kDebugMode) {
      debugPrint('📝 클릭투콜 기록 임시 저장 (Newchannel 이벤트 대기)');
      debugPrint('   단말번호: $extensionNumber');
      debugPrint('   발신번호: $phoneNumber');
      debugPrint('   착신전환: $callForwardEnabled');
    }
    
    // 10초 후 타임아웃 - 이벤트가 안 오면 임시 데이터로 생성
    Future.delayed(const Duration(seconds: 10), () {
      if (_pendingClickToCallRecords.containsKey(extensionNumber)) {
        final data = _pendingClickToCallRecords[extensionNumber]!;
        final recordTimestamp = DateTime.parse(data['timestamp'] as String);
        
        // 10초 경과 확인
        if (DateTime.now().difference(recordTimestamp).inSeconds >= 10) {
          if (kDebugMode) {
            debugPrint('⏰ Newchannel 이벤트 타임아웃 - 임시 데이터로 기록 생성');
            debugPrint('   단말번호: $extensionNumber');
          }
          
          // Firestore에 linkedid 없이 생성
          _createCallHistoryFromPending(extensionNumber, null);
        }
      }
    });
  }
  
  /// 임시 저장된 클릭투콜 기록을 Firestore에 생성
  Future<void> _createCallHistoryFromPending(String extensionNumber, String? linkedid) async {
    final data = _pendingClickToCallRecords.remove(extensionNumber);
    if (data == null) return;
    
    try {
      final firestore = FirebaseFirestore.instance;
      
      await firestore.collection('call_history').add({
        'userId': data['userId'],
        'phoneNumber': data['phoneNumber'],
        'callType': 'outgoing',
        'callMethod': 'extension',
        'callTime': (data['callTime'] as DateTime).toIso8601String(),
        'mainNumberUsed': data['mainNumberUsed'],
        'extensionUsed': data['extensionUsed'],
        'callForwardEnabled': data['callForwardEnabled'],
        'callForwardDestination': data['callForwardDestination'],
        'linkedid': linkedid, // Newchannel에서 받은 linkedid (없으면 null)
        'createdAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ 클릭투콜 기록 생성 완료');
        debugPrint('   단말번호: $extensionNumber');
        debugPrint('   Linkedid: ${linkedid ?? "(없음)"}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 클릭투콜 기록 생성 오류: $e');
      }
    }
  }

  /// 서비스 정리
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _eventController.close();
    _pendingClickToCallRecords.clear();
  }
}
