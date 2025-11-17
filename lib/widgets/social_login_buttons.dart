import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// 소셜 로그인 버튼 위젯
/// 
/// 4가지 소셜 로그인 버튼을 제공:
/// - Google (모든 플랫폼)
/// - Kakao (모든 플랫폼)
/// - Naver (모든 플랫폼)
/// - Apple (iOS 전용)
class SocialLoginButtons extends StatelessWidget {
  final Function()? onGooglePressed;
  final Function()? onKakaoPressed;
  final Function()? onNaverPressed;
  final Function()? onApplePressed;
  final bool isLoading;

  const SocialLoginButtons({
    super.key,
    this.onGooglePressed,
    this.onKakaoPressed,
    this.onNaverPressed,
    this.onApplePressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // 구분선
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '간편 로그인',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                thickness: 1,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // 소셜 로그인 버튼들 (2x2 그리드)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 구글 로그인
            _buildSocialButton(
              context: context,
              onPressed: isLoading ? null : onGooglePressed,
              backgroundColor: Colors.white,
              icon: _buildGoogleIcon(),
              label: 'Google',
              isDark: isDark,
            ),
            
            // 카카오 로그인
            _buildSocialButton(
              context: context,
              onPressed: isLoading ? null : onKakaoPressed,
              backgroundColor: const Color(0xFFFEE500),
              icon: _buildKakaoIcon(),
              label: 'Kakao',
              isDark: isDark,
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 네이버 로그인
            _buildSocialButton(
              context: context,
              onPressed: isLoading ? null : onNaverPressed,
              backgroundColor: const Color(0xFF03C75A),
              icon: _buildNaverIcon(),
              label: 'Naver',
              isDark: isDark,
            ),
            
            // 애플 로그인 (iOS만)
            if (!kIsWeb && Platform.isIOS)
              _buildSocialButton(
                context: context,
                onPressed: isLoading ? null : onApplePressed,
                backgroundColor: Colors.black,
                icon: const Icon(
                  Icons.apple,
                  color: Colors.white,
                  size: 28,
                ),
                label: 'Apple',
                isDark: isDark,
              )
            else
              // iOS가 아닌 경우 빈 공간
              _buildEmptySpace(),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required Function()? onPressed,
    required Color backgroundColor,
    required Widget icon,
    required String label,
    required bool isDark,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon,
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: backgroundColor == Colors.white || backgroundColor == const Color(0xFFFEE500)
                          ? Colors.black87
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptySpace() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Container(
          height: 56,
        ),
      ),
    );
  }

  Widget _buildGoogleIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          ),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildKakaoIcon() {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(
        Icons.chat_bubble,
        color: Color(0xFFFEE500),
        size: 16,
      ),
    );
  }

  Widget _buildNaverIcon() {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Text(
          'N',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF03C75A),
          ),
        ),
      ),
    );
  }
}
