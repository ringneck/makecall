import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../database_service.dart';
import '../../models/fcm_token_model.dart';
import '../../exceptions/max_device_limit_exception.dart';
import 'fcm_platform_utils.dart';

/// FCM 토큰 관리자
/// 
/// FCM 토큰의 생명주기를 관리합니다:
/// - 토큰 저장 (중복 저장 방지)
/// - 토큰 갱신
/// - 토큰 비활성화 (로그아웃 시)
/// - 기기 승인 로직 (다중 기기 로그인 지원)
class FCMTokenManager {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  final FCMPlatformUtils _platformUtils = FCMPlatformUtils();

  // 🔒 중복 저장 방지
  String? _lastSavedToken;
  DateTime? _lastSaveTime;

  /// FCM 토큰을 Firestore에 저장 (중복 로그인 방지 포함)
  /// 
  /// ⚠️ 중요: 사용자 데이터(users 컬렉션)는 절대 삭제하지 않음!
  /// 
  /// 중복 로그인 방지 프로세스:
  /// 1. 기존 활성 토큰 조회 (fcm_tokens 컬렉션)
  /// 2. 다른 기기 감지 시 → 승인 요청 로직 실행 (외부에서 처리)
  /// 3. 새 FCM 토큰 저장
  /// 
  /// Returns: (needsApproval, otherDevices) - 승인이 필요한지 여부와 다른 기기 목록
  Future<(bool, List<FcmTokenModel>)> saveFCMToken({
    required String userId, 
    required String token,
  }) async {
    try {
      // ignore: avoid_print
      print('💾 [FCM-SAVE] 토큰 저장 시작');
      
      // 🔒 중복 저장 방지: 동일 토큰이 최근 1분 내에 저장되었으면 스킵
      if (_lastSavedToken == token && 
          _lastSaveTime != null && 
          DateTime.now().difference(_lastSaveTime!) < const Duration(minutes: 1)) {
        // ignore: avoid_print
        print('⏭️  [FCM-SAVE] 동일 토큰이 최근에 저장됨 - 중복 저장 스킵');
        // ignore: avoid_print
        print('   - 마지막 저장: ${DateTime.now().difference(_lastSaveTime!).inSeconds}초 전');
        return (false, <FcmTokenModel>[]);
      }
      
      final deviceId = await _platformUtils.getDeviceId();
      final deviceName = await _platformUtils.getDeviceName();
      final platformLower = _platformUtils.getPlatformName();
      
      // 🔑 CRITICAL: 플랫폼 이름을 대문자로 변환 (Firestore 문서 ID 형식 통일)
      // fcm_tokens 문서 ID: userId_deviceId_Android 또는 userId_deviceId_iOS
      String platform;
      if (platformLower == 'android') {
        platform = 'Android';
      } else if (platformLower == 'ios') {
        platform = 'iOS';
      } else {
        platform = platformLower; // web, unknown 등
      }
      
      // ignore: avoid_print
      print('   - Device ID: $deviceId');
      // ignore: avoid_print
      print('   - Device Name: $deviceName');
      // ignore: avoid_print
      print('   - Platform: $platform');
      
      // 🔧 레거시 토큰 정리 (플랫폼 정보 없는 옛날 토큰 삭제)
      try {
        await _databaseService.cleanupLegacyFcmTokens(userId);
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-SAVE] 레거시 토큰 정리 실패 (무시): $e');
      }
      
      // 1. 모든 기존 활성 토큰 조회 (다중 기기 지원)
      // ignore: avoid_print
      print('🔍 [FCM-SAVE] 모든 활성 토큰 조회 중...');
      final existingTokens = await _databaseService.getAllActiveFcmTokens(userId);
      
      // 🔑 CRITICAL: Device ID + Platform 조합으로 기기 구분
      // 같은 Device ID라도 플랫폼이 다르면 다른 기기로 취급
      final currentDeviceKey = '${deviceId}_$platform';
      
      // 🔧 FIX: 같은 기기의 기존 토큰을 먼저 비활성화 (중복 방지)
      final sameDeviceTokens = existingTokens
          .where((token) => '${token.deviceId}_${token.platform}' == currentDeviceKey)
          .toList();
      
      // 🔒 CRITICAL: 같은 기기의 기존 토큰이 승인되지 않았는지 확인
      // 🔧 FIX: 모든 기기의 승인 대기 상태도 체크 (같은 기기만이 아니라)
      bool hasUnapprovedToken = false;
      
      // 1) 같은 기기의 승인되지 않은 토큰 체크
      if (sameDeviceTokens.isNotEmpty) {
        // ignore: avoid_print
        print('🧹 [FCM-SAVE] 같은 기기의 기존 토큰 ${sameDeviceTokens.length}개 발견 - 비활성화 중...');
        for (var oldToken in sameDeviceTokens) {
          // 🔒 승인되지 않은 토큰 감지
          if (!oldToken.isApproved) {
            hasUnapprovedToken = true;
            // ignore: avoid_print
            print('   ⚠️ 승인되지 않은 기존 토큰 발견: ${oldToken.fcmToken.substring(0, 20)}...');
          }
          
          // Firestore에서 직접 비활성화
          await _firestore
              .collection('fcm_tokens')
              .where('fcmToken', isEqualTo: oldToken.fcmToken)
              .get()
              .then((snapshot) async {
            for (var doc in snapshot.docs) {
              await doc.reference.update({'isActive': false});
            }
          });
          // ignore: avoid_print
          print('   ✅ 비활성화 완료: ${oldToken.fcmToken.substring(0, 20)}...');
        }
      }
      
      // 2) 🔧 FIX: 다른 기기 중에서도 승인 대기 중인 기기가 있는지 체크
      final otherUnapprovedTokens = existingTokens
          .where((token) => 
              '${token.deviceId}_${token.platform}' != currentDeviceKey && 
              !token.isApproved)
          .toList();
      
      if (otherUnapprovedTokens.isNotEmpty) {
        // ignore: avoid_print
        print('⚠️ [FCM-SAVE] 다른 기기에 승인 대기 중인 토큰 ${otherUnapprovedTokens.length}개 발견');
        for (var token in otherUnapprovedTokens) {
          // ignore: avoid_print
          print('   - ${token.deviceName} (${token.platform})');
        }
      }
      
      // 🚫 CRITICAL: 승인되지 않은 토큰이 있으면 로그인 차단
      if (hasUnapprovedToken) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] ========================================');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] 승인되지 않은 기기입니다!');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] ========================================');
        // ignore: avoid_print
        print('   - Device: $deviceName ($platform)');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
        // ignore: avoid_print
        print('   - 이 기기는 승인 대기 상태입니다.');
        // ignore: avoid_print
        print('   - 다른 기기에서 승인을 완료해주세요.');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] ========================================');
        // ignore: avoid_print
        print('');
        throw Exception('Device approval pending - Please approve from another device');
      }
      
      // 현재 기기를 제외한 다른 기기들 필터링
      final otherDevices = existingTokens
          .where((token) => '${token.deviceId}_${token.platform}' != currentDeviceKey)
          .toList();
      
      // 🔍 플랫폼 변경 감지: 같은 Device ID지만 다른 플랫폼
      final sameDeviceIdDifferentPlatform = existingTokens
          .where((token) => token.deviceId == deviceId && token.platform != platform)
          .toList();
      
      if (sameDeviceIdDifferentPlatform.isNotEmpty) {
        // ignore: avoid_print
        print('⚠️  [FCM-SAVE] 플랫폼 변경 감지!');
        // ignore: avoid_print
        print('   - Device ID: $deviceId');
        // ignore: avoid_print
        print('   - 이전 플랫폼: ${sameDeviceIdDifferentPlatform.first.platform}');
        // ignore: avoid_print
        print('   - 새 플랫폼: $platform');
        // ignore: avoid_print
        print('   - 🚨 다른 플랫폼으로 간주하여 승인 요청 진행');
      }
      
      // 🔒 STEP 1: 사용자 정보 조회 (maxDevices 확인)
      int maxDevices = 1; // 기본값
      try {
        // ignore: avoid_print
        print('📊 [FCM-SAVE] 사용자 정보 조회 중 (maxDevices 확인)...');
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          maxDevices = userData?['maxDevices'] as int? ?? 1;
          // ignore: avoid_print
          print('📊 [FCM-SAVE] 사용자 최대 기기 수: $maxDevices개');
        } else {
          // ignore: avoid_print
          print('⚠️ [FCM-SAVE] 사용자 문서 없음 (기본값 1 사용)');
        }
      } catch (e) {
        // ignore: avoid_print
        print('⚠️ [FCM-SAVE] 사용자 정보 조회 실패 (기본값 1 사용): $e');
      }
      
      // 🔒 STEP 2: 기기 수 제한 체크
      if (otherDevices.length >= maxDevices) {
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] ========================================');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] 최대 사용 기기 수 초과!');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] ========================================');
        // ignore: avoid_print
        print('   - 최대 허용 기기 수: $maxDevices개');
        // ignore: avoid_print
        print('   - 현재 활성 기기 수: ${otherDevices.length}개');
        // ignore: avoid_print
        print('   - 새 기기: $deviceName ($platform)');
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('   📋 현재 활성 기기 목록:');
        for (var i = 0; i < otherDevices.length; i++) {
          final device = otherDevices[i];
          // ignore: avoid_print
          print('   ${i + 1}. ${device.deviceName} (${device.platform})');
        }
        // ignore: avoid_print
        print('');
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] ========================================');
        // ignore: avoid_print
        print('');
        
        // 🔧 특별한 Exception 던지기 (UI에서 감지 가능)
        throw MaxDeviceLimitException(
          maxDevices: maxDevices,
          currentDevices: otherDevices.length,
          deviceName: deviceName,
        );
      }
      
      // ignore: avoid_print
      print('✅ [FCM-SAVE] 기기 수 체크 통과 (${otherDevices.length}/$maxDevices개)');
      
      bool needsApproval = false;
      
      if (otherDevices.isNotEmpty) {
        // 다른 기기에서 로그인 감지
        // ignore: avoid_print
        print('🔔 [FCM-SAVE] 새 기기 로그인 감지!');
        // ignore: avoid_print
        print('   - 새 기기: $deviceName ($platform)');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
        // ignore: avoid_print
        print('   - 기존 기기 ${otherDevices.length}개 발견 - 승인 필요');
        
        needsApproval = true;
        
      } else if (existingTokens.any((token) => '${token.deviceId}_${token.platform}' == currentDeviceKey)) {
        // ignore: avoid_print
        print('ℹ️ [FCM-SAVE] 동일 기기 토큰 갱신');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
      } else {
        // ignore: avoid_print
        print('ℹ️ [FCM-SAVE] 첫 로그인 (다른 활성 기기 없음)');
        // ignore: avoid_print
        print('   - Device Key: $currentDeviceKey');
      }
      
      // 🔐 기기 승인 상태 결정
      // - 첫 기기: 자동 승인 (isApproved: true, isActive: true)
      // - 동일 기기 토큰 갱신: 자동 승인 (isApproved: true, isActive: true)
      // - 추가 기기: 승인 대기 (isApproved: false, isActive: false) ← 🔧 FIX
      final bool isApproved = !needsApproval;
      
      if (needsApproval) {
        // ignore: avoid_print
        print('🔒 [FCM-SAVE] 새 기기 승인 대기 상태로 저장 (isApproved: false, isActive: false)');
      } else {
        // ignore: avoid_print
        print('✅ [FCM-SAVE] 기기 자동 승인 (isApproved: true, isActive: true)');
      }
      
      // 2. 새 토큰 모델 생성 및 저장
      final tokenModel = FcmTokenModel(
        userId: userId,
        fcmToken: token,
        deviceId: deviceId,
        deviceName: deviceName,
        platform: platform,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        isActive: isApproved,  // 🔧 FIX: 승인 전에는 비활성 상태
        isApproved: isApproved,
      );
      
      // ignore: avoid_print
      print('💾 [FCM-SAVE] DatabaseService.saveFcmToken() 호출 중...');
      await _databaseService.saveFcmToken(tokenModel);
      
      // ignore: avoid_print
      print('✅ [FCM-SAVE] Firestore 저장 완료!');
      // ignore: avoid_print
      print('   - 컬렉션: fcm_tokens');
      // ignore: avoid_print
      print('   - 문서 ID: ${userId}_${deviceId}_$platform');
      // ignore: avoid_print
      print('   - 기기: $deviceName ($platform)');
      
      // 🔒 저장 성공 - 추적 정보 업데이트
      _lastSavedToken = token;
      _lastSaveTime = DateTime.now();
      // ignore: avoid_print
      print('🔒 [FCM-SAVE] 중복 저장 추적 업데이트 완료');
      
      return (needsApproval, otherDevices);
      
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('❌ [FCM-SAVE] 토큰 저장 오류: $e');
      // ignore: avoid_print
      print('Stack trace:');
      // ignore: avoid_print
      print(stackTrace);
      
      // 🔒 CRITICAL: 승인 관련 오류는 반드시 상위로 전파하여 로그인 차단
      if (e.toString().contains('Device approval') || 
          e.toString().contains('denied') || 
          e.toString().contains('timeout')) {
        // ignore: avoid_print
        print('🚫 [FCM-SAVE] 승인 관련 오류 감지 - 상위로 예외 전파');
        rethrow;
      }
      
      // 일반적인 토큰 저장 오류는 무시 (로그인은 계속 진행)
      // ignore: avoid_print
      print('⚠️ [FCM-SAVE] 토큰 저장 실패했지만 로그인은 허용');
      return (false, <FcmTokenModel>[]);
    }
  }

  /// FCM 토큰 비활성화 (로그아웃 시)
  /// 
  /// ⚠️ 중요: 이 메서드는 오직 fcm_tokens 컬렉션만 삭제합니다!
  /// ✅ 보존되는 데이터:
  ///   - users/{userId}: API/WebSocket 설정, 회사 정보 등
  ///   - my_extensions: 등록된 단말번호 정보
  ///   - call_forward_info: 착신전환 설정
  /// 
  /// 로그아웃 시 현재 기기의 FCM 토큰만 삭제합니다.
  Future<void> deactivateToken(String userId, String? currentToken) async {
    try {
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('🔓 [FCM-DEACTIVATE] 현재 기기 토큰 비활성화 시작');
      // ignore: avoid_print
      print('   userId: $userId');
      // ignore: avoid_print
      print('   currentToken: ${currentToken != null ? "${currentToken.substring(0, 20)}..." : "null"}');
      
      // 🔧 FIX: currentToken이 null이어도 deviceId로 토큰 비활성화 시도
      final deviceId = await _platformUtils.getDeviceId();
      final platformLower = _platformUtils.getPlatformName();
      
      // 🔑 CRITICAL: 플랫폼 이름을 대문자로 변환 (Firestore 문서 ID 형식과 일치)
      String platform;
      if (platformLower == 'android') {
        platform = 'Android';
      } else if (platformLower == 'ios') {
        platform = 'iOS';
      } else {
        platform = platformLower; // web, unknown 등
      }
      
      // ignore: avoid_print
      print('   deviceId: $deviceId');
      // ignore: avoid_print
      print('   platform: $platform');
      
      // 🔧 FIX: 삭제가 아니라 isActive를 false로 변경
      // 🔑 CRITICAL: Platform 포함으로 iOS/Android 기기 구분
      await _databaseService.deactivateFcmToken(userId, deviceId, platform);
      
      // ignore: avoid_print
      print('✅ [FCM-DEACTIVATE] 현재 기기 토큰 비활성화 완료');
      // ignore: avoid_print
      print('   ℹ️  다른 기기의 토큰은 영향 없음 (계속 활성 유지)');
      print('');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [FCM-DEACTIVATE] 토큰 비활성화 오류: $e');
      // 🔧 에러를 던지지 않음 - 로그아웃은 계속 진행
    }
  }

  /// 중복 저장 추적 정보 초기화
  void clearSaveTracking() {
    _lastSavedToken = null;
    _lastSaveTime = null;
  }
}
