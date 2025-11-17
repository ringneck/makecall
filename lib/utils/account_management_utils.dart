import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/account_manager_service.dart';
import '../models/saved_account_model.dart';
import '../utils/dialog_utils.dart';
import '../utils/profile_image_utils.dart';
import '../widgets/cached_network_image_widget.dart';
import '../widgets/safe_circle_avatar.dart';
import '../main.dart' show navigatorKey;

/// 🔐 계정 관리 유틸리티 클래스
/// 
/// 기능:
/// - 프로필 상세 정보 다이얼로그
/// - 조직명 편집 다이얼로그
/// - 계정 삭제 (로그인하지 않은 계정만)
/// - 로그아웃 처리 (단일/목록)
/// 
/// 정적 메서드로 구성되어 어디서든 사용 가능
class AccountManagementUtils {
  AccountManagementUtils._(); // Private constructor (정적 클래스)

  /// 📋 프로필 상세 정보 다이얼로그
  static void showProfileDetailDialog(BuildContext context, AuthService authService) {
    final userModel = authService.currentUserModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 헤더
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '프로필 상세 정보',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[200] : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.grey[400] : Colors.black54,
                      ),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 프로필 이미지 (편집 가능)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        ProfileImageUtils.showImageOptions(context, authService);
                      },
                      child: SafeCircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.transparent,
                        imageUrl: userModel?.profileImageUrl,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          ProfileImageUtils.showImageOptions(context, authService);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blue[700] : const Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.grey[800]! : Colors.white, 
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // 조직명
                _buildDetailRow(
                  context: context,
                  icon: Icons.business,
                  label: '조직명',
                  value: userModel?.companyName?.isNotEmpty == true 
                      ? userModel!.companyName!
                      : '미설정',
                  onEdit: () {
                    Navigator.pop(context);
                    showEditCompanyNameDialog(context, authService);
                  },
                ),
                
                const Divider(height: 24),
                
                // 이메일
                _buildDetailRow(
                  context: context,
                  icon: Icons.email,
                  label: '이메일',
                  value: userModel?.email ?? '미설정',
                ),
                
                const Divider(height: 24),
                
                // UID
                _buildDetailRow(
                  context: context,
                  icon: Icons.fingerprint,
                  label: 'UID',
                  value: userModel?.uid ?? '미설정',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🏢 조직명 편집 다이얼로그
  static Future<void> showEditCompanyNameDialog(BuildContext context, AuthService authService) async {
    final currentCompanyName = authService.currentUserModel?.companyName ?? '';
    final controller = TextEditingController(text: currentCompanyName);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('조직명 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '계정: ${authService.currentUserModel?.email ?? ""}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '조직명',
                hintText: '예: 본사, 지사, 개인 등',
                border: OutlineInputBorder(),
                helperText: '소속된 조직 이름입니다',
              ),
              maxLength: 50,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (currentCompanyName.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.pop(context, ''), // 빈 문자열로 삭제
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('삭제'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
            child: const Text('확인'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      try {
        // Firestore 업데이트
        await authService.updateCompanyName(result.isEmpty ? null : result);
        
        if (context.mounted) {
          await DialogUtils.showSuccess(
            context,
            result.isEmpty 
                ? '조직명이 삭제되었습니다' 
                : '조직명이 업데이트되었습니다',
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (context.mounted) {
          await DialogUtils.showError(context, '오류 발생: $e');
        }
      }
    }
  }

  /// 🗑️ 등록된 계정 삭제 (로그인하지 않은 계정만)
  static Future<void> handleDeleteAccount(BuildContext context, SavedAccountModel account) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 현재 로그인된 계정인지 다시 확인 (안전장치)
    if (account.isCurrentAccount) {
      await DialogUtils.showError(
        context,
        '현재 로그인된 계정은 삭제할 수 없습니다.\n먼저 로그아웃해주세요.',
      );
      return;
    }
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.warning_rounded, 
              color: isDark ? Colors.orange[300] : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '계정 삭제 확인',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        Icons.email, 
                        size: 16,
                        color: isDark ? Colors.orange[300] : Colors.orange[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          account.email,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.orange[300] : Colors.orange[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (account.companyName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.business, 
                          size: 16,
                          color: isDark ? Colors.orange[300] : Colors.orange[700],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          account.companyName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.orange[400] : Colors.orange[800],
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
              '이 계정 정보를 삭제하시겠습니까?',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline, 
                        size: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '안내',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• 저장된 계정 정보만 삭제됩니다\n'
                    '• Firebase 계정 자체는 삭제되지 않습니다\n'
                    '• 삭제 후 다시 로그인할 수 있습니다',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.red[700] : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await AccountManagerService().removeAccount(account.uid);
        
        if (context.mounted) {
          await DialogUtils.showSuccess(
            context,
            '계정이 삭제되었습니다',
            duration: const Duration(seconds: 2),
          );
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ 계정 삭제 오류: $e');
        }
        
        if (context.mounted) {
          await DialogUtils.showError(
            context,
            '계정 삭제 실패: $e',
          );
        }
      }
    }
  }

  /// 🚪 로그아웃 (목록에서)
  static Future<void> handleLogoutFromList(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.logout_rounded, 
              color: isDark ? Colors.orange[300] : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              '로그아웃',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[200] : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          '로그아웃 하시겠습니까?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              '취소',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.orange[700] : Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await handleLogout(context);
    }
  }

  /// 🚪 로그아웃 처리
  static Future<void> handleLogout(BuildContext context) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 로그아웃 시작...');
      }

      // Drawer 닫기
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // 🔧 CRITICAL FIX: AuthService.signOut()을 호출하여 FCM 토큰 비활성화 수행
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();

      if (kDebugMode) {
        debugPrint('✅ 로그아웃 완료');
      }

      // 🔥 CRITICAL: AuthService.signOut()이 자동으로 로그인 화면으로 이동
      // 여기서 명시적으로 navigate하지 않아도 AuthService가 처리함
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 로그아웃 오류: $e');
      }

      // 🔥 CRITICAL: context가 dispose된 경우를 대비하여 전역 navigator key 사용
      final globalContext = navigatorKey.currentContext;
      if (globalContext != null && globalContext.mounted) {
        await DialogUtils.showError(
          globalContext,
          '로그아웃 실패: $e',
        );
      }
    }
  }

  /// 🔧 상세 정보 행 빌더 (내부 헬퍼 메서드)
  static Widget _buildDetailRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon, 
          size: 20, 
          color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            icon: Icon(
              Icons.edit_rounded,
              size: 18,
              color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
            ),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: '편집',
          ),
      ],
    );
  }
}
