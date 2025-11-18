import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication ID Token 관리 헬퍼
/// 
/// ID Token 캐싱, 자동 갱신, 만료 처리를 담당합니다.
/// - ID Token은 1시간 유효 (Firebase 기본값)
/// - 자동 캐싱으로 성능 최적화
/// - 만료 시 자동 갱신
class FirebaseAuthTokenHelper {
  // Singleton 패턴
  static final FirebaseAuthTokenHelper _instance = FirebaseAuthTokenHelper._internal();
  factory FirebaseAuthTokenHelper() => _instance;
  FirebaseAuthTokenHelper._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 캐시된 ID Token
  String? _cachedToken;
  DateTime? _tokenExpiryTime;

  /// 현재 사용자의 ID Token 가져오기 (캐싱 최적화)
  /// 
  /// - 캐시된 토큰이 유효하면 즉시 반환 (네트워크 요청 없음)
  /// - 토큰이 만료되었거나 없으면 Firebase에서 새로 가져옴
  /// - [forceRefresh] = true: 강제로 새 토큰 발급
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    try {
      final user = _auth.currentUser;
      
      if (user == null) {
        if (kDebugMode) {
          debugPrint('⚠️ [AUTH-TOKEN] 로그인된 사용자 없음');
        }
        _cachedToken = null;
        _tokenExpiryTime = null;
        return null;
      }

      // 강제 갱신 요청이 아니고, 캐시된 토큰이 유효한 경우
      if (!forceRefresh && _cachedToken != null && _tokenExpiryTime != null) {
        // 만료 5분 전까지 캐시 사용 (안전 마진)
        final now = DateTime.now();
        if (now.isBefore(_tokenExpiryTime!.subtract(const Duration(minutes: 5)))) {
          if (kDebugMode) {
            final remainingMinutes = _tokenExpiryTime!.difference(now).inMinutes;
            debugPrint('✅ [AUTH-TOKEN] 캐시된 토큰 사용 (유효 시간: ${remainingMinutes}분 남음)');
          }
          return _cachedToken;
        }
      }

      // 새 토큰 발급
      if (kDebugMode) {
        debugPrint('🔄 [AUTH-TOKEN] 새 ID Token 발급 중... (forceRefresh: $forceRefresh)');
      }

      final idToken = await user.getIdToken(forceRefresh);
      
      if (idToken != null) {
        _cachedToken = idToken;
        // Firebase ID Token은 기본적으로 1시간 유효
        _tokenExpiryTime = DateTime.now().add(const Duration(hours: 1));
        
        if (kDebugMode) {
          debugPrint('✅ [AUTH-TOKEN] 새 토큰 발급 완료');
          debugPrint('   - Token: ${idToken.substring(0, 20)}...');
          debugPrint('   - 만료 시간: $_tokenExpiryTime');
        }
      }

      return idToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AUTH-TOKEN] ID Token 가져오기 실패: $e');
      }
      _cachedToken = null;
      _tokenExpiryTime = null;
      return null;
    }
  }

  /// ID Token 강제 갱신
  /// 
  /// 401 Unauthorized 에러 발생 시 호출하여 토큰을 새로 발급받습니다.
  Future<String?> refreshToken() async {
    if (kDebugMode) {
      debugPrint('🔄 [AUTH-TOKEN] 토큰 강제 갱신 시작...');
    }
    return await getIdToken(forceRefresh: true);
  }

  /// 캐시 초기화
  /// 
  /// 로그아웃 시 호출하여 캐시된 토큰을 삭제합니다.
  void clearCache() {
    if (kDebugMode) {
      debugPrint('🧹 [AUTH-TOKEN] 토큰 캐시 초기화');
    }
    _cachedToken = null;
    _tokenExpiryTime = null;
  }

  /// 캐시된 토큰이 유효한지 확인
  bool isCachedTokenValid() {
    if (_cachedToken == null || _tokenExpiryTime == null) {
      return false;
    }
    
    // 만료 5분 전까지 유효로 간주
    final now = DateTime.now();
    return now.isBefore(_tokenExpiryTime!.subtract(const Duration(minutes: 5)));
  }

  /// 현재 캐시된 토큰 정보 (디버깅용)
  Map<String, dynamic> getCacheInfo() {
    return {
      'hasCachedToken': _cachedToken != null,
      'tokenPreview': _cachedToken != null ? '${_cachedToken!.substring(0, 20)}...' : null,
      'expiryTime': _tokenExpiryTime?.toIso8601String(),
      'isValid': isCachedTokenValid(),
      'remainingMinutes': _tokenExpiryTime != null 
          ? _tokenExpiryTime!.difference(DateTime.now()).inMinutes 
          : null,
    };
  }
}
