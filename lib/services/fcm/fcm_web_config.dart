import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// FCM 웹 플랫폼 설정 클래스
/// 
/// 웹 플랫폼에서 FCM 초기화 및 토큰 관리를 담당합니다.
/// - VAPID key 관리
/// - 웹 FCM 토큰 가져오기
/// - 웹 알림 권한 요청 처리
class FCMWebConfig {
  // 🔑 Firebase Cloud Messaging VAPID Key (Web Push)
  // Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
  static const String vapidKey = 'BM2qgTRRwT-mG4shgKLDr7CnVf5-xVs3DqNNcqY7zzHZXd5P5xWqvCLn8BxGnqJ3YKj0zcY6Kp0YwQ_Zr8vK2jM';
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  /// 웹 플랫폼에서 FCM 토큰 가져오기
  /// 
  /// VAPID key를 사용하여 웹 푸시 알림 토큰을 요청합니다.
  /// 
  /// Returns: FCM 토큰 (실패 시 null)
  Future<String?> getWebFCMToken() async {
    if (!kIsWeb) {
      if (kDebugMode) {
        debugPrint('⚠️ [FCM-WEB] 웹 플랫폼이 아닙니다');
      }
      return null;
    }
    
    try {
      if (kDebugMode) {
        debugPrint('🌐 [FCM-WEB] 웹 FCM 토큰 요청 시작...');
        debugPrint('   VAPID Key: ${vapidKey.substring(0, 20)}...');
      }
      
      // VAPID key를 사용하여 토큰 요청
      final token = await _messaging.getToken(vapidKey: vapidKey);
      
      if (token != null) {
        if (kDebugMode) {
          debugPrint('✅ [FCM-WEB] 웹 FCM 토큰 획득 성공');
          debugPrint('   토큰 길이: ${token.length}');
          debugPrint('   토큰 일부: ${token.substring(0, 30)}...');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-WEB] 웹 FCM 토큰이 null입니다');
          debugPrint('   가능한 원인:');
          debugPrint('   1. 브라우저 알림 권한 거부됨');
          debugPrint('   2. VAPID Key 불일치');
          debugPrint('   3. Service Worker 등록 실패');
          debugPrint('   4. 브라우저 호환성 문제 (Safari 등)');
        }
      }
      
      return token;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-WEB] 웹 FCM 토큰 요청 실패: $e');
        debugPrint('   에러 타입: ${e.runtimeType}');
        debugPrint('   Stack trace: $stackTrace');
        debugPrint('   🔍 Firebase Console에서 VAPID Key 확인:');
        debugPrint('   Project Settings > Cloud Messaging > Web Push certificates');
      }
      return null;
    }
  }
  
  /// 웹 알림 권한 상태 확인
  /// 
  /// Returns: true if permission granted, false otherwise
  Future<bool> checkWebNotificationPermission() async {
    if (!kIsWeb) {
      return false;
    }
    
    try {
      final settings = await _messaging.getNotificationSettings();
      final isGranted = settings.authorizationStatus == AuthorizationStatus.authorized ||
                        settings.authorizationStatus == AuthorizationStatus.provisional;
      
      if (kDebugMode) {
        debugPrint('🔔 [FCM-WEB] 알림 권한 상태: ${settings.authorizationStatus}');
        if (!isGranted) {
          debugPrint('   ⚠️ 알림 권한이 필요합니다!');
          debugPrint('   브라우저 설정에서 알림 권한을 허용해주세요.');
        }
      }
      
      return isGranted;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-WEB] 권한 확인 실패: $e');
      }
      return false;
    }
  }
  
  /// 웹 알림 권한 요청
  /// 
  /// Returns: AuthorizationStatus
  Future<AuthorizationStatus> requestWebNotificationPermission() async {
    if (!kIsWeb) {
      return AuthorizationStatus.notDetermined;
    }
    
    try {
      if (kDebugMode) {
        debugPrint('🔔 [FCM-WEB] 알림 권한 요청 중...');
      }
      
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      if (kDebugMode) {
        debugPrint('✅ [FCM-WEB] 알림 권한 요청 완료: ${settings.authorizationStatus}');
      }
      
      return settings.authorizationStatus;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-WEB] 권한 요청 실패: $e');
      }
      return AuthorizationStatus.denied;
    }
  }
  
  /// 웹 FCM 초기화 (토큰 요청 + 권한 확인)
  /// 
  /// 웹 플랫폼에서 FCM을 완전히 초기화합니다.
  /// 1. 알림 권한 요청
  /// 2. FCM 토큰 가져오기
  /// 
  /// Returns: FCM 토큰 (실패 시 null)
  Future<String?> initializeWebFCM() async {
    if (!kIsWeb) {
      return null;
    }
    
    try {
      if (kDebugMode) {
        debugPrint('🌐 [FCM-WEB] 웹 FCM 초기화 시작...');
      }
      
      // Step 1: 알림 권한 요청
      final status = await requestWebNotificationPermission();
      
      if (status != AuthorizationStatus.authorized && 
          status != AuthorizationStatus.provisional) {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-WEB] 알림 권한이 거부되었습니다');
        }
        return null;
      }
      
      // Step 2: FCM 토큰 가져오기
      final token = await getWebFCMToken();
      
      if (token != null) {
        if (kDebugMode) {
          debugPrint('✅ [FCM-WEB] 웹 FCM 초기화 완료');
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-WEB] 토큰 획득 실패');
        }
      }
      
      return token;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-WEB] 초기화 실패: $e');
      }
      return null;
    }
  }
}
