import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import '../auth_service.dart';
import '../dcmiws_service.dart';
import '../../main.dart' show navigatorKey;
import '../../screens/call/incoming_call_screen.dart';
import '../../screens/call/incoming_call_screen_logged_out.dart';
import 'fcm_notification_service.dart';

/// FCM 수신전화 처리 서비스
/// 
/// 책임:
/// - FCM 수신전화 메시지 처리
/// - 수신전화 화면 표시
/// - 수신전화 취소 처리
/// - 통화 기록 생성
/// - 진동/사운드 제어
/// 
/// Phase 4에서 fcm_service.dart에서 분리됨
class FCMIncomingCallHandler {
  static BuildContext? _context;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FCMNotificationService _notificationService = FCMNotificationService();
  
  bool _isShowingIncomingCall = false;
  
  /// BuildContext 설정 (main.dart에서 호출)
  static void setContext(BuildContext context) {
    _context = context;
  }
  
  /// FCM 수신전화 처리
  /// 
  /// DCMIWS 웹소켓 연결이 중지되었을 때 FCM으로 수신전화를 처리합니다.
  Future<void> handleIncomingCallFCM(RemoteMessage message) async {
    // ignore: avoid_print
    print('📞 [FCM-INCOMING] 수신 전화 FCM 메시지 처리 시작');
    // ignore: avoid_print
    print('   - Platform: ${Platform.isAndroid ? 'Android' : (Platform.isIOS ? 'iOS' : 'Other')}');
    // ignore: avoid_print
    print('   - Message data: ${message.data}');
    
    // 🔔 사용자 로그인 상태 및 알림 설정 확인
    final authService = AuthService();
    final userId = authService.currentUser?.uid;
    final isLoggedIn = userId != null;
    
    // ignore: avoid_print
    print('🔐 [FCM-INCOMING] 사용자 로그인 상태: ${isLoggedIn ? "로그인" : "로그아웃"}');
    
    bool soundEnabled = true; // 기본값
    bool vibrationEnabled = true; // 기본값
    
    if (isLoggedIn) {
      // 로그인된 경우: 알림 설정 확인
      try {
        final settings = await _notificationService.getUserNotificationSettings(userId!);
        final pushEnabled = settings?['pushEnabled'] ?? true;
        soundEnabled = settings?['soundEnabled'] ?? true;
        vibrationEnabled = settings?['vibrationEnabled'] ?? true;
        
        // ignore: avoid_print
        print('📦 [FCM-INCOMING] 알림 설정:');
        // ignore: avoid_print
        print('   - pushEnabled: $pushEnabled');
        // ignore: avoid_print
        print('   - soundEnabled: $soundEnabled');
        // ignore: avoid_print
        print('   - vibrationEnabled: $vibrationEnabled');
        
        if (!pushEnabled) {
          // ignore: avoid_print
          print('⏭️ [FCM-INCOMING] 푸시 알림이 비활성화되어 수신 전화 표시 건너뜀');
          return; // 알림 설정이 꺼져있으면 수신 전화 처리 중단
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-INCOMING] 알림 설정 확인 실패: $e');
        // 설정 확인 실패 시 기본 동작 (수신 전화 표시, 소리/진동 켜짐)
      }
    } else {
      // 로그아웃 상태: 알림 설정 건너뜀 (로그아웃 전용 화면은 소리/진동 없음)
      // ignore: avoid_print
      print('📦 [FCM-INCOMING] 로그아웃 상태 - 로그아웃 전용 화면 표시 예정');
    }
    
    // 1️⃣ 사용자 설정 확인 (dcmiwsEnabled)
    final dcmiwsEnabled = authService.currentUserModel?.dcmiwsEnabled ?? false;
    
    // ignore: avoid_print
    print('📋 [FCM-INCOMING] 사용자 수신 전화 처리 설정:');
    // ignore: avoid_print
    print('   - dcmiwsEnabled: $dcmiwsEnabled');
    // ignore: avoid_print
    print('   - 처리 방식: ${dcmiwsEnabled ? "WebSocket (DCMIWS)" : "FCM (Push)"}');
    
    if (dcmiwsEnabled) {
      // 2️⃣ WebSocket 모드: FCM 무시
      // ignore: avoid_print
      print('✅ [FCM-INCOMING] WebSocket 모드 설정됨 - FCM 무시');
      
      // WebSocket 연결 상태 확인 (경고용)
      try {
        final dcmiwsService = DCMIWSService();
        final isConnected = dcmiwsService.isConnected;
        
        if (!isConnected) {
          // ignore: avoid_print
          print('⚠️ [FCM-INCOMING] WebSocket 연결 안 됨 - 수신 전화 놓칠 수 있음');
          // ignore: avoid_print
          print('   💡 WebSocket 연결을 확인하거나 FCM 모드로 전환하세요');
        } else {
          // ignore: avoid_print
          print('✅ [FCM-INCOMING] WebSocket 연결 활성 - WebSocket으로 수신 전화 처리 중');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-INCOMING] WebSocket 상태 확인 오류: $e');
      }
      
      return; // WebSocket 모드는 FCM 무시
    }
    
    // 3️⃣ FCM 모드: FCM으로 수신 전화 처리
    // ignore: avoid_print
    print('✅ [FCM-INCOMING] FCM 모드 설정됨 - FCM으로 수신 전화 처리');
    // ignore: avoid_print
    print('📞 [FCM-INCOMING] showIncomingCallScreen() 호출 시작...');
    
    if (isLoggedIn) {
      // 로그인 상태: 풀스크린 수신 전화 화면 (소리/진동 포함)
      // ignore: avoid_print
      print('   - 화면 타입: 로그인 전용 (IncomingCallScreen)');
      // ignore: avoid_print
      print('   - soundEnabled: $soundEnabled (벨소리 재생)');
      // ignore: avoid_print
      print('   - vibrationEnabled: $vibrationEnabled (진동)');
      
      try {
        await showIncomingCallScreen(message, soundEnabled: soundEnabled, vibrationEnabled: vibrationEnabled);
        // ignore: avoid_print
        print('✅ [FCM-INCOMING] showIncomingCallScreen() 호출 완료');
      } catch (e, stackTrace) {
        // ignore: avoid_print
        print('❌ [FCM-INCOMING] showIncomingCallScreen() 오류: $e');
        // ignore: avoid_print
        print('Stack trace: $stackTrace');
      }
    } else {
      // 로그아웃 상태: 로그아웃 전용 수신 전화 화면 (소리/진동 없음)
      // ignore: avoid_print
      print('   - 화면 타입: 로그아웃 전용 (IncomingCallScreenLoggedOut)');
      // ignore: avoid_print
      print('   - soundEnabled: false (로그아웃 상태 - 시스템 알림만)');
      // ignore: avoid_print
      print('   - vibrationEnabled: false (로그아웃 상태 - 시스템 알림만)');
      
      try {
        await showIncomingCallScreenLoggedOut(message);
        // ignore: avoid_print
        print('✅ [FCM-INCOMING] showIncomingCallScreenLoggedOut() 호출 완료');
      } catch (e, stackTrace) {
        // ignore: avoid_print
        print('❌ [FCM-INCOMING] showIncomingCallScreenLoggedOut() 오류: $e');
        // ignore: avoid_print
        print('Stack trace: $stackTrace');
      }
    }
  }
  
