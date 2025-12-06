import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/auth_service.dart';
import '../../../services/database_service.dart';
import '../../../models/my_extension_model.dart';
import '../../../widgets/profile_drawer/extension_management_section.dart';
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
  
  /// 🔄 로그인 세션마다 플래그 리셋 (매 로그인 시 설정 재체크)
  void resetFlags() {
    _hasCheckedSettings = false;
    _isDialogShowing = false;
    if (kDebugMode) {
      debugPrint('🔄 [SettingsChecker] 플래그 리셋 완료 - 매 로그인마다 설정 체크');
    }
  }

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
    
    // 🔒 CRITICAL: 다이얼로그 표시 플래그를 체크 직후 바로 설정 (Race Condition 방지)
    _isDialogShowing = true;

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

    // 🔐 CRITICAL: userModel 로드 확인 (이벤트 기반)
    // ❌ 시간 기반 polling 제거: while + Future.delayed (불안정)
    // ✅ 이벤트 기반: currentUserModel 직접 체크 (안정적)
    final userModel = authService.currentUserModel;
    if (userModel == null) {
      if (kDebugMode) {
        debugPrint('⚠️ userModel 아직 로드 안 됨 - AuthService 리스너가 재호출할 것');
      }
      _hasCheckedSettings = false; // 재시도 가능하도록 플래그 리셋
      return;  // AuthService의 notifyListeners()가 다시 호출할 것
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
      _isDialogShowing = false; // 플래그 해제
      if (kDebugMode) debugPrint('✅ REST API 설정 완료');
      return;
    }

    // 🔒 REST API 설정 미완료 시 안내 다이얼로그
    if (!hasApiSettings) {
      _hasCheckedSettings = true; // 1회만 표시

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
      
      // 🚫 CRITICAL: MaxDeviceLimit 차단 중에는 다이얼로그 표시 안 함
      if (authService.isBlockedByMaxDeviceLimit) {
        if (kDebugMode) {
          debugPrint('⏭️ MaxDeviceLimit 차단 중 - 단말번호 등록 안내 건너뛰기');
        }
        _isDialogShowing = false;
        return;
      }
      
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
                '🎉 회원가입이 완료되었습니다!\n\n'
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
                // 🔥 CRITICAL FIX: Navigator.pop()을 1번만 호출!
                Navigator.pop(dialogContext);

                // 다이얼로그가 완전히 닫힌 후 기본 API 설정 다이얼로그 표시
                await Future.delayed(const Duration(milliseconds: 300));

                if (context.mounted) {
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
              child: const Text('닫기'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);

                // 다이얼로그가 완전히 닫힌 후 단말번호 관리 다이얼로그 직접 호출
                await Future.delayed(const Duration(milliseconds: 300));

                if (context.mounted) {
                  // ExtensionManagementSection의 static 메서드를 통해 단말번호 관리 다이얼로그 표시
                  await ExtensionManagementSection.showExtensionManagementDialog(context);
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
  
  /// 단말번호 입력 다이얼로그
  Future<void> _showExtensionInputDialog(BuildContext context) async {
    final extensionController = TextEditingController();
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.phone_in_talk,
                color: isDark ? Colors.orange[300] : Colors.orange,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text('단말번호 등록'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '사용할 단말번호를 입력하세요.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: extensionController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '단말번호',
                  hintText: '예: 1000',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final extension = extensionController.text.trim();
                if (extension.isEmpty) {
                  // 빈 값이면 그냥 리턴 (에러 표시 안 함)
                  return;
                }
                
                Navigator.pop(dialogContext);
                
                // 단말번호 저장
                try {
                  final userId = authService.currentUser?.uid;
                  if (userId != null) {
                    final myExtension = MyExtensionModel(
                      id: '',
                      userId: userId,
                      extensionId: '',  // 단말번호 등록 시점에는 extension_id가 없음
                      extension: extension,
                      name: '기본 단말번호',
                      classOfServicesId: '',  // 나중에 API 동기화 시 업데이트
                      createdAt: DateTime.now(),
                    );
                    
                    await databaseService.addMyExtension(myExtension);
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('단말번호가 등록되었습니다'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('단말번호 등록 실패: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('확인'),
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
