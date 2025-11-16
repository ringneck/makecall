import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// FCM 메시지 핸들러
/// 
/// FCM 메시지 수신 및 타입별 라우팅을 담당합니다.
/// - 포그라운드 메시지 처리
/// - 백그라운드 메시지 처리 (알림 클릭)
/// - 메시지 타입별 라우팅
/// - 중복 메시지 방지
class FCMMessageHandler {
  // 🔒 중복 메시지 처리 방지
  static final Set<String> _processedMessageIds = {};

  // 메시지 타입별 핸들러 콜백
  Function(RemoteMessage)? onForceLogout;
  Function(RemoteMessage)? onDeviceApprovalRequest;
  Function(RemoteMessage)? onDeviceApprovalResponse;
  Function(RemoteMessage)? onIncomingCallCancelled;
  Function(RemoteMessage)? onIncomingCall;
  Function(RemoteMessage)? onGeneralNotification;

  /// 포그라운드 메시지 처리
  void handleForegroundMessage(RemoteMessage message) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('📨 [FCM-HANDLER] handleForegroundMessage() 호출');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('📨 Title: ${message.notification?.title}');
    // ignore: avoid_print
    print('📨 Data: ${message.data}');
    
    // 중복 메시지 방지
    if (!_checkAndMarkMessage(message.messageId)) {
      return;
    }
    
    // 메시지 타입별 라우팅
    _routeMessage(message, isForeground: true);
  }

  /// 백그라운드/종료 상태에서 알림 클릭 시 처리
  void handleMessageOpenedApp(RemoteMessage message) {
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('🔔 [FCM-HANDLER] handleMessageOpenedApp() 호출');
    // ignore: avoid_print
    print('═══════════════════════════════════════════════');
    // ignore: avoid_print
    print('🔔 Title: ${message.notification?.title}');
    // ignore: avoid_print
    print('🔔 Data: ${message.data}');
    
    // 메시지 타입별 라우팅
    _routeMessage(message, isForeground: false);
  }

  /// 메시지 타입별 라우팅
  void _routeMessage(RemoteMessage message, {required bool isForeground}) {
    final messageType = message.data['type'] as String?;
    
    // ignore: avoid_print
    print('🔍 [FCM-HANDLER] 메시지 타입: $messageType');
    
    // 🔐 강제 로그아웃 (레거시)
    if (messageType == 'force_logout') {
      // ignore: avoid_print
      print('🚨 [FCM-HANDLER] 강제 로그아웃 메시지');
      onForceLogout?.call(message);
      return;
    }
    
    // 🔔 기기 승인 요청
    if (messageType == 'device_approval_request') {
      // ignore: avoid_print
      print('🔔 [FCM-HANDLER] 기기 승인 요청 메시지');
      if (onDeviceApprovalRequest == null) {
        // ignore: avoid_print
        print('❌ [FCM-HANDLER] onDeviceApprovalRequest 콜백이 null입니다!');
        return;
      }
      // ignore: avoid_print
      print('📞 [FCM-HANDLER] onDeviceApprovalRequest 콜백 호출 중...');
      try {
        onDeviceApprovalRequest?.call(message);
        // ignore: avoid_print
        print('✅ [FCM-HANDLER] onDeviceApprovalRequest 콜백 호출 완료');
      } catch (e, stackTrace) {
        // ignore: avoid_print
        print('❌ [FCM-HANDLER] onDeviceApprovalRequest 콜백 실행 중 예외: $e');
        // ignore: avoid_print
        print('Stack trace: $stackTrace');
      }
      return;
    }
    
    // ✅ 기기 승인 응답
    if (messageType == 'device_approval_response') {
      // ignore: avoid_print
      print('✅ [FCM-HANDLER] 기기 승인 응답 메시지');
      onDeviceApprovalResponse?.call(message);
      return;
    }
    
    // 🛑 수신전화 알림 취소
    if (messageType == 'incoming_call_cancelled') {
      // ignore: avoid_print
      print('🛑 [FCM-HANDLER] 수신전화 취소 메시지');
      onIncomingCallCancelled?.call(message);
      return;
    }
    
    // 📞 수신 전화 (Android와 iOS 모두 지원)
    if (_isIncomingCallMessage(message)) {
      // ignore: avoid_print
      print('📞 [FCM-HANDLER] 수신 전화 메시지');
      onIncomingCall?.call(message);
      return;
    }
    
    // 📥 일반 알림 (포그라운드만)
    if (isForeground) {
      // ignore: avoid_print
      print('📥 [FCM-HANDLER] 일반 알림 메시지');
      onGeneralNotification?.call(message);
    }
  }

  /// 수신 전화 메시지 판별
  bool _isIncomingCallMessage(RemoteMessage message) {
    final hasIncomingCallType = message.data['type'] == 'incoming_call';
    final hasLinkedId = message.data['linkedid'] != null && 
                        (message.data['linkedid'] as String).isNotEmpty;
    final hasCallType = message.data['call_type'] != null;
    
    final isIncomingCall = hasIncomingCallType || (hasLinkedId && hasCallType);
    
    if (kDebugMode && isIncomingCall) {
      // ignore: avoid_print
      print('🔍 [FCM-HANDLER] 수신 전화 판별:');
      // ignore: avoid_print
      print('   - type: ${message.data['type']}');
      // ignore: avoid_print
      print('   - linkedid: ${message.data['linkedid']}');
      // ignore: avoid_print
      print('   - call_type: ${message.data['call_type']}');
    }
    
    return isIncomingCall;
  }

  /// 중복 메시지 체크 및 마킹
  /// 
  /// Returns: true (처리 가능), false (이미 처리됨)
  bool _checkAndMarkMessage(String? messageId) {
    if (messageId == null) {
      return true; // messageId가 없으면 처리
    }
    
    if (_processedMessageIds.contains(messageId)) {
      // ignore: avoid_print
      print('⚠️ [FCM-HANDLER] 중복 메시지 - 무시: $messageId');
      return false;
    }
    
    _processedMessageIds.add(messageId);
    // ignore: avoid_print
    print('✅ [FCM-HANDLER] 새 메시지 처리 시작: $messageId');
    
    // 🧹 메모리 관리: 100개 이상 쌓이면 오래된 것 제거
    if (_processedMessageIds.length > 100) {
      final toRemove = _processedMessageIds.take(50).toList();
      _processedMessageIds.removeAll(toRemove);
      // ignore: avoid_print
      print('🧹 [FCM-HANDLER] 오래된 메시지 ID 50개 제거');
    }
    
    return true;
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

  /// 처리된 메시지 ID 초기화
  static void clearProcessedMessages() {
    _processedMessageIds.clear();
    // ignore: avoid_print
    print('🧹 [FCM-HANDLER] 처리된 메시지 ID 모두 삭제');
  }
}
