import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🔄 앱 버전 체크 서비스
/// 
/// Firestore에 저장된 최신 버전과 현재 앱 버전을 비교하여
/// 업데이트 필요 여부를 판단합니다.
/// 
/// Firestore 데이터 구조:
/// ```
/// app_config/version_info
/// {
///   "latest_version": "1.0.0",
///   "minimum_version": "1.0.0",
///   "update_message": "새로운 기능이 추가되었습니다!",
///   "force_update": false
/// }
/// ```
class VersionCheckService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// 버전 비교 결과
  VersionCheckResult? _cachedResult;
  
  /// 현재 앱 버전 정보 가져오기
  Future<PackageInfo> getCurrentVersion() async {
    return await PackageInfo.fromPlatform();
  }
  
  /// Firestore에서 최신 버전 정보 가져오기
  Future<Map<String, dynamic>?> getLatestVersionInfo() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('version_info')
          .get();
      
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [VERSION CHECK] Failed to get version info: $e');
      }
      return null;
    }
  }
  
  /// 버전 체크 수행
  Future<VersionCheckResult> checkVersion() async {
    try {
      // 캐시된 결과가 있으면 반환 (앱 실행 중 한 번만 체크)
      if (_cachedResult != null) {
        return _cachedResult!;
      }
      
      final packageInfo = await getCurrentVersion();
      final currentVersion = packageInfo.version;
      
      final versionInfo = await getLatestVersionInfo();
      
      if (versionInfo == null) {
        // Firestore에 버전 정보가 없으면 최신 버전으로 간주
        _cachedResult = VersionCheckResult(
          currentVersion: currentVersion,
          latestVersion: currentVersion,
          isUpdateAvailable: false,
          isForceUpdate: false,
        );
        return _cachedResult!;
      }
      
      final latestVersion = versionInfo['latest_version'] as String? ?? currentVersion;
      final minimumVersion = versionInfo['minimum_version'] as String? ?? currentVersion;
      final updateMessage = versionInfo['update_message'] as String?;
      final forceUpdate = versionInfo['force_update'] as bool? ?? false;
      
      // 버전 비교
      final isUpdateAvailable = _compareVersions(currentVersion, latestVersion) < 0;
      final isForceUpdate = forceUpdate && _compareVersions(currentVersion, minimumVersion) < 0;
      
      _cachedResult = VersionCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minimumVersion: minimumVersion,
        isUpdateAvailable: isUpdateAvailable,
        isForceUpdate: isForceUpdate,
        updateMessage: updateMessage,
      );
      
      if (kDebugMode) {
        debugPrint('🔄 [VERSION CHECK] Current: $currentVersion');
        debugPrint('🔄 [VERSION CHECK] Latest: $latestVersion');
        debugPrint('🔄 [VERSION CHECK] Update Available: $isUpdateAvailable');
        debugPrint('🔄 [VERSION CHECK] Force Update: $isForceUpdate');
      }
      
      return _cachedResult!;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [VERSION CHECK] Error: $e');
      }
      
      // 에러 발생 시 현재 버전을 최신으로 간주
      final packageInfo = await getCurrentVersion();
      return VersionCheckResult(
        currentVersion: packageInfo.version,
        latestVersion: packageInfo.version,
        isUpdateAvailable: false,
        isForceUpdate: false,
      );
    }
  }
  
  /// 버전 문자열 비교 (semantic versioning)
  /// 
  /// 반환값:
  /// - 음수: version1 < version2
  /// - 0: version1 == version2
  /// - 양수: version1 > version2
  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final v2Parts = version2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    // 버전 파트 개수를 맞춤 (1.0 vs 1.0.0 처리)
    while (v1Parts.length < 3) v1Parts.add(0);
    while (v2Parts.length < 3) v2Parts.add(0);
    
    // Major, Minor, Patch 순서로 비교
    for (int i = 0; i < 3; i++) {
      if (v1Parts[i] < v2Parts[i]) return -1;
      if (v1Parts[i] > v2Parts[i]) return 1;
    }
    
    return 0; // 동일한 버전
  }
  
  /// 캐시 초기화 (앱 재시작 시 새로 체크하도록)
  void clearCache() {
    _cachedResult = null;
  }
}

/// 버전 체크 결과
class VersionCheckResult {
  final String currentVersion;
  final String latestVersion;
  final String? minimumVersion;
  final bool isUpdateAvailable;
  final bool isForceUpdate;
  final String? updateMessage;
  
  VersionCheckResult({
    required this.currentVersion,
    required this.latestVersion,
    this.minimumVersion,
    required this.isUpdateAvailable,
    required this.isForceUpdate,
    this.updateMessage,
  });
  
  /// 업데이트 상태 텍스트
  String get statusText {
    if (isForceUpdate) {
      return '업데이트 필요';
    } else if (isUpdateAvailable) {
      return '업데이트 가능';
    } else {
      return '최신 버전';
    }
  }
  
  /// 업데이트 상태 색상
  Color get statusColor {
    if (isForceUpdate) {
      return const Color(0xFFEF5350); // 빨강 (강제 업데이트)
    } else if (isUpdateAvailable) {
      return const Color(0xFFFF9800); // 주황 (선택적 업데이트)
    } else {
      return const Color(0xFF66BB6A); // 초록 (최신 버전)
    }
  }
  
  /// 업데이트 상태 아이콘
  IconData get statusIcon {
    if (isForceUpdate) {
      return Icons.warning;
    } else if (isUpdateAvailable) {
      return Icons.info;
    } else {
      return Icons.check_circle;
    }
  }
}
