import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../config/kakao_config.dart';

/// 소셜 로그인 버튼 위젯 (공식 디자인 가이드 준수)
/// 
/// 플랫폼별 소셜 로그인 버튼 제공:
/// - 웹 플랫폼: Kakao + Google + Apple (3개)
/// - iOS 플랫폼: Kakao + Google + Apple (3개)
/// - Android 플랫폼: Kakao + Google + Apple (3개)
/// 
/// 각 소셜 플랫폼의 공식 디자인 가이드라인을 준수하여
/// 유통되는 공식 이미지와 동일한 스타일로 구현
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    
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
        Column(
          children: [
            // 카카오 로그인 버튼 (웹에서도 표시)
            if (kIsWeb ? KakaoConfig.isWebLoginEnabled : true)
              _buildKakaoLoginButton(context, screenWidth, isDark),
            
            if (kIsWeb ? KakaoConfig.isWebLoginEnabled : true)
              const SizedBox(height: 12),
            
            // 구글 로그인 버튼
            _buildGoogleLoginButton(context, screenWidth, isDark),
            
            const SizedBox(height: 12),
            
            // 애플 로그인 버튼
            _buildAppleLoginButton(context, screenWidth, isDark),
          ],
        ),
      ],
    );
  }

  /// 카카오 로그인 버튼 (공식 디자인)
  Widget _buildKakaoLoginButton(BuildContext context, double screenWidth, bool isDark) {
    final buttonWidth = screenWidth > 600 ? 300.0 : screenWidth * 0.8;
    
    return SizedBox(
      width: buttonWidth,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onKakaoPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFEE500), // 카카오 공식 노란색
          foregroundColor: Colors.black87,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 카카오 로고
            Image.asset(
              'assets/images/social/kakao_logo.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chat_bubble,
                    color: Color(0xFFFEE500),
                    size: 16,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            const Text(
              '카카오 로그인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 구글 로그인 버튼 (공식 디자인)
  Widget _buildGoogleLoginButton(BuildContext context, double screenWidth, bool isDark) {
    final buttonWidth = screenWidth > 600 ? 300.0 : screenWidth * 0.8;
    
    return SizedBox(
      width: buttonWidth,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onGooglePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.grey[850] : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
          side: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 구글 로고
            Image.asset(
              'assets/images/social/google_logo.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(
                    Icons.g_mobiledata,
                    color: Color(0xFF4285F4),
                    size: 20,
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            Text(
              'Google 로그인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 애플 로그인 버튼 (공식 디자인)
  Widget _buildAppleLoginButton(BuildContext context, double screenWidth, bool isDark) {
    final buttonWidth = screenWidth > 600 ? 300.0 : screenWidth * 0.8;
    
    return SizedBox(
      width: buttonWidth,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onApplePressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 애플 로고
            Icon(
              Icons.apple,
              color: isDark ? Colors.black : Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(
              'Apple로 로그인',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
