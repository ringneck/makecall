import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// 소셜 로그인 버튼 위젯
/// 
/// 4가지 소셜 로그인 버튼을 제공:
/// - Google (모든 플랫폼)
/// - Kakao (모든 플랫폼)
/// - Naver (모든 플랫폼)
/// - Apple (모든 플랫폼 - iOS에서만 실제 작동)
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
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 반응형 버튼 크기
    final buttonSize = screenWidth > 600 ? 70.0 : 64.0;
    final iconSize = screenWidth > 600 ? 32.0 : 28.0;
    
    return Column(
      children: [
        // "SNS 계정으로 로그인" 텍스트
        Text(
          'SNS 계정으로 로그인',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            letterSpacing: 0.3,
          ),
        ),
        
        const SizedBox(height: 8),
        
        // "연동했던 SNS 계정을 선택해 주세요." 텍스트
        Text(
          '연동했던 SNS 계정을 선택해 주세요.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            letterSpacing: 0.2,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // 소셜 로그인 버튼들 (1줄에 4개 - 아이콘만)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 네이버 로그인 (왼쪽부터)
            _buildIconButton(
              context: context,
              onPressed: isLoading ? null : onNaverPressed,
              backgroundColor: const Color(0xFF03C75A),
              icon: _buildNaverIcon(iconSize),
              size: buttonSize,
              isDark: isDark,
            ),
            
            SizedBox(width: screenWidth > 600 ? 20 : 16),
            
            // 카카오 로그인
            _buildIconButton(
              context: context,
              onPressed: isLoading ? null : onKakaoPressed,
              backgroundColor: const Color(0xFFFEE500),
              icon: _buildKakaoIcon(iconSize),
              size: buttonSize,
              isDark: isDark,
            ),
            
            SizedBox(width: screenWidth > 600 ? 20 : 16),
            
            // 구글 로그인
            _buildIconButton(
              context: context,
              onPressed: isLoading ? null : onGooglePressed,
              backgroundColor: isDark ? Colors.grey[850]! : Colors.white,
              icon: _buildGoogleIcon(iconSize),
              size: buttonSize,
              isDark: isDark,
              hasBorder: true,
            ),
            
            SizedBox(width: screenWidth > 600 ? 20 : 16),
            
            // 애플 로그인 (항상 표시)
            _buildIconButton(
              context: context,
              onPressed: isLoading ? null : onApplePressed,
              backgroundColor: isDark ? Colors.white : Colors.black,
              icon: Icon(
                Icons.apple,
                color: isDark ? Colors.black : Colors.white,
                size: iconSize,
              ),
              size: buttonSize,
              isDark: isDark,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIconButton({
    required BuildContext context,
    required Function()? onPressed,
    required Color backgroundColor,
    required Widget icon,
    required double size,
    required bool isDark,
    bool hasBorder = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: hasBorder
            ? Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          splashColor: Colors.white.withValues(alpha: 0.3),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Center(
            child: icon,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleIcon(double size) {
    return Container(
      width: size * 0.85,
      height: size * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            fontSize: size * 0.65,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF4285F4), // Google Blue
            height: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildKakaoIcon(double size) {
    return Container(
      width: size * 0.85,
      height: size * 0.85,
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Icon(
        Icons.chat_bubble,
        color: const Color(0xFFFEE500),
        size: size * 0.6,
      ),
    );
  }

  Widget _buildNaverIcon(double size) {
    return Container(
      width: size * 0.85,
      height: size * 0.85,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.15),
      ),
      child: Center(
        child: Text(
          'N',
          style: TextStyle(
            fontSize: size * 0.65,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF03C75A),
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