  /// Context가 준비될 때까지 대기 후 수신전화 화면 표시 (백그라운드용)
  Future<void> waitForContextAndShowIncomingCall(RemoteMessage message) async {
    int retryCount = 0;
    const maxRetries = 30; // 3초 (100ms * 30)
    
    while (retryCount < maxRetries) {
      final context = _context ?? navigatorKey.currentContext;
      
      if (context != null) {
        debugPrint('✅ [FCM-INCOMING] Context 준비 완료 (${retryCount * 100}ms 대기)');
        
        // 사용자 설정 확인 (dcmiwsEnabled)
        final authService = AuthService();
        final dcmiwsEnabled = authService.currentUserModel?.dcmiwsEnabled ?? false;
        
        if (dcmiwsEnabled) {
          debugPrint('✅ [FCM-INCOMING] WebSocket 모드 설정됨 - FCM 무시');
          return;
        }
        
        // 사용자 알림 설정 확인 (pushEnabled, soundEnabled, vibrationEnabled)
        final userId = authService.currentUser?.uid;
        
        bool soundEnabled = true; // 기본값
        bool vibrationEnabled = true; // 기본값
        
        if (userId != null) {
          try {
            final settings = await _notificationService.getUserNotificationSettings(userId);
            final pushEnabled = settings?['pushEnabled'] ?? true;
            soundEnabled = settings?['soundEnabled'] ?? true;
            vibrationEnabled = settings?['vibrationEnabled'] ?? true;
            
            debugPrint('📦 [FCM-INCOMING] 사용자 알림 설정:');
            debugPrint('   - pushEnabled: $pushEnabled');
            debugPrint('   - soundEnabled: $soundEnabled');
            debugPrint('   - vibrationEnabled: $vibrationEnabled');
            
            if (!pushEnabled) {
              debugPrint('⏭️ [FCM-INCOMING] 푸시 알림이 비활성화되어 수신 전화 표시 건너뜀');
              return;
            }
          } catch (e) {
            debugPrint('⚠️ [FCM-INCOMING] 알림 설정 확인 실패: $e');
          }
        }
        
        // 로그인 상태에 따라 적절한 화면 표시
        if (userId != null) {
          // 로그인 상태: 풀스크린 수신 전화 화면 (소리/진동 포함)
          await showIncomingCallScreen(message, soundEnabled: soundEnabled, vibrationEnabled: vibrationEnabled);
        } else {
          // 로그아웃 상태: 로그아웃 전용 수신 전화 화면 (소리/진동 없음)
          await showIncomingCallScreenLoggedOut(message);
        }
        return;
      }
      
      debugPrint('⏳ [FCM-INCOMING] Context 대기 중... (${retryCount + 1}/$maxRetries)');
      await Future.delayed(const Duration(milliseconds: 100));
      retryCount++;
    }
    
    debugPrint('❌ [FCM-INCOMING] Context 타임아웃 (3초 대기 후에도 Context 없음)');
  }
  
