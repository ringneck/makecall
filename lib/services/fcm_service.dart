import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;

/// FCM(Firebase Cloud Messaging) 서비스
class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String? _fcmToken;
  
  /// FCM 토큰 가져오기
  String? get fcmToken => _fcmToken;
  
  /// FCM 초기화
  Future<void> initialize(String userId) async {
    try {
      if (kDebugMode) {
        debugPrint('🔔 FCM 서비스 초기화 시작...');
      }
      
      // 알림 권한 요청
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      if (kDebugMode) {
        debugPrint('📱 알림 권한 상태: ${settings.authorizationStatus}');
      }
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // FCM 토큰 가져오기
        _fcmToken = await _messaging.getToken();
        
        if (_fcmToken != null) {
          if (kDebugMode) {
            debugPrint('✅ FCM 토큰 획득: ${_fcmToken!.substring(0, 20)}...');
          }
          
          // Firestore에 토큰 저장
          await _saveFCMToken(userId, _fcmToken!);
          
          // 토큰 갱신 리스너 등록
          _messaging.onTokenRefresh.listen((newToken) {
            if (kDebugMode) {
              debugPrint('🔄 FCM 토큰 갱신: ${newToken.substring(0, 20)}...');
            }
            _fcmToken = newToken;
            _saveFCMToken(userId, newToken);
          });
          
          // 포그라운드 메시지 리스너
          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
          
          // 백그라운드 메시지 핸들러는 main.dart에서 설정
          
        } else {
          if (kDebugMode) {
            debugPrint('⚠️ FCM 토큰을 가져올 수 없습니다 (웹 플랫폼일 수 있음)');
          }
        }
      } else {
        if (kDebugMode) {
          debugPrint('❌ 알림 권한이 거부되었습니다');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 초기화 오류: $e');
      }
    }
  }
  
  /// FCM 토큰을 Firestore에 저장
  Future<void> _saveFCMToken(String userId, String token) async {
    try {
      final deviceId = await _getDeviceId();
      final platform = _getPlatformName();
      
      await _firestore.collection('fcm_tokens').doc(token).set({
        'userId': userId,
        'token': token,
        'deviceId': deviceId,
        'deviceName': await _getDeviceName(),
        'platform': platform,
        'appVersion': '1.0.0', // TODO: 실제 앱 버전으로 변경
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'lastUsedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ FCM 토큰 Firestore 저장 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 토큰 저장 오류: $e');
      }
    }
  }
  
  /// 포그라운드 메시지 처리
  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('📨 포그라운드 메시지 수신:');
      debugPrint('  제목: ${message.notification?.title}');
      debugPrint('  내용: ${message.notification?.body}');
      debugPrint('  데이터: ${message.data}');
    }
    
    // TODO: 로컬 알림 표시 (flutter_local_notifications 패키지 사용)
  }
  
  /// 사용자 알림 설정 가져오기
  Future<Map<String, dynamic>?> getUserNotificationSettings(String userId) async {
    try {
      final doc = await _firestore
          .collection('user_notification_settings')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      
      // 기본 설정 반환
      return {
        'pushEnabled': true,
        'soundEnabled': true,
        'vibrationEnabled': true,
        'incomingCallNotification': true,
        'missedCallNotification': true,
        'messageNotification': true,
        'quietHoursEnabled': false,
        'quietHoursStart': '22:00',
        'quietHoursEnd': '08:00',
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 조회 오류: $e');
      }
      return null;
    }
  }
  
  /// 사용자 알림 설정 업데이트
  Future<void> updateNotificationSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await _firestore
          .collection('user_notification_settings')
          .doc(userId)
          .set({
        ...settings,
        'userId': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ 알림 설정 업데이트 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 업데이트 오류: $e');
      }
      rethrow;
    }
  }
  
  /// 특정 설정 항목만 업데이트
  Future<void> updateSingleSetting(
    String userId,
    String key,
    dynamic value,
  ) async {
    try {
      await _firestore
          .collection('user_notification_settings')
          .doc(userId)
          .set({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      if (kDebugMode) {
        debugPrint('✅ 알림 설정 업데이트 완료: $key = $value');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 알림 설정 업데이트 오류: $e');
      }
      rethrow;
    }
  }
  
  /// FCM 토큰 비활성화 (로그아웃 시)
  Future<void> deactivateToken() async {
    if (_fcmToken == null) return;
    
    try {
      await _firestore.collection('fcm_tokens').doc(_fcmToken).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ FCM 토큰 비활성화 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ FCM 토큰 비활성화 오류: $e');
      }
    }
  }
  
  /// 기기 ID 가져오기
  Future<String> _getDeviceId() async {
    try {
      // TODO: device_info_plus 패키지를 사용하여 실제 기기 ID 가져오기
      return 'device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      return 'unknown_device';
    }
  }
  
  /// 기기 이름 가져오기
  Future<String> _getDeviceName() async {
    try {
      // TODO: device_info_plus 패키지를 사용하여 실제 기기 이름 가져오기
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device';
    }
  }
  
  /// 플랫폼 이름 가져오기
  String _getPlatformName() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isIOS) {
      return 'ios';
    }
    return 'unknown';
  }
}
