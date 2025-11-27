import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'fcm_notification_sound_service.dart';
import 'fcm_platform_utils.dart';
import '../database_service.dart';
import '../auth_service.dart';

/// FCM 메시지 핸들러
/// 
/// FCM 메시지 수신 및 타입별 라우팅을 담당합니다.
/// - 포그라운드 메시지 처리
/// - 백그라운드 메시지 처리 (알림 클릭)
/// - 메시지 타입별 라우팅
/// - 중복 메시지 방지
/// - 기기 승인 상태 체크 (미승인 기기는 승인 관련 메시지만 수신)
class FCMMessageHandler {
  // 🔒 중복 메시지 처리 방지
  static final Set<String> _processedMessageIds = {};
  
  // 서비스 인스턴스
  final DatabaseService _databaseService = DatabaseService();
  final AuthService _authService = AuthService();
  final FCMPlatformUtils _platformUtils = FCMPlatformUtils();
  
  // 기기 정보 캐시 (앱 실행 중 변경되지 않음)
  String? _cachedDeviceId;
  String? _cachedPlatform;

  // 메시지 타입별 핸들러 콜백
  Function(RemoteMessage)? onForceLogout;
  Function(RemoteMessage)? onDeviceApprovalRequest;
  Function(RemoteMessage)? onDeviceApprovalResponse;
  Function(RemoteMessage)? onDeviceApprovalCancelled;
  Function(RemoteMessage)? onIncomingCallCancelled;
  Function(RemoteMessage)? onIncomingCall;
  Function(RemoteMessage)? onGeneralNotification;

