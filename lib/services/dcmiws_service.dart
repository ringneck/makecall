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

  /// 메시지 수신 핸들러
  void _handleMessage(dynamic message) {
    try {
      final Map<String, dynamic> data = json.decode(message as String);
      
      if (kDebugMode) {
        debugPrint('📨 DCMIWS: Received message: $data');
      }

      // 🔔 수신 전화 이벤트 감지 (Newchannel) - 비동기 처리
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
  Future<void> _checkIncomingCall(Map<String, dynamic> data) async {
    try {
      // type이 3인지 확인 (Call Event)
      if (data['type'] != 3) return;
      
      final eventData = data['data'] as Map<String, dynamic>?;
      if (eventData == null) return;
      
      // Event가 "Newchannel"인지 확인
      final event = eventData['Event'] as String?;
      if (event != 'Newchannel') return;
      
      // ChannelStateDesc가 "Ring"인지 확인 (수신 통화만 처리)
      final channelStateDesc = eventData['ChannelStateDesc'] as String?;
      if (channelStateDesc != 'Ring') return;
      
      // CallerIDNum, Exten, Channel, Linkedid, Context 추출
      final callerIdNum = eventData['CallerIDNum'] as String?;
      final exten = eventData['Exten'] as String?;
      final channel = eventData['Channel'] as String?;
      final linkedid = eventData['Linkedid'] as String?;
      final context = eventData['Context'] as String?;
      
      if (callerIdNum == null || exten == null) return;
      if (channel == null || linkedid == null) return;
      
      if (kDebugMode) {
        debugPrint('📞 수신 전화 감지!');
        debugPrint('  발신번호: $callerIdNum');
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
      
      // 수신 전화 화면 표시
      _showIncomingCallScreen(callerIdNum, exten, channel, linkedid, data, callType);
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 수신 전화 체크 오류: $e');
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
      debugPrint('  발신번호: $callerNumber');
      debugPrint('  수신번호: $receiverNumber');
      debugPrint('  Channel: $channel');
      debugPrint('  Linkedid: $linkedid');
    }
    
    _navigatorKey!.currentState!.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => IncomingCallScreen(
          callerName: finalCallerName,
          callerNumber: callerNumber,
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
  /// 서비스 정리
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _eventController.close();
  }
}
