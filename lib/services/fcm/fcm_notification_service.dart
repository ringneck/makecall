import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../../utils/dialog_utils.dart';

/// FCM 알림 표시 서비스
/// 
/// 책임:
/// - Android 로컬 알림 표시
/// - Web 브라우저 알림 표시
/// - iOS 네이티브 알림 표시
/// - 사용자 알림 설정 조회 및 적용
/// 
/// Phase 3에서 fcm_service.dart에서 분리됨
class FCMNotificationService {
  static BuildContext? _context;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// BuildContext 설정 (main.dart에서 호출)
  static void setContext(BuildContext context) {
    _context = context;
  }
  
  /// 안드로이드 로컬 알림 표시 (포그라운드 전용)
  Future<void> showAndroidNotification(RemoteMessage message) async {
    if (!Platform.isAndroid) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MAKECALL 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림이 있습니다.';
      
      debugPrint('🔔 [FCM-Notification] 안드로이드 알림 표시 시작');
      debugPrint('   제목: $title');
      debugPrint('   내용: $body');
      
      // 📥 사용자 알림 설정 가져오기
      String? userId;
      
      // _context가 있으면 AuthService에서 userId 가져오기
      if (_context != null) {
        try {
          final authService = Provider.of<AuthService>(_context!, listen: false);
          userId = authService.currentUser?.uid;
        } catch (e) {
          debugPrint('⚠️ [FCM-알림설정] AuthService 접근 실패: $e');
        }
      }
      
      Map<String, dynamic>? settings;
      
      if (userId != null) {
        settings = await getUserNotificationSettings(userId);
        debugPrint('📦 [FCM-알림설정] 사용자 설정: $settings');
      } else {
        debugPrint('⚠️ [FCM-알림설정] userId 없음 - 기본 설정 사용');
      }
      
      // 알림 설정 적용 (기본값: 모두 켜짐)
      final pushEnabled = settings?['pushEnabled'] ?? true;
      final soundEnabled = settings?['soundEnabled'] ?? true;
      final vibrationEnabled = settings?['vibrationEnabled'] ?? true;
      
      debugPrint('🔧 [FCM-알림설정] 적용:');
      debugPrint('   - 푸시 알림: $pushEnabled');
      debugPrint('   - 알림음: $soundEnabled');
      debugPrint('   - 진동: $vibrationEnabled');
      debugPrint('');
      debugPrint('⚠️ [안드로이드 알림 체크리스트]');
      debugPrint('1. 기기 무음/진동 모드 확인: 설정 → 소리');
      debugPrint('2. 방해 금지 모드 확인: 설정 → 방해 금지');
      debugPrint('3. 앱 알림 설정 확인: 설정 → 앱 → MAKECALL → 알림');
      debugPrint('4. 채널별 설정 확인: 각 채널의 소리/진동 개별 확인');
      debugPrint('');
      
      // 푸시 알림이 꺼져있으면 알림 표시 안함
      if (!pushEnabled) {
        debugPrint('⏭️ [FCM-Notification] 푸시 알림이 비활성화되어 알림 표시 건너뜀');
        return;
      }
      
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      // 사용자 설정에 따라 적절한 알림 채널 선택
      String channelId;
      String channelName;
      String channelDescription;
      
      if (soundEnabled && vibrationEnabled) {
        channelId = 'notification_sound_on_vibration_on';
        channelName = 'Notifications with Sound and Vibration';
        channelDescription = 'Notifications with both sound and vibration enabled';
      } else if (!soundEnabled && vibrationEnabled) {
        channelId = 'notification_sound_off_vibration_on';
        channelName = 'Notifications with Vibration Only';
        channelDescription = 'Notifications with vibration only (no sound)';
      } else if (soundEnabled && !vibrationEnabled) {
        channelId = 'notification_sound_on_vibration_off';
        channelName = 'Notifications with Sound Only';
        channelDescription = 'Notifications with sound only (no vibration)';
      } else {
        channelId = 'notification_sound_off_vibration_off';
        channelName = 'Silent Notifications';
        channelDescription = 'Notifications without sound and vibration';
      }
      
      debugPrint('');
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('📱 [FCM-알림] 채널 선택 정보:');
      debugPrint('   - 채널 ID: $channelId');
      debugPrint('   - 채널명: $channelName');
      debugPrint('   - 알림음 요청: $soundEnabled');
      debugPrint('   - 진동 요청: $vibrationEnabled');
      debugPrint('');
      debugPrint('🔍 [시스템 제한 가능성]:');
      debugPrint('   - 기기 무음/진동 모드일 경우 알림음/진동 차단됨');
      debugPrint('   - 방해 금지 모드일 경우 알림음/진동 차단됨');
      debugPrint('   - 앱 설정에서 채널별 소리/진동 비활성화 가능');
      debugPrint('═══════════════════════════════════════════════');
      debugPrint('');
      
      // 알림 상세 설정 (사용자 설정에 맞는 채널 사용)
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId, // 사용자 설정에 맞는 채널 ID
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        playSound: soundEnabled, // 🔊 사용자 설정 적용
        enableVibration: vibrationEnabled, // 📳 사용자 설정 적용
        vibrationPattern: vibrationEnabled ? Int64List.fromList([0, 500, 200, 500]) : null, // 진동 패턴 (0ms 대기, 500ms 진동, 200ms 정지, 500ms 진동)
        icon: '@mipmap/ic_launcher', // 앱 아이콘 사용
      );
      
