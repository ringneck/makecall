import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as permission_handler;

import '../../../services/mobile_contacts_service.dart';

/// 🔧 PermissionHandler Service
/// 
/// **책임 (Single Responsibility)**:
/// - 연락처 권한 확인 및 요청 로직 처리
/// - 권한 요청 다이얼로그 표시
/// - 권한 거부 시 설정 화면 안내
/// - 권한 상태 관리 및 검증
/// 
/// **설계 패턴**:
/// - Service Pattern: 비즈니스 로직 캡슐화
/// - Dependency Injection: MobileContactsService 주입
/// - Context-aware: 다이얼로그 표시를 위한 BuildContext 필요
/// - Early Return Pattern: 빠른 검증 실패 처리
/// 
/// **사용 예시**:
/// ```dart
/// // 초기화
/// _permissionHandler = PermissionHandler(
///   mobileContactsService: _mobileContactsService,
/// );
/// 
/// // 권한 확인 및 요청
/// final hasPermission = await _permissionHandler.checkAndRequestPermission(context);
/// if (hasPermission) {
///   // 연락처 가져오기
/// }
/// ```
class PermissionHandler {
  final MobileContactsService mobileContactsService;
  
  PermissionHandler({
    required this.mobileContactsService,
  });
  
  /// 🔐 연락처 권한 확인 및 요청 (통합 메서드)
  /// 
  /// **기능**: 연락처 권한 상태 확인 및 필요 시 권한 요청 처리
  /// - 권한이 이미 있는 경우: true 반환
  /// - 권한이 없는 경우: 사용자에게 권한 요청 다이얼로그 표시
  /// - 권한 허용: true 반환
  /// - 권한 거부: 설정 화면 안내 다이얼로그 표시 후 false 반환
  /// 
  /// **고급 패턴**:
  /// - Early Return: 이미 권한이 있으면 즉시 반환
  /// - User Consent: 시스템 다이얼로그 전에 사용자 의사 확인
  /// - Settings Redirect: 권한 거부 시 설정 화면으로 안내
  /// 
  /// **Returns**: 권한 허용 여부 (true: 허용됨, false: 거부됨)
  Future<bool> checkAndRequestPermission(BuildContext context) async {
    try {
      // 🎯 STEP 1: 현재 권한 상태 확인
      final hasPermission = await mobileContactsService.hasContactsPermission();
      
      if (kDebugMode) {
        debugPrint('🔍 PermissionHandler: hasPermission = $hasPermission');
      }
      
      // 🔒 Early Return: 권한이 이미 있으면 즉시 반환
      if (hasPermission) {
        return true;
      }
      
      if (kDebugMode) {
        debugPrint('⚠️ PermissionHandler: 권한 없음 - 사용자에게 권한 요청');
      }
      
      if (!context.mounted) return false;
      
      // 🎯 STEP 2: 사용자에게 권한 요청 의사 확인
      final shouldRequest = await showPermissionRequestDialog(context);
      if (shouldRequest != true) {
        if (kDebugMode) {
          debugPrint('❌ PermissionHandler: 사용자가 권한 요청 취소');
        }
        return false;
      }
      
      // 🎯 STEP 3: 시스템 권한 다이얼로그 표시
      final permissionStatus = await mobileContactsService.requestContactsPermission();
      
      if (kDebugMode) {
        debugPrint('📱 PermissionHandler: requestContactsPermission 결과');
        debugPrint('   - permissionStatus: $permissionStatus');
        debugPrint('   - isGranted: ${permissionStatus.isGranted}');
      }
      
      // 🎯 STEP 4: 권한 거부 시 설정 화면 안내
      if (!permissionStatus.isGranted) {
        if (kDebugMode) {
          debugPrint('❌ PermissionHandler: 권한 거부됨');
        }
        
        if (context.mounted) {
          showPermissionDeniedDialog(context);
        }
        return false;
      }
      
      if (kDebugMode) {
        debugPrint('✅ PermissionHandler: 권한 허용됨');
      }
      
      return true;
      
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PermissionHandler: 권한 확인 오류: $e');
      }
      return false;
    }
  }
  
  /// 📱 권한 요청 다이얼로그 표시 (초기 요청)
  /// 
  /// **기능**: 사용자에게 연락처 권한 요청 의사 확인
  /// - 권한이 필요한 이유 설명
  /// - 다음 단계 안내 (시스템 다이얼로그에서 "허용" 선택)
  /// 
  /// **Returns**: 사용자 선택 (true: 권한 요청, false/null: 취소)
  Future<bool?> showPermissionRequestDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.contacts,
                color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('연락처 권한 필요')),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '장치 연락처를 불러오려면 연락처 접근 권한이 필요합니다.',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 12),
              Text(
                '다음 화면에서 "허용"을 선택해주세요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
              ),
              child: const Text('권한 요청'),
            ),
          ],
        );
      },
    );
  }
  
  /// ⚠️ 권한 거부 다이얼로그 표시 (설정으로 이동)
  /// 
  /// **기능**: 권한 거부 시 설정 화면으로 이동 안내
  /// - 권한이 거부된 이유 설명
  /// - 설정에서 권한을 허용하는 방법 안내
  /// - "설정 열기" 버튼으로 앱 설정 화면 바로가기
  void showPermissionDeniedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? Colors.orange[300] : Colors.orange,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('연락처 권한 거부됨')),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '연락처 권한이 거부되었습니다.',
                style: TextStyle(fontSize: 15),
              ),
              SizedBox(height: 12),
              Text(
                '장치 연락처를 사용하려면 설정에서 권한을 허용해주세요.',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                // permission_handler의 openAppSettings 사용
                await permission_handler.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.orange[700] : Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('설정 열기'),
            ),
          ],
        );
      },
    );
  }
}
