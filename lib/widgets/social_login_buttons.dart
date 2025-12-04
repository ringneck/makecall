import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../config/kakao_config.dart';

/// 소셜 로그인 버튼 위젯 (로고만 표시)
/// 
/// 플랫폼별 소셜 로그인 버튼 제공:
/// - 웹 플랫폼: Kakao + Google (Apple은 WebView sessionStorage 제한으로 미지원)
/// - iOS 플랫폼: Kakao + Google + Apple (3개)
/// - Android 플랫폼: Kakao + Google (Apple은 WebView sessionStorage 문제로 비활성화)
/// 
/// 각 소셜 플랫폼의 공식 로고만 표시 (텍스트 없음)
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 카카오 로그인 (웹에서도 표시)
            if (kIsWeb ? KakaoConfig.isWebLoginEnabled : true)
              _buildKakaoLoginButton(context, screenWidth, isDark),
            
            if (kIsWeb ? KakaoConfig.isWebLoginEnabled : true)
              const SizedBox(width: 16),
            
            // 구글 로그인
            _buildGoogleLoginButton(context, screenWidth, isDark),
            
            // 애플 로그인 (iOS 전용 - Android는 WebView sessionStorage 문제로 비활성화)
            if (!kIsWeb && Platform.isIOS) ...[
              const SizedBox(width: 16),
              _buildAppleLoginButton(context, screenWidth, isDark),
            ],
          ],
        ),
      ],
    );
  }

  /// 카카오 로그인 버튼 (로고만)
  Widget _buildKakaoLoginButton(BuildContext context, double screenWidth, bool isDark) {
    final buttonSize = screenWidth > 600 ? 64.0 : 56.0;
    
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: const Color(0xFFFEE500), // 카카오 공식 노란색
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () {
            // 키보드 내리기
            FocusScope.of(context).unfocus();
            onKakaoPressed?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Image.asset(
              'assets/images/social/kakao_talk_logo.png',
              width: buttonSize * 0.75,
              height: buttonSize * 0.75,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: buttonSize * 0.75,
                  height: buttonSize * 0.75,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(buttonSize * 0.3),
                  ),
                  child: Icon(
                    Icons.chat_bubble,
                    color: const Color(0xFFFEE500),
                    size: buttonSize * 0.4,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 구글 로그인 버튼 (로고만)
  Widget _buildGoogleLoginButton(BuildContext context, double screenWidth, bool isDark) {
    final buttonSize = screenWidth > 600 ? 64.0 : 56.0;
    
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF424242) : const Color(0xFFF5F5F5), // 보색 대비 좋은 회색
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () {
            // 키보드 내리기
            FocusScope.of(context).unfocus();
            onGooglePressed?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Image.asset(
              'assets/images/social/google_logo.png',
              width: buttonSize * 0.7,
              height: buttonSize * 0.7,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: buttonSize * 0.6,
                  height: buttonSize * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(buttonSize * 0.3),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Icon(
                    Icons.g_mobiledata,
                    color: const Color(0xFF4285F4),
                    size: buttonSize * 0.5,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// 애플 로그인 버튼 (로고만)
  Widget _buildAppleLoginButton(BuildContext context, double screenWidth, bool isDark) {
    final buttonSize = screenWidth > 600 ? 64.0 : 56.0;
    
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        color: isDark ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : () {
            // 키보드 내리기
            FocusScope.of(context).unfocus();
            onApplePressed?.call();
          },
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Icon(
              Icons.apple,
              color: isDark ? Colors.black : Colors.white,
              size: buttonSize * 0.65,
            ),
          ),
        ),
      ),
    );
  }
}