      // ✅ const 제거: androidDetails가 런타임에 계산되므로 const 사용 불가
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );
      
      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        message.hashCode, // 고유 알림 ID (메시지마다 다름)
        title,
        body,
        notificationDetails,
      );
      
      debugPrint('✅ [FCM-Notification] 안드로이드 알림 표시 완료 (진동: $vibrationEnabled)');
      
    } catch (e) {
      debugPrint('❌ [FCM-Notification] 안드로이드 알림 표시 오류: $e');
    }
  }
  
  /// 웹 플랫폼 알림 표시
  Future<void> showWebNotification(RemoteMessage message) async {
    if (!kIsWeb) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MakeCall 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림';
      
      if (kDebugMode) {
        debugPrint('🌐 [FCM-Notification] 웹 알림 표시: $title - $body');
      }
      
      // 웹 알림은 서비스 워커에서 처리됨
      // 여기서는 앱 내 다이얼로그로 표시
      if (_context != null) {
        await DialogUtils.showInfo(
          _context!,
          body,
          title: title,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-Notification] 웹 알림 표시 오류: $e');
      }
    }
  }
  
  /// iOS 플랫폼 알림 표시 (네이티브 알림 사용)
  Future<void> showIOSNotification(RemoteMessage message) async {
    if (!Platform.isIOS) return;
    
    try {
      final title = message.notification?.title ?? message.data['title'] ?? 'MAKECALL 알림';
      final body = message.notification?.body ?? message.data['body'] ?? '새로운 알림이 있습니다.';
      
      debugPrint('🍎 [FCM-Notification] iOS 알림 표시 시작');
      debugPrint('   제목: $title');
      debugPrint('   내용: $body');
      
      // 📥 사용자 알림 설정 가져오기
      String? userId;
      
      // _context가 있으면 AuthService에서 userId 가져오기
      if (_context != null) {
        try {
          final authService = Provider.of<AuthService>(_context!, listen: false);
          userId = authService.currentUser?.uid;
        } catch (e) {
          debugPrint('⚠️ [FCM-알림설정-iOS] AuthService 접근 실패: $e');
        }
      }
      
      Map<String, dynamic>? settings;
      
      if (userId != null) {
        settings = await getUserNotificationSettings(userId);
        debugPrint('📦 [FCM-알림설정-iOS] 사용자 설정: $settings');
      } else {
        debugPrint('⚠️ [FCM-알림설정-iOS] userId 없음 - 기본 설정 사용');
      }
      
      // 알림 설정 적용 (기본값: 모두 켜짐)
      final pushEnabled = settings?['pushEnabled'] ?? true;
      final soundEnabled = settings?['soundEnabled'] ?? true;
      final vibrationEnabled = settings?['vibrationEnabled'] ?? true;
      
      debugPrint('🔧 [FCM-알림설정-iOS] 적용:');
      debugPrint('   - 푸시 알림: $pushEnabled');
      debugPrint('   - 알림음: $soundEnabled');
      debugPrint('   - 진동: $vibrationEnabled');
      
      // 푸시 알림이 꺼져있으면 알림 표시 안함
      if (!pushEnabled) {
        debugPrint('⏭️ [FCM-Notification-iOS] 푸시 알림이 비활성화되어 알림 표시 건너뜀');
        return;
      }
      
      // iOS 네이티브 알림 표시 (소리/진동 제어)
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      
      // iOS 알림 상세 설정 (사용자 설정 적용)
      final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: soundEnabled, // 🔊 사용자 설정 적용
        sound: soundEnabled ? 'ringtone.caf' : null, // 커스텀 사운드 또는 무음
        badgeNumber: 0,
        // iOS는 진동을 소리와 함께 제어 (sound가 있으면 진동도 함께 발생)
        // 진동만 제어하려면 커스텀 사운드 파일 필요
      );
      
      final NotificationDetails notificationDetails = NotificationDetails(
        iOS: iosDetails,
      );
      
      debugPrint('🔔 [FCM-Notification-iOS] 네이티브 알림 표시:');
      debugPrint('   - presentSound: $soundEnabled');
      debugPrint('   - 진동: ${soundEnabled ? "소리와 함께 발생" : "없음"}');
      
      // 알림 표시
      await flutterLocalNotificationsPlugin.show(
        message.hashCode, // 고유 알림 ID
        title,
        body,
        notificationDetails,
      );
      
      debugPrint('✅ [FCM-Notification-iOS] 네이티브 알림 표시 완료');
      
    } catch (e) {
      debugPrint('❌ [FCM-Notification-iOS] 알림 표시 오류: $e');
    }
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
        debugPrint('❌ [FCM-Notification] 알림 설정 조회 오류: $e');
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
        debugPrint('✅ [FCM-Notification] 알림 설정 업데이트 완료');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-Notification] 알림 설정 업데이트 오류: $e');
      }
    }
  }
}
