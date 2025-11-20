import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// 소셜 로그인 버튼 위젯
/// 
/// 플랫폼별 소셜 로그인 버튼 제공:
/// - 웹 플랫폼: Kakao, Google, Apple (3개)
/// - iOS 플랫폼: Kakao, Google, Apple (3개)
/// - Android 플랫폼: Kakao, Google, Apple (3개 - Apple 웹뷰 지원)
class SocialLoginButtons extends StatelessWidget {
  final Function()? onGooglePressed;
  final Function()? onKakaoPressed;
  final Function()? onApplePressed;
  final bool isLoading;

  const SocialLoginButtons({
    super.key,
    this.onGooglePressed,
    this.onKakaoPressed,
    this.onApplePressed,
    this.isLoading = false,
  });

  /// 플랫폼별 소셜 로그인 버튼 생성
  List<Widget> _buildPlatformSpecificButtons(
    BuildContext context,
    double buttonSize,
    double iconSize,
    bool isDark,
    double screenWidth,
  ) {
    final spacing = SizedBox(width: screenWidth > 600 ? 20 : 16);
    
    if (kIsWeb) {
      // 🌐 웹 플랫폼: Kakao + Google + Apple (3개)
      return [
        _buildIconButton(
          context: context,
          onPressed: isLoading ? null : onKakaoPressed,
          backgroundColor: const Color(0xFFFEE500),
          icon: _buildKakaoIcon(iconSize),
          size: buttonSize,
          isDark: isDark,
        ),
        spacing,
        _buildIconButton(
          context: context,
          onPressed: isLoading ? null : onGooglePressed,
          backgroundColor: isDark ? Colors.grey[850]! : Colors.white,
          icon: _buildGoogleIcon(iconSize),
          size: buttonSize,
          isDark: isDark,
          hasBorder: true,
        ),
        spacing,
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
      ];
    } else {
      // 📱 모바일 플랫폼
      final bool isIOS = !kIsWeb && Platform.isIOS;
      
      if (isIOS) {
        // iOS: Kakao + Google + Apple (3개)
        return [
          _buildIconButton(
            context: context,
            onPressed: isLoading ? null : onKakaoPressed,
            backgroundColor: const Color(0xFFFEE500),
            icon: _buildKakaoIcon(iconSize),
            size: buttonSize,
            isDark: isDark,
          ),
          spacing,
          _buildIconButton(
            context: context,
            onPressed: isLoading ? null : onGooglePressed,
            backgroundColor: isDark ? Colors.grey[850]! : Colors.white,
            icon: _buildGoogleIcon(iconSize),
            size: buttonSize,
            isDark: isDark,
            hasBorder: true,
          ),
          spacing,
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
        ];
      } else {
        // Android: Kakao + Google + Apple (3개 - Apple 복원)
        return [
          _buildIconButton(
            context: context,
            onPressed: isLoading ? null : onKakaoPressed,
            backgroundColor: const Color(0xFFFEE500),
            icon: _buildKakaoIcon(iconSize),
            size: buttonSize,
            isDark: isDark,
          ),
          spacing,
          _buildIconButton(
            context: context,
            onPressed: isLoading ? null : onGooglePressed,
            backgroundColor: isDark ? Colors.grey[850]! : Colors.white,
            icon: _buildGoogleIcon(iconSize),
            size: buttonSize,
            isDark: isDark,
            hasBorder: true,
          ),
          spacing,
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
        ];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    
    final buttonSize = screenWidth > 600 ? 70.0 : 64.0;
    final iconSize = screenWidth > 600 ? 32.0 : 28.0;
    
    return Column(
      children: [
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
        Text(
          '연동했던 SNS 계정을 선택해 주세요.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _buildPlatformSpecificButtons(
            context,
            buttonSize,
            iconSize,
            isDark,
            screenWidth,
          ),
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
    // Google 로고 이미지 사용
    return ClipOval(
      child: Image.asset(
        'assets/images/social/google_logo.png',
        width: size * 0.65,
        height: size * 0.65,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 이미지 로드 실패 시 폴백 아이콘
          return Icon(
            Icons.g_mobiledata,
            size: size * 0.7,
            color: const Color(0xFF4285F4),
          );
        },
      ),
    );
  }

  Widget _buildKakaoIcon(double size) {
    // 카카오 로고 이미지 사용
    return ClipOval(
      child: Image.asset(
        'assets/images/social/kakao_logo.png',
        width: size * 0.65,
        height: size * 0.65,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // 이미지 로드 실패 시 폴백 아이콘
          return Icon(
            Icons.chat_bubble,
            size: size * 0.6,
            color: Colors.black87,
          );
        },
      ),
    );
  }
}