  /// 🛑 수신전화 알림 취소 메시지 처리 (방법 1: FCM 푸시)
  /// 
  /// 다른 기기에서 통화를 수락/거부했을 때 현재 기기의 IncomingCallScreen을 닫습니다.
  /// 앱이 백그라운드/종료 상태에서도 작동합니다.
  void handleIncomingCallCancelled(RemoteMessage message) {
    final linkedid = message.data['linkedid'] as String?;
    final action = message.data['action'] as String? ?? 'unknown';
    
    if (kDebugMode) {
      debugPrint('🛑 [FCM-CANCEL] 수신전화 취소 메시지 수신');
      debugPrint('   linkedid: $linkedid');
      debugPrint('   action: $action');
    }
    
    if (linkedid == null || linkedid.isEmpty) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CANCEL] linkedid 없음');
      }
      return;
    }
    
    // Navigator를 통해 현재 표시된 IncomingCallScreen 닫기
    final context = _context ?? navigatorKey.currentContext;
    if (context == null) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-CANCEL] BuildContext 없음 - Navigator 사용 불가');
        debugPrint('   → Firestore 리스너(방법 3)가 처리할 것입니다');
      }
      return;
    }
    
    // 🔧 안전 장치: Context가 mounted 상태인지 확인 (이미 dispose된 경우 방지)
    if (context is Element) {
      if (!context.mounted) {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-CANCEL] Context가 이미 deactivated - 화면이 이미 닫혔을 수 있음');
        }
        return;
      }
    }
    
    // 현재 라우트가 IncomingCallScreen인 경우에만 닫기
    try {
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null && currentRoute.isCurrent) {
        Navigator.of(context).popUntil((route) {
          // IncomingCallScreen이 아닌 라우트를 찾을 때까지 pop
          return route.settings.name != '/incoming_call' || route.isFirst;
        });
        
        if (kDebugMode) {
          debugPrint('✅ [FCM-CANCEL] IncomingCallScreen 닫기 완료 (FCM 푸시)');
        }
      } else {
        if (kDebugMode) {
          debugPrint('ℹ️ [FCM-CANCEL] 현재 IncomingCallScreen이 표시되지 않음');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-CANCEL] Navigator 오류 (화면이 이미 닫혔을 수 있음): $e');
        debugPrint('   → 이는 정상적인 동작입니다 (확인 버튼으로 이미 닫힘)');
      }
    }
  }
  
  /// 수신 전화 풀스크린 표시
  Future<void> showIncomingCallScreen(RemoteMessage message, {bool soundEnabled = true, bool vibrationEnabled = true}) async {
    // ignore: avoid_print
    print('🎬 [FCM-SCREEN] showIncomingCallScreen() 시작');
    
    // 🔧 중복 표시 방지
    if (_isShowingIncomingCall) {
      // ignore: avoid_print
      print('⚠️ [FCM-SCREEN] 이미 수신 전화 화면이 표시 중 - 중복 호출 무시');
      return;
    }
    
    // ignore: avoid_print
    print('   - _context: ${_context != null ? '있음' : '없음'}');
    // ignore: avoid_print
    print('   - navigatorKey.currentContext: ${navigatorKey.currentContext != null ? '있음' : '없음'}');
    
    // 🔧 FIX: navigatorKey.currentContext를 우선 사용 (항상 최신 상태)
    BuildContext? context = navigatorKey.currentContext;
    
    // navigatorKey가 없으면 _context 사용 (폴백)
    if (context == null) {
      context = _context;
      // ignore: avoid_print
      print('⚠️ [FCM-SCREEN] navigatorKey 없음 - _context 사용 (폴백)');
    } else {
      // ignore: avoid_print
      print('✅ [FCM-SCREEN] navigatorKey.currentContext 사용 (우선)');
    }
    
    if (context == null) {
      // ignore: avoid_print
      print('❌ [FCM-SCREEN] BuildContext와 NavigatorKey 모두 사용 불가');
      // ignore: avoid_print
      print('💡 main.dart에서 FCMIncomingCallHandler.setContext()를 호출하거나 앱이 완전히 시작될 때까지 기다리세요');
      return;
    }
    
    // 🔧 Context가 mounted 상태인지 확인
    if (context is Element) {
      if (!context.mounted) {
        // ignore: avoid_print
        print('❌ [FCM-SCREEN] Context가 deactivated 상태 - 사용 불가');
        return;
      }
      // ignore: avoid_print
      print('✅ [FCM-SCREEN] Context mounted 확인 완료');
    }
    
    // ignore: avoid_print
    print('✅ [FCM-SCREEN] Context 최종 확인 완료');
    
    // 📋 메시지 데이터에서 정보 추출
    final callerName = message.data['caller_name'] ?? 
                       message.data['callerName'] ?? 
                       message.notification?.title?.split(' ').first ?? 
                       '알 수 없음';
    
    final callerNumber = message.data['caller_num'] ?? 
                         message.data['caller_number'] ?? 
                         message.data['callerNumber'] ?? 
                         _extractPhoneNumber(message.notification?.title) ??
                         _extractPhoneNumber(message.notification?.body) ??
                         '번호 없음';
    
    final callerAvatar = message.data['caller_avatar'] ?? 
                         message.data['callerAvatar'];
    
    // 통화 관련 메타데이터
    final channel = message.data['channel'] ?? '';
    
    final linkedid = message.data['linkedid'] ?? 
                     message.data['linkedId'] ?? 
                     DateTime.now().millisecondsSinceEpoch.toString();
    
    final receiverNumber = message.data['receiver_number'] ?? 
                           message.data['receiverNumber'] ?? 
                           message.data['extension'] ??
                           message.data['did'] ??
                           '';
    
    final callType = message.data['call_type'] ?? 
                     message.data['callType'] ?? 
                     message.data['type'] ??
                     'voice'; // iOS FCM에서는 voice로 전송됨
    
    // ignore: avoid_print
    print('📞 [FCM-SCREEN] 수신 전화 데이터 추출:');
    // ignore: avoid_print
    print('   발신자: $callerName');
    // ignore: avoid_print
    print('   번호: $callerNumber');
    // ignore: avoid_print
    print('   채널: $channel');
    // ignore: avoid_print
    print('   링크ID: $linkedid');
    // ignore: avoid_print
    print('   수신번호: $receiverNumber');
    // ignore: avoid_print
    print('   통화타입: $callType');
    
    // 💾 통화 기록 생성 (call_history)
    // ignore: avoid_print
    print('📝 [FCM-SCREEN] 통화 기록 생성 시도 중...');
    
    // FCM 메시지에서 user_id 추출 (백업용)
    final fcmUserId = message.data['user_id'] ?? message.data['userId'];
    
    await _createCallHistory(
      callerNumber: callerNumber,
      callerName: callerName,
      receiverNumber: receiverNumber,
      linkedid: linkedid,
      channel: channel,
      callType: callType,
      fcmUserId: fcmUserId, // FCM 메시지의 userId 전달 (로그인 상태에서는 사용 안 함)
    );
    // ignore: avoid_print
    print('📝 [FCM-SCREEN] 통화 기록 생성 완료 (또는 실패)');
    
    print('🎬 [FCM] 수신 전화 화면 표시');
    
    // 🔧 플래그 설정 (화면 표시 시작)
    _isShowingIncomingCall = true;
    
    try {
      // 🔥 CRITICAL FIX: 기존 IncomingCallScreen이 있으면 제거 후 새로 표시
      final navigator = Navigator.of(context);
      
      // 현재 route가 IncomingCallScreen인지 확인
      final currentRoute = ModalRoute.of(context);
      if (currentRoute != null && 
          (currentRoute.settings.name == '/incoming_call' || 
           currentRoute.isCurrent == false)) {
        // ignore: avoid_print
        print('🔄 [FCM-SCREEN] 기존 IncomingCallScreen 감지 - 교체 모드');
        
        // 기존 화면 제거 (안전성 체크)
        if (navigator.canPop()) {
          try {
            navigator.popUntil((route) => route.isFirst || route.settings.name != '/incoming_call');
            // ignore: avoid_print
            print('✅ [FCM-SCREEN] 기존 화면 제거 완료');
          } catch (e) {
            // ignore: avoid_print
            print('⚠️ [FCM-SCREEN] popUntil 오류: $e');
          }
        }
      }
      
      // 수신 전화 화면 표시 (fullscreenDialog로 전체 화면)
      await navigator.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          settings: const RouteSettings(name: '/incoming_call'),
          builder: (context) => IncomingCallScreen(
            callerName: callerName,
            callerNumber: callerNumber,
            callerAvatar: callerAvatar,
            linkedid: linkedid,
            channel: channel,
            receiverNumber: receiverNumber,
            callType: callType,
            shouldPlaySound: soundEnabled, // 사용자 알림 설정 전달
            shouldVibrate: vibrationEnabled, // 사용자 알림 설정 전달
            onAccept: () {
              // Accept 처리는 IncomingCallScreen 내부에서 수행
              Navigator.of(context).pop();
            },
            onReject: () {
              // Reject 처리는 IncomingCallScreen 내부에서 수행
              Navigator.of(context).pop();
            },
          ),
        ),
      );
      
      // ignore: avoid_print
      print('✅ [FCM-SCREEN] IncomingCallScreen 닫힘 (사용자가 수락/거부함)');
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-SCREEN] IncomingCallScreen 표시 오류: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
    } finally {
      // 🔧 플래그 해제 (화면 표시 종료)
      _isShowingIncomingCall = false;
      // ignore: avoid_print
      print('🏁 [FCM-SCREEN] showIncomingCallScreen() 완료 (플래그 해제)');
    }
  }
  
  /// 통화 기록 생성 (Firestore)
  /// 
  /// ✅ linkedid를 문서 ID로 사용하여 중복 생성 방지
  /// ✅ 로그아웃 상태에서도 생성 가능 (FCM 메시지의 user_id 사용)
  Future<void> _createCallHistory({
    required String callerNumber,
    required String callerName,
    required String receiverNumber,
    required String linkedid,
    required String channel,
    required String callType,
    String? fcmUserId, // FCM 메시지에서 전달된 userId (로그아웃 상태용)
  }) async {
    try {
      final authService = AuthService();
      String? userId = authService.currentUser?.uid; // 현재 로그인 사용자
      
      // 로그아웃 상태면 FCM 메시지의 userId 사용
      if (userId == null && fcmUserId != null) {
        userId = fcmUserId;
        debugPrint('📝 [FCM-CALL-HISTORY] 로그아웃 상태 - FCM userId 사용: $userId');
      }
      
      if (userId == null) {
        debugPrint('⚠️ [FCM-CALL-HISTORY] 사용자 ID 없음 - 통화 기록 생성 불가');
        return;
      }
      
      // ✅ linkedid를 문서 ID로 사용 (중복 방지)
      await _firestore.collection('call_history').doc(linkedid).set({
        'userId': userId,
        'callerNumber': callerNumber,
        'callerName': callerName,
        'receiverNumber': receiverNumber,
        'linkedid': linkedid,
        'channel': channel,
        'callType': callType,
        'direction': 'incoming',
        'status': 'missed', // 초기 상태는 missed (부재중)
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: false)); // 덮어쓰기 방지
      
      debugPrint('✅ [FCM-CALL-HISTORY] 통화 기록 생성 완료 (linkedid: $linkedid, status: missed, userId: $userId)');
      
    } catch (e) {
      debugPrint('❌ [FCM-CALL-HISTORY] 통화 기록 생성 실패: $e');
    }
  }
  
  /// 전화번호 추출 헬퍼
  String? _extractPhoneNumber(String? text) {
    if (text == null) return null;
    final phoneRegex = RegExp(r'\d{2,4}-\d{3,4}-\d{4}');
    final match = phoneRegex.firstMatch(text);
    return match?.group(0);
  }
  
  /// 🔐 로그아웃 전용 수신 전화 풀스크린 표시
  /// 
  /// 로그아웃 상태에서 FCM 푸시 알림을 탭했을 때 표시되는 화면
  /// - 기존 IncomingCallScreen과 동일한 디자인
  /// - 소리/진동 없음 (시스템 알림에서 이미 처리됨)
  /// - 닫기 버튼 (우측 상단 ✕)
  /// - "로그인하여 확인하기" 단일 버튼
  Future<void> showIncomingCallScreenLoggedOut(RemoteMessage message) async {
    // ignore: avoid_print
    print('🎬 [FCM-SCREEN-LOGOUT] showIncomingCallScreenLoggedOut() 시작');
    
    // 🔧 중복 표시 방지
    if (_isShowingIncomingCall) {
      // ignore: avoid_print
      print('⚠️ [FCM-SCREEN-LOGOUT] 이미 수신 전화 화면이 표시 중 - 중복 호출 무시');
      return;
    }
    
    // ignore: avoid_print
    print('   - _context: ${_context != null ? '있음' : '없음'}');
    // ignore: avoid_print
    print('   - navigatorKey.currentContext: ${navigatorKey.currentContext != null ? '있음' : '없음'}');
    
    // 🔧 FIX: navigatorKey.currentContext를 우선 사용 (항상 최신 상태)
    BuildContext? context = navigatorKey.currentContext;
    
    // navigatorKey가 없으면 _context 사용 (폴백)
    if (context == null) {
      context = _context;
      // ignore: avoid_print
      print('⚠️ [FCM-SCREEN-LOGOUT] navigatorKey 없음 - _context 사용 (폴백)');
    } else {
      // ignore: avoid_print
      print('✅ [FCM-SCREEN-LOGOUT] navigatorKey.currentContext 사용 (우선)');
    }
    
    if (context == null) {
      // ignore: avoid_print
      print('❌ [FCM-SCREEN-LOGOUT] BuildContext와 NavigatorKey 모두 사용 불가');
      return;
    }
    
    // 🔧 Context가 mounted 상태인지 확인
    if (context is Element) {
      if (!context.mounted) {
        // ignore: avoid_print
        print('❌ [FCM-SCREEN-LOGOUT] Context가 deactivated 상태 - 사용 불가');
        return;
      }
      // ignore: avoid_print
      print('✅ [FCM-SCREEN-LOGOUT] Context mounted 확인 완료');
    }
    
    // ignore: avoid_print
    print('✅ [FCM-SCREEN-LOGOUT] Context 최종 확인 완료');
    
    // 📋 메시지 데이터에서 정보 추출
    final callerName = message.data['caller_name'] ?? 
                       message.data['callerName'] ?? 
                       message.notification?.title?.split(' ').first ?? 
                       '알 수 없음';
    
    final callerNumber = message.data['caller_num'] ?? 
                         message.data['caller_number'] ?? 
                         message.data['callerNumber'] ?? 
                         _extractPhoneNumber(message.notification?.title) ??
                         _extractPhoneNumber(message.notification?.body) ??
                         '번호 없음';
    
    final callerAvatar = message.data['caller_avatar'] ?? 
                         message.data['callerAvatar'];
    
    // 통화 관련 메타데이터
    final channel = message.data['channel'] ?? '';
    
    final linkedid = message.data['linkedid'] ?? 
                     message.data['linkedId'] ?? 
                     DateTime.now().millisecondsSinceEpoch.toString();
    
    final receiverNumber = message.data['receiver_number'] ?? 
                           message.data['receiverNumber'] ?? 
                           message.data['extension'] ??
                           message.data['did'] ??
                           '';
    
    final callType = message.data['call_type'] ?? 
                     message.data['callType'] ?? 
                     message.data['type'] ??
                     'voice';
    
    // 내 단말번호 정보 추출
    final myExtension = message.data['my_extension'] ?? 
                        message.data['myExtension'] ?? 
                        '';
    
    final myCompanyName = message.data['my_company_name'] ?? 
                          message.data['myCompanyName'];
    
    final myOutboundCid = message.data['my_outbound_cid'] ?? 
                          message.data['myOutboundCid'];
    
    final myExternalCidName = message.data['my_external_cid_name'] ?? 
                              message.data['myExternalCidName'];
    
    final myExternalCidNumber = message.data['my_external_cid_number'] ?? 
                                message.data['myExternalCidNumber'];
    
    // 착신전환 정보
    final isCallForwardEnabled = message.data['is_call_forward_enabled'] == 'true' ||
                                 message.data['isCallForwardEnabled'] == 'true';
    
    final callForwardDestination = message.data['call_forward_destination'] ?? 
                                   message.data['callForwardDestination'];
    
    // ignore: avoid_print
    print('📞 [FCM-SCREEN-LOGOUT] 수신 전화 데이터 추출:');
    // ignore: avoid_print
    print('   발신자: $callerName');
    // ignore: avoid_print
    print('   번호: $callerNumber');
    // ignore: avoid_print
    print('   채널: $channel');
    // ignore: avoid_print
    print('   링크ID: $linkedid');
    // ignore: avoid_print
    print('   수신번호: $receiverNumber');
    // ignore: avoid_print
    print('   통화타입: $callType');
    
    // FCM 메시지에서 user_id 추출 (로그아웃 상태에서 통화 기록 생성용)
    final fcmUserId = message.data['user_id'] ?? message.data['userId'];
    
    // ignore: avoid_print
    print('📝 [FCM-SCREEN-LOGOUT] FCM user_id: ${fcmUserId ?? "(없음)"}');
    
    // 💾 통화 기록 생성 (call_history) - 로그아웃 상태에서도 생성
    // ignore: avoid_print
    print('📝 [FCM-SCREEN-LOGOUT] 통화 기록 생성 시도 중...');
    await _createCallHistory(
      callerNumber: callerNumber,
      callerName: callerName,
      receiverNumber: receiverNumber,
      linkedid: linkedid,
      channel: channel,
      callType: callType,
      fcmUserId: fcmUserId, // FCM 메시지의 userId 전달
    );
    // ignore: avoid_print
    print('📝 [FCM-SCREEN-LOGOUT] 통화 기록 생성 완료 (또는 실패)');
    
    print('🎬 [FCM-LOGOUT] 로그아웃 전용 수신 전화 화면 표시');
    
    // 🔧 플래그 설정 (화면 표시 시작)
    _isShowingIncomingCall = true;
    
    try {
      // 수신 전화 화면 표시 (fullscreenDialog로 전체 화면)
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          settings: const RouteSettings(name: '/incoming_call_logged_out'),
          builder: (context) => IncomingCallScreenLoggedOut(
            callerName: callerName,
            callerNumber: callerNumber,
            callerAvatar: callerAvatar,
            linkedid: linkedid,
            channel: channel,
            receiverNumber: receiverNumber,
            callType: callType,
            myExtension: myExtension,
            myCompanyName: myCompanyName,
            myOutboundCid: myOutboundCid,
            myExternalCidName: myExternalCidName,
            myExternalCidNumber: myExternalCidNumber,
            isCallForwardEnabled: isCallForwardEnabled,
            callForwardDestination: callForwardDestination,
          ),
        ),
      );
      
      // ignore: avoid_print
      print('✅ [FCM-SCREEN-LOGOUT] IncomingCallScreenLoggedOut 닫힘 (사용자가 닫기 또는 로그인)');
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-SCREEN-LOGOUT] IncomingCallScreenLoggedOut 표시 오류: $e');
      // ignore: avoid_print
      print('Stack trace: $stackTrace');
    } finally {
      // 🔧 플래그 해제 (화면 표시 종료)
      _isShowingIncomingCall = false;
      // ignore: avoid_print
      print('🏁 [FCM-SCREEN-LOGOUT] showIncomingCallScreenLoggedOut() 완료 (플래그 해제)');
    }
  }
}
