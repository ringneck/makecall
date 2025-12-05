import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FCM 플랫폼 유틸리티 클래스
/// 
/// 기기 정보 조회 및 플랫폼 감지 관련 유틸리티 메서드를 제공합니다.
/// - 기기 ID 조회 (Android, iOS, Web)
/// - 기기 이름 조회 (사용자 친화적인 이름)
/// - 플랫폼 감지 (android, ios, web)
class FCMPlatformUtils {
  static const String _deviceIdCacheKey = 'cached_device_id';
  String? _cachedDeviceId;

  /// 기기 ID 가져오기
  /// 
  /// FCM 토큰과 함께 사용하여 기기를 고유하게 식별합니다.
  /// 중복 로그인 방지에 사용됩니다.
  Future<String> getDeviceId() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        // 웹: 브라우저 + OS 조합으로 ID 생성
        return 'web_${webInfo.browserName.name}_${webInfo.platform ?? "unknown"}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android: androidId 사용 (고유한 기기 식별자)
        return androidInfo.id; // Example: "5d513e7a5fb1e2d5"
      } else if (Platform.isIOS) {
        // 🔧 iOS: 앱 재설치에도 유지되는 안정적인 Device ID 관리
        // CRITICAL: identifierForVendor는 앱 재설치 시 변경되므로
        // SharedPreferences에 저장된 UUID를 최우선으로 사용
        
        // 1️⃣ 메모리 캐시 확인 (가장 빠름)
        if (_cachedDeviceId != null) {
          debugPrint('📱 [iOS] 메모리 캐시된 deviceId 사용: $_cachedDeviceId');
          return _cachedDeviceId!;
        }
        
        // 2️⃣ SharedPreferences 확인 (영구 저장소 - 최우선)
        try {
          final prefs = await SharedPreferences.getInstance();
          final cachedId = prefs.getString(_deviceIdCacheKey);
          
          if (cachedId != null && cachedId.isNotEmpty) {
            debugPrint('📱 [iOS] SharedPreferences 영구 deviceId 사용: $cachedId');
            _cachedDeviceId = cachedId;
            return cachedId;
          }
          
          // 🔍 SharedPreferences에 없음 → 최초 실행 또는 앱 재설치
          debugPrint('🆕 [iOS] SharedPreferences에 deviceId 없음 - 최초 실행 감지');
        } catch (e) {
          debugPrint('⚠️ [iOS] SharedPreferences 읽기 실패: $e');
        }
        
        // 3️⃣ identifierForVendor 시도 (fallback)
        final iosInfo = await deviceInfo.iosInfo;
        final vendorId = iosInfo.identifierForVendor;
        
        String finalDeviceId;
        
        if (vendorId != null && vendorId.isNotEmpty) {
          // identifierForVendor 사용 가능
          debugPrint('📱 [iOS] identifierForVendor 가져옴: $vendorId');
          finalDeviceId = vendorId;
        } else {
          // identifierForVendor null → 고유 ID 생성 (시간 + 랜덤)
          debugPrint('⚠️ [iOS] identifierForVendor가 null - 새 고유 ID 생성');
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final random = timestamp.hashCode.toRadixString(36);
          finalDeviceId = 'ios_$timestamp\_$random';
        }
        
        // 4️⃣ 영구 저장 (SharedPreferences + 메모리 캐시)
        _cachedDeviceId = finalDeviceId;
        
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_deviceIdCacheKey, finalDeviceId);
          debugPrint('✅ [iOS] deviceId 영구 저장 완료: $finalDeviceId');
          debugPrint('   → 앱 재설치 후에도 이 ID가 유지됩니다');
        } catch (e) {
          debugPrint('⚠️ [iOS] SharedPreferences 저장 실패: $e');
        }
        
        return finalDeviceId;
      }
      
      // Fallback: 타임스탬프 기반 ID
      return 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('⚠️ 기기 ID 조회 실패: $e');
      
      // iOS에서 캐시된 값이 있으면 사용
      if (_cachedDeviceId != null) {
        debugPrint('📱 오류 시 캐시된 deviceId 사용: $_cachedDeviceId');
        return _cachedDeviceId!;
      }
      
      return 'fallback_device_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 기기 이름 가져오기
  /// 
  /// 사용자에게 표시할 기기 이름을 반환합니다.
  /// 실제 기기 모델명과 OS 버전을 포함합니다.
  Future<String> getDeviceName() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        // 웹: 브라우저 이름 + OS
        final browser = webInfo.browserName.name;
        final platform = webInfo.platform ?? 'Unknown OS';
        return '$browser on $platform';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Android: 제조사 + 모델명
        // 예: "Samsung Galaxy S21", "Google Pixel 6"
        final manufacturer = androidInfo.manufacturer;
        final model = androidInfo.model;
        return '$manufacturer $model';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // iOS: 모델명 + iOS 버전
        // 예: "iPhone 15 Pro", "iPad Pro"
        final model = iosInfo.utsname.machine; // 예: "iPhone14,3"
        final version = iosInfo.systemVersion; // 예: "17.0"
        
        // 사용자 친화적인 모델명 변환
        final friendlyName = getiOSFriendlyName(model);
        return '$friendlyName (iOS $version)';
      }
      
      return 'Unknown Device';
    } catch (e) {
      debugPrint('⚠️ 기기 이름 조회 실패: $e');
      
      // Fallback: 플랫폼 기본 이름
      if (kIsWeb) {
        return 'Web Browser';
      } else if (Platform.isAndroid) {
        return 'Android Device';
      } else if (Platform.isIOS) {
        return 'iOS Device';
      }
      return 'Unknown Device';
    }
  }

  /// iOS 기기 코드를 사용자 친화적인 이름으로 변환
  /// 
  /// 예: "iPhone14,3" → "iPhone 13 Pro Max"
  String getiOSFriendlyName(String machineCode) {
    // 주요 iPhone 모델 매핑 (최신 모델 위주)
    final Map<String, String> iosModels = {
      // iPhone 15 시리즈
      'iPhone16,1': 'iPhone 15 Pro',
      'iPhone16,2': 'iPhone 15 Pro Max',
      'iPhone15,4': 'iPhone 15',
      'iPhone15,5': 'iPhone 15 Plus',
      
      // iPhone 14 시리즈
      'iPhone15,2': 'iPhone 14 Pro',
      'iPhone15,3': 'iPhone 14 Pro Max',
      'iPhone14,7': 'iPhone 14',
      'iPhone14,8': 'iPhone 14 Plus',
      
      // iPhone 13 시리즈
      'iPhone14,2': 'iPhone 13 Pro',
      'iPhone14,3': 'iPhone 13 Pro Max',
      'iPhone14,4': 'iPhone 13 Mini',
      'iPhone14,5': 'iPhone 13',
      
      // iPhone 12 시리즈
      'iPhone13,1': 'iPhone 12 Mini',
      'iPhone13,2': 'iPhone 12',
      'iPhone13,3': 'iPhone 12 Pro',
      'iPhone13,4': 'iPhone 12 Pro Max',
      
      // iPad 시리즈 (주요 모델)
      'iPad13,18': 'iPad Pro 12.9" (6th gen)',
      'iPad13,16': 'iPad Pro 11" (4th gen)',
      'iPad13,1': 'iPad Air (4th gen)',
      'iPad14,1': 'iPad mini (6th gen)',
    };
    
    // 매핑된 이름이 있으면 반환, 없으면 원래 코드 반환
    return iosModels[machineCode] ?? machineCode;
  }

  /// 플랫폼 이름 가져오기
  String getPlatformName() {
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
