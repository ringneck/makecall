import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../utils/account_management_utils.dart';
import '../cached_network_image_widget.dart';
import '../safe_circle_avatar.dart';

/// 👤 프로필 헤더 섹션
/// 
/// 기능:
/// - 프로필 사진 (클릭 시 상세 정보)
/// - 조직명 표시
/// - 이메일 표시
/// - 로그아웃 버튼
/// 
/// 독립적인 StatelessWidget으로 구현:
/// - Provider를 통해 AuthService 접근
/// - AccountManagementUtils로 프로필 상세/로그아웃 처리
/// - 그라데이션 배경과 그림자 효과
/// - 부모 위젯과의 결합도 최소화
class ProfileHeaderSection extends StatelessWidget {
  const ProfileHeaderSection({super.key});

  /// 소셜 로그인 제공자에 따른 배경색 반환
  Color _getSocialProviderColor(String provider) {
    switch (provider) {
      case 'google':
        return const Color(0xFFF5F5F5); // 구글 회색
      case 'kakao':
        return const Color(0xFFFEE500); // 카카오 노란색
      case 'apple':
        return Colors.black; // 애플 검정색
      default:
        return Colors.grey;
    }
  }

  /// 소셜 로그인 제공자에 따른 아이콘 반환
  Widget _getSocialProviderIcon(String provider) {
    switch (provider) {
      case 'google':
        return Image.asset(
          'assets/images/social/google_logo.png',
          width: 12,
          height: 12,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.g_mobiledata,
              color: Color(0xFF4285F4),
              size: 12,
            );
          },
        );
      case 'kakao':
        return Image.asset(
          'assets/images/social/kakao_talk_logo.png',
          width: 12,
          height: 12,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.chat_bubble,
              color: Colors.black87,
              size: 10,
            );
          },
        );
      case 'apple':
        return const Icon(
          Icons.apple,
          color: Colors.white,
          size: 12,
        );
      default:
        return const Icon(
          Icons.person,
          color: Colors.white,
          size: 12,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final userModel = authService.currentUserModel;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 프로필 아바타 (그림자 효과 + 소셜 로그인 배지)
          InkWell(
            onTap: () => AccountManagementUtils.showProfileDetailDialog(context, authService),
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SafeCircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    imageUrl: userModel?.profileImageUrl,
                  ),
                ),
                // 소셜 로그인 배지
                if (userModel?.loginProvider != null && 
                    ['google', 'kakao', 'apple'].contains(userModel!.loginProvider))
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getSocialProviderColor(userModel.loginProvider!),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _getSocialProviderIcon(userModel.loginProvider!),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // 조직명 + 이메일
          Expanded(
            child: InkWell(
              onTap: () => AccountManagementUtils.showProfileDetailDialog(context, authService),
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 조직명
                  if (userModel?.companyName != null && userModel!.companyName!.isNotEmpty)
                    Text(
                      userModel.companyName!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  // 이메일
                  Text(
                    userModel?.email ?? '이메일 없음',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // 로그아웃 아이콘 (흰색)
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => AccountManagementUtils.handleLogoutFromList(context),
              icon: const Icon(Icons.logout_rounded),
              color: Colors.white,
              tooltip: '로그아웃',
              iconSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}