  /// 포그라운드 메시지 처리
  void handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('📨 [FCM-HANDLER] 포그라운드 메시지: ${message.notification?.title ?? message.data['type']}');
    }
    
    // 중복 메시지 방지
    if (!_checkAndMarkMessage(message.messageId)) {
      return;
    }
    
    // 메시지 타입별 라우팅
    _routeMessage(message, isForeground: true);
  }

  /// 백그라운드/종료 상태에서 알림 클릭 시 처리
  void handleMessageOpenedApp(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('🔔 [FCM-HANDLER] 백그라운드 알림 탭: ${message.notification?.title ?? message.data['type']}');
    }
    
    // 🔔 iOS 배지 제거 (알림 탭 시)
    _clearBadgeOnNotificationTap();
    
    // 메시지 타입별 라우팅
    _routeMessage(message, isForeground: false);
  }

  /// 메시지 타입별 라우팅
  void _routeMessage(RemoteMessage message, {required bool isForeground}) async {
    final messageType = message.data['type'] as String?;
    
    // 강제 로그아웃 (레거시)
    if (messageType == 'force_logout') {
      if (kDebugMode) {
        debugPrint('🚨 [FCM-HANDLER] 강제 로그아웃');
      }
      onForceLogout?.call(message);
      return;
    }
    
    // 기기 승인 요청 - 항상 허용
    if (messageType == 'device_approval_request') {
      if (kDebugMode) {
        debugPrint('🔔 [FCM-HANDLER] 기기 승인 요청');
      }
      try {
        onDeviceApprovalRequest?.call(message);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [FCM-HANDLER] 승인 요청 처리 실패: $e');
        }
      }
      return;
    }
    
    // 기기 승인 응답 - 항상 허용
    if (messageType == 'device_approval_response') {
      if (kDebugMode) {
        debugPrint('✅ [FCM-HANDLER] 기기 승인 응답');
      }
      onDeviceApprovalResponse?.call(message);
      return;
    }
    
    // 기기 승인 취소 - 항상 허용
    if (messageType == 'device_approval_cancelled') {
      if (kDebugMode) {
        debugPrint('🛑 [FCM-HANDLER] 기기 승인 취소');
      }
      onDeviceApprovalCancelled?.call(message);
      return;
    }
    
    // 🔔 수신전화 알림 취소 - 승인 체크 필요 없음 (백엔드에서 이미 검증됨)
    if (messageType == 'incoming_call_cancelled') {
      if (kDebugMode) {
        debugPrint('🛑 [FCM-HANDLER] 수신전화 취소');
      }
      onIncomingCallCancelled?.call(message);
      return;
    }
    
    // 📞 수신 전화 - 승인 체크 필요 없음 (백엔드에서 my_extensions로 이미 검증됨)
    // 로그아웃 상태에서도 수신전화는 표시되어야 함
    if (_isIncomingCallMessage(message)) {
      if (kDebugMode) {
        debugPrint('📞 [FCM-HANDLER] 수신 전화 (승인 체크 생략 - 백엔드 검증됨)');
      }
      onIncomingCall?.call(message);
      return;
    }
    
    // 🔐 승인 상태 체크 (수신전화 외 메시지)
    final isApproved = await _checkDeviceApprovalStatus();
    if (!isApproved) {
      if (kDebugMode) {
        debugPrint('🔒 [FCM-HANDLER] 미승인 기기 - 메시지 차단');
      }
      return;
    }
    
    // 착신전환 알림
    if (_isCallForwardMessage(message)) {
      _handleCallForwardNotification(message);
      return;
    }
    
    // 일반 알림 (포그라운드만)
    if (isForeground) {
      onGeneralNotification?.call(message);
    }
  }
  
  /// 착신전환 메시지 판별
  bool _isCallForwardMessage(RemoteMessage message) {
    final messageType = message.data['type'] as String?;
    return messageType != null && messageType.startsWith('call_forward');
  }
  
  /// 착신전환 알림 처리 (사운드 재생)
  void _handleCallForwardNotification(RemoteMessage message) {
    FCMNotificationSoundService.playNotificationWithVibration(duration: 3);
    onGeneralNotification?.call(message);
  }

  /// 수신 전화 메시지 판별
  bool _isIncomingCallMessage(RemoteMessage message) {
    final hasIncomingCallType = message.data['type'] == 'incoming_call';
    final hasLinkedId = message.data['linkedid'] != null && 
                        (message.data['linkedid'] as String).isNotEmpty;
    final hasCallType = message.data['call_type'] != null;
    
    return hasIncomingCallType || (hasLinkedId && hasCallType);
  }

  /// 중복 메시지 체크 및 마킹
  /// 
  /// Returns: true (처리 가능), false (이미 처리됨)
  bool _checkAndMarkMessage(String? messageId) {
    if (messageId == null) {
      return true;
    }
    
    if (_processedMessageIds.contains(messageId)) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-HANDLER] 중복 메시지 무시');
      }
      return false;
    }
    
    _processedMessageIds.add(messageId);
    
    // 메모리 관리: 100개 이상 쌓이면 오래된 것 제거
    if (_processedMessageIds.length > 100) {
      final toRemove = _processedMessageIds.take(50).toList();
      _processedMessageIds.removeAll(toRemove);
    }
    
    return true;
  }

  /// 기기 승인 상태 체크
  /// 
  /// Returns: true (승인됨), false (미승인)
  Future<bool> _checkDeviceApprovalStatus() async {
    try {
      // 현재 로그인된 사용자 확인
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        // 로그아웃 상태 - 안전하게 미승인으로 처리
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-HANDLER] 로그아웃 상태 - 미승인으로 처리');
        }
        return false;
      }
      
      final userId = currentUser.uid;
      
      // 기기 정보 가져오기 (캐시 사용)
      if (_cachedDeviceId == null || _cachedPlatform == null) {
        if (kDebugMode) {
          debugPrint('🔄 [FCM-HANDLER] 기기 정보 로드 중...');
        }
        await _loadDeviceInfo();
      }
      
      if (_cachedDeviceId == null || _cachedPlatform == null) {
        // 기기 정보 없음 - 안전하게 미승인으로 처리
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-HANDLER] 기기 정보 없음 - 미승인으로 처리');
          debugPrint('   - _cachedDeviceId: $_cachedDeviceId');
          debugPrint('   - _cachedPlatform: $_cachedPlatform');
        }
        return false;
      }
      
      if (kDebugMode) {
        debugPrint('📱 [FCM-HANDLER] 기기 정보 확인 완료');
        debugPrint('   - userId: $userId');
        debugPrint('   - deviceId: $_cachedDeviceId');
        debugPrint('   - platform: $_cachedPlatform');
      }
      
      // DatabaseService를 통해 승인 상태 조회
      final isApproved = await _databaseService.isCurrentDeviceApproved(
        userId,
        _cachedDeviceId!,
        _cachedPlatform!,
      );
      
      if (kDebugMode) {
        debugPrint('🔐 [FCM-HANDLER] 기기 승인 상태: $isApproved');
      }
      
      return isApproved;
    } catch (e) {
      // 에러 발생 시 안전하게 미승인으로 처리
      if (kDebugMode) {
        debugPrint('❌ [FCM-HANDLER] 승인 상태 체크 실패 - 미승인으로 처리: $e');
      }
      return false;
    }
  }
  
  /// 기기 정보 로드 및 캐싱
  /// 
  /// 🔧 FIX: FCMPlatformUtils 사용 (FCMTokenManager와 동일한 방식)
  Future<void> _loadDeviceInfo() async {
    try {
      // FCMPlatformUtils로 기기 ID 가져오기 (iOS 캐싱 로직 포함)
      _cachedDeviceId = await _platformUtils.getDeviceId();
      
      // 플랫폼 이름 가져오기 (소문자: 'android', 'ios', 'web')
      final platformLower = _platformUtils.getPlatformName();
      
      // 🔑 CRITICAL: 대문자로 변환 (Firestore 문서 ID 형식에 맞춤)
      // fcm_tokens 문서 ID: userId_deviceId_Android 또는 userId_deviceId_iOS
      if (platformLower == 'android') {
        _cachedPlatform = 'Android';
      } else if (platformLower == 'ios') {
        _cachedPlatform = 'iOS';
      } else {
        _cachedPlatform = platformLower; // web, unknown 등
      }
      
      if (kDebugMode) {
        debugPrint('📱 [FCM-HANDLER] 기기 정보 로드: deviceId=$_cachedDeviceId, platform=$_cachedPlatform');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-HANDLER] 기기 정보 로드 실패: $e');
      }
    }
  }

  /// 디버그 정보 출력
  void printMessageDetails(RemoteMessage message) {
    // ignore: avoid_print
    print('🔍 [FCM-HANDLER] 메시지 상세 정보:');
    // ignore: avoid_print
    print('   - messageId: ${message.messageId}');
    // ignore: avoid_print
    print('   - notification.title: ${message.notification?.title}');
    // ignore: avoid_print
    print('   - notification.body: ${message.notification?.body}');
    // ignore: avoid_print
    print('   - data keys: ${message.data.keys.toList()}');
    
    message.data.forEach((key, value) {
      // ignore: avoid_print
      print('   - data[$key]: $value (${value.runtimeType})');
    });
  }

  /// 🔔 알림 탭 시 iOS 배지 제거
  Future<void> _clearBadgeOnNotificationTap() async {
    // iOS에서만 실행
    if (kIsWeb || !Platform.isIOS) return;
    
    try {
      final notificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // 모든 알림 제거 (배지 포함)
      await notificationsPlugin.cancelAll();
      
      if (kDebugMode) {
        debugPrint('✅ [Badge] 알림 탭으로 iOS 배지 제거');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [Badge] 알림 탭 시 배지 제거 실패: $e');
      }
    }
  }

  /// 처리된 메시지 ID 초기화
  static void clearProcessedMessages() {
    _processedMessageIds.clear();
    // ignore: avoid_print
    print('🧹 [FCM-HANDLER] 처리된 메시지 ID 모두 삭제');
  }
}
