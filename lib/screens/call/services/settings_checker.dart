import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../profile/api_settings_dialog.dart';

/// 설정 확인 및 안내 서비스
/// 
/// 신규 사용자의 필수 설정 상태를 확인하고 설정이 필요한 경우 안내 다이얼로그를 표시합니다.
/// - API 설정 확인 (apiBaseUrl, companyId, appKey)
/// - 단말번호 등록 확인
/// - 초기 등록 안내 다이얼로그
class SettingsChecker {
  final AuthService authService;
  final DatabaseService databaseService;
  final GlobalKey<ScaffoldState> scaffoldKey;
  
  bool _hasCheckedSettings = false;
  
  // 🔒 CRITICAL: 다이얼로그 중복 표시 방지를 위한 static 플래그
  static bool _isDialogShowing = false;

  SettingsChecker({
    required this.authService,
    required this.databaseService,
    required this.scaffoldKey,
  });

  /// 설정 체크 완료 여부
  bool get hasCheckedSettings => _hasCheckedSettings;

  /// 설정 체크 완료 상태 설정
  set hasCheckedSettings(bool value) => _hasCheckedSettings = value;

  /// 🎯 설정 상태 확인 및 안내 다이얼로그 표시
  /// 
  /// **핵심 기능**: 신규 사용자의 필수 설정 완료 여부 확인
  /// - REST API 설정 (apiBaseUrl, companyId, appKey)
  /// - 단말번호 등록
  /// 
  /// **최적화 전략**:
  /// - Idempotent: _hasCheckedSettings 플래그로 중복 실행 방지
  /// - Lazy Loading: userModel 로드 전에는 실행하지 않음
  /// - Static Flag: _isDialogShowing으로 다이얼로그 중복 표시 완전 차단
  Future<void> checkAndShowGuide(BuildContext context) async {
    // 🔒 CRITICAL: 다이얼로그가 이미 표시 중이면 즉시 리턴 (중복 방지)
    if (_isDialogShowing) {
      if (kDebugMode) debugPrint('⏭️ 설정 안내 다이얼로그 이미 표시 중 - 중복 실행 방지');
      return;
    }
    
    // 🔒 중복 실행 방지
    if (_hasCheckedSettings) {
      if (kDebugMode) debugPrint('✅ 설정 체크 이미 완료됨');
      return;
    }

    // 🔒 Early Return: 인증 상태 검증
    if (authService.currentUser == null || !authService.isAuthenticated) {
      return;
    }

    // 🔐 CRITICAL: 기기 승인 대기 중인 경우 초기 등록 팝업 표시 안 함
    if (authService.approvalRequestId != null) {
      if (kDebugMode) {
        debugPrint('⏭️ 기기 승인 대기 중 - 초기 등록 팝업 건너뛰기');
      }
      _hasCheckedSettings = true; // 승인 후 재실행 방지
      return;
    }

    // 🔐 CRITICAL: userModel 로드 완료까지 대기 (소셜 로그인 시 필수)
    int waitCount = 0;
    while (authService.currentUserModel == null && waitCount < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    final userModel = authService.currentUserModel;
    if (userModel == null) {
      if (kDebugMode) {
        debugPrint('⚠️ userModel 로드 실패 - 설정 체크 재시도 가능');
      }
      _hasCheckedSettings = false; // 재시도 가능하도록 플래그 리셋
      return;
    }

    // 🔐 CRITICAL: 소셜 로그인 진행 중인 경우 설정 체크 건너뛰기
    if (authService.isInSocialLoginFlow) {
      if (kDebugMode) {
        debugPrint('⏭️ 소셜 로그인 진행 중 - 초기 등록 팝업 건너뛰기');
      }
      return; // 플래그를 설정하지 않고 return (다음에 다시 체크 가능)
    }

    if (kDebugMode) {
      debugPrint('🔍 설정 상태 확인 시작...');
    }

    final userId = authService.currentUser?.uid ?? '';

    // 🔒 필수 설정 확인 (REST API만 체크)
    final hasApiSettings = (userModel.apiBaseUrl?.isNotEmpty ?? false) &&
        (userModel.companyId?.isNotEmpty ?? false) &&
        (userModel.appKey?.isNotEmpty ?? false);

    // 🔒 등록된 단말번호 확인
    final extensions = await databaseService.getMyExtensions(userId).first;
    final hasExtensions = extensions.isNotEmpty;

    if (kDebugMode) {
      debugPrint('✅ API 설정: $hasApiSettings');
      debugPrint('✅ 단말번호: $hasExtensions');
    }

    // 🔒 REST API 설정 완료 시 체크 종료
    if (hasApiSettings && hasExtensions) {
      _hasCheckedSettings = true;
      if (kDebugMode) debugPrint('✅ REST API 설정 완료');
      return;
    }

    // 🔒 REST API 설정 미완료 시 안내 다이얼로그
    if (!hasApiSettings) {
      _hasCheckedSettings = true; // 1회만 표시
      _isDialogShowing = true; // 다이얼로그 표시 중 플래그 설정

      if (context.mounted) {
        try {
          await _showApiSettingsDialog(context, userModel);
        } finally {
          _isDialogShowing = false; // 다이얼로그 닫힌 후 플래그 해제
        }
      } else {
        _isDialogShowing = false; // context가 없으면 플래그 해제
      }
      return;
    }

    // 🔒 단말번호 미등록 시 안내 다이얼로그
    if (!hasExtensions) {
      _hasCheckedSettings = true; // 1회만 표시
      _isDialogShowing = true; // 다이얼로그 표시 중 플래그 설정
      
      if (context.mounted) {
        try {
          await _showExtensionRegistrationDialog(context);
        } finally {
          _isDialogShowing = false; // 다이얼로그 닫힌 후 플래그 해제
        }
      } else {
        _isDialogShowing = false; // context가 없으면 플래그 해제
      }
    }
  }

  /// API 설정 안내 다이얼로그
  Future<void> _showApiSettingsDialog(BuildContext context, dynamic userModel) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('초기 등록 필요'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 계정 정보 표시
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[850] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.person,
                          size: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            userModel.email ?? '이메일 없음',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.grey[300] : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (userModel.organizationName != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.badge,
                            size: 16,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            userModel.organizationName!,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '클릭투콜 서비스를 이용하려면\nREST API 설정이 필요합니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.blue[900]!.withValues(alpha: 0.3)
                      : Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.blue[700]! : Colors.blue[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          size: 16,
                          color: isDark ? Colors.blue[300] : Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '설정 방법',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.blue[300] : Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. 왼쪽 상단 프로필 아이콘 클릭\n'
                      '2. REST API 정보 입력\n'
                      '3. 단말번호 조회 및 등록',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 다이얼로그가 완전히 닫힌 후 기본 API 설정 다이얼로그 표시
                await Future.delayed(const Duration(milliseconds: 300));

                if (dialogContext.mounted) {
                  // 현재 다이얼로그 닫기
                  Navigator.of(dialogContext).pop();
                  
                  // 기본 API 설정 다이얼로그 표시
                  await showDialog(
                    context: context,  // 원본 context 사용
                    barrierDismissible: false,
                    builder: (ctx) => const ApiSettingsDialog(),
                  );
                }
              },
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('설정하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 단말번호 등록 안내 다이얼로그
  Future<void> _showExtensionRegistrationDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.phone_disabled,
                color: isDark ? Colors.orange[300] : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('단말번호 등록 필요'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '클릭투콜 서비스를 이용하려면\n단말번호 등록이 필요합니다.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange[900]!.withValues(alpha: 0.3)
                      : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.orange[700]! : Colors.orange[200]!,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info,
                          size: 16,
                          color: isDark ? Colors.orange[300] : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '등록 방법',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.orange[300] : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. 왼쪽 상단 프로필 아이콘 클릭\n'
                      '2. 단말번호 조회 및 등록\n',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (!context.mounted) return;
                _hasCheckedSettings = true;
                Navigator.pop(dialogContext);
              },
              child: const Text('나중에'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 다이얼로그가 완전히 닫힌 후 ProfileDrawer 열기
                await Future.delayed(const Duration(milliseconds: 300));

                if (context.mounted && scaffoldKey.currentState != null) {
                  scaffoldKey.currentState!.openDrawer();
                }
              },
              icon: const Icon(Icons.phone_in_talk, size: 18),
              label: const Text('등록하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.orange[700] : Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
