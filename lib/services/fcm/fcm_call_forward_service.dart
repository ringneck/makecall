import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/fcm_token_model.dart';
import 'fcm_platform_utils.dart';

/// 착신전환 설정 변경 푸시 알림 서비스
/// 
/// 착신전환 설정이 변경될 때 다른 활성 기기에 푸시 알림을 전송합니다.
/// 설정을 실행한 기기는 제외하고 나머지 기기에만 알림을 보냅니다.
class FCMCallForwardService {
  final DatabaseService _databaseService = DatabaseService();
  final FCMPlatformUtils _platformUtils = FCMPlatformUtils();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 착신전환 설정 활성화 알림 전송
  /// 
  /// 현재 기기를 제외한 모든 활성 기기에 푸시 알림을 전송합니다.
  Future<void> sendCallForwardEnabledNotification({
    required String userId,
    required String extensionNumber,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📤 ========== 착신전환 설정 알림 전송 ==========');
        debugPrint('   👤 User ID: $userId');
        debugPrint('   📱 Extension: $extensionNumber');
        debugPrint('   📋 알림 타입: 착신전환 활성화');
      }

      // 🎵 사용자 ringtone 정보 가져오기
      String? ringtone = await _getUserRingtone(userId);

      await _sendNotificationToOtherDevices(
        userId: userId,
        title: '착신전환 설정',
        body: '착신전환 사용이 설정되었습니다. ($extensionNumber)',
        data: {
          'type': 'call_forward_enabled',
          'extensionNumber': extensionNumber,
          if (ringtone != null) 'ringtone': ringtone, // 🎵 ringtone 추가
        },
      );

      if (kDebugMode) {
        debugPrint('   ✅ 착신전환 설정 알림 전송 완료');
        debugPrint('================================================');
        debugPrint('');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CallForward] 착신전환 설정 알림 전송 실패: $e');
      }
    }
  }

  /// 착신전환 해제 알림 전송
  Future<void> sendCallForwardDisabledNotification({
    required String userId,
    required String extensionNumber,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📤 ========== 착신전환 해제 알림 전송 ==========');
        debugPrint('   👤 User ID: $userId');
        debugPrint('   📱 Extension: $extensionNumber');
        debugPrint('   📋 알림 타입: 착신전환 해제');
      }

      // 🎵 사용자 ringtone 정보 가져오기
      String? ringtone = await _getUserRingtone(userId);

      await _sendNotificationToOtherDevices(
        userId: userId,
        title: '착신전환 해제',
        body: '착신전환 사용이 해제되었습니다. ($extensionNumber)',
        data: {
          'type': 'call_forward_disabled',
          'extensionNumber': extensionNumber,
          if (ringtone != null) 'ringtone': ringtone, // 🎵 ringtone 추가
        },
      );

      if (kDebugMode) {
        debugPrint('   ✅ 착신전환 해제 알림 전송 완료');
        debugPrint('================================================');
        debugPrint('');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CallForward] 착신전환 해제 알림 전송 실패: $e');
      }
    }
  }

  /// 착신전환 번호 변경 알림 전송
  Future<void> sendCallForwardNumberChangedNotification({
    required String userId,
    required String extensionNumber,
    required String newNumber,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('');
        debugPrint('📤 ========== 착신전환 번호 변경 알림 전송 ==========');
        debugPrint('   👤 User ID: $userId');
        debugPrint('   📱 Extension: $extensionNumber');
        debugPrint('   📞 New Number: $newNumber');
        debugPrint('   📋 알림 타입: 착신전환 번호 변경');
      }

      // 🎵 사용자 ringtone 정보 가져오기
      String? ringtone = await _getUserRingtone(userId);

      await _sendNotificationToOtherDevices(
        userId: userId,
        title: '착신전환 번호 변경',
        body: '착신전환 번호가 변경되었습니다. ($extensionNumber → $newNumber)',
        data: {
          'type': 'call_forward_number_changed',
          'extensionNumber': extensionNumber,
          'newNumber': newNumber,
          if (ringtone != null) 'ringtone': ringtone, // 🎵 ringtone 추가
        },
      );

      if (kDebugMode) {
        debugPrint('   ✅ 착신전환 번호 변경 알림 전송 완료');
        debugPrint('================================================');
        debugPrint('');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CallForward] 착신전환 번호 변경 알림 전송 실패: $e');
      }
    }
  }

  /// 현재 기기를 제외한 다른 활성 기기에 알림 전송
  Future<void> _sendNotificationToOtherDevices({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      // 1. 현재 기기 정보 가져오기
      final currentDeviceId = await _platformUtils.getDeviceId();
      final currentPlatformLower = _platformUtils.getPlatformName();
      
      // 🔑 CRITICAL: 플랫폼 이름을 대문자로 변환 (Firestore 형식과 일치)
      String currentPlatform;
      if (currentPlatformLower == 'android') {
        currentPlatform = 'Android';
      } else if (currentPlatformLower == 'ios') {
        currentPlatform = 'iOS';
      } else if (currentPlatformLower == 'web') {
        currentPlatform = 'Web';
      } else {
        currentPlatform = currentPlatformLower; // unknown 등
      }
      
      final currentDeviceKey = '${currentDeviceId}_$currentPlatform';

      if (kDebugMode) {
        // 현재 기기 정보 $currentDeviceKey');
      }

      // 2. 모든 활성 FCM 토큰 조회
      final allTokens = await _databaseService.getAllActiveFcmTokens(userId);

      if (kDebugMode) {
        // 전체 활성 기기 조회 ${allTokens.length}개');
      }

      // 3. 현재 기기를 제외한 다른 기기 필터링
      final otherDeviceTokens = allTokens.where((token) {
        final deviceKey = '${token.deviceId}_${token.platform}';
        return deviceKey != currentDeviceKey;
      }).toList();

      if (kDebugMode) {
        // 알림 전송 대상 확인 ${otherDeviceTokens.length}개 기기');
        for (var token in otherDeviceTokens) {
        }
      }

      if (otherDeviceTokens.isEmpty) {
        if (kDebugMode) {
          debugPrint('   ℹ️  다른 활성 기기가 없어 알림 전송 스킵');
        }
        return;
      }

      // 4. FCM 알림 데이터 생성
      final notification = {
        'notification': {
          'title': title,
          'body': body,
        },
        'data': {
          ...data,
          'timestamp': DateTime.now().toIso8601String(),
        },
      };

      // 5. 각 기기에 알림 저장 (Firestore에 알림 저장 → Cloud Functions가 FCM 전송)
      for (var token in otherDeviceTokens) {
        await _firestore.collection('fcm_notifications').add({
          'userId': userId,
          'fcmToken': token.fcmToken,
          'deviceId': token.deviceId,
          'deviceName': token.deviceName,
          'platform': token.platform,
          'notification': notification,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          debugPrint('   ✅ 알림 저장: ${token.deviceName}');
        }
      }

      if (kDebugMode) {
        debugPrint('   ✅ 총 ${otherDeviceTokens.length}개 기기에 알림 저장 완료');
        debugPrint('   📡 Cloud Functions가 FCM으로 전송합니다');
      }

    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CallForward] 알림 전송 실패: $e');
      }
      rethrow;
    }
  }

  /// 사용자의 모든 활성 기기 정보 조회
  Future<List<FcmTokenModel>> getActiveDevices(String userId) async {
    try {
      return await _databaseService.getAllActiveFcmTokens(userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CallForward] 활성 기기 조회 실패: $e');
      }
      return [];
    }
  }

  /// 🎵 사용자 DB에서 ringtone 정보 가져오기
  Future<String?> _getUserRingtone(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ [FCM-CallForward] 사용자 문서 없음');
        }
        return null;
      }

      final data = userDoc.data();
      if (data == null) return null;

      // ringtone 필드 가져오기 (없으면 null)
      final ringtone = data['ringtone'] as String?;
      
      if (kDebugMode) {
        debugPrint('🎵 [FCM-CallForward] 사용자 ringtone: ${ringtone ?? "없음 (기본 벨소리 사용)"}');
      }

      return ringtone;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [FCM-CallForward] ringtone 조회 실패: $e');
      }
      return null;
    }
  }
}
