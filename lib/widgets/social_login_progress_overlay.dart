import 'package:flutter/material.dart';

/// 소셜 로그인 진행 상황 오버레이
/// 
/// 소셜 로그인 진행 중 사용자에게 단계별 진행 상황을 표시합니다.
class SocialLoginProgressOverlay extends StatelessWidget {
  final String message;
  final String? subMessage;
  final double? progress; // 0.0 ~ 1.0 (null이면 무한 로딩)

  const SocialLoginProgressOverlay({
    super.key,
    required this.message,
    this.subMessage,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      color: (isDark ? Colors.black : Colors.white).withOpacity(0.9),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 로딩 인디케이터
              if (progress == null)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // 메인 메시지
              Text(
                message,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              // 서브 메시지
              if (subMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  subMessage!,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 소셜 로그인 진행 상황 표시 헬퍼
class SocialLoginProgressHelper {
  static OverlayEntry? _currentOverlay;

  /// 진행 상황 오버레이 표시
  static void show(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) {
    hide(); // 기존 오버레이 제거

    _currentOverlay = OverlayEntry(
      builder: (context) => SocialLoginProgressOverlay(
        message: message,
        subMessage: subMessage,
        progress: progress,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }

  /// 오버레이 숨기기
  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// 진행 상황 업데이트
  static void update(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) {
    hide();
    show(
      context,
      message: message,
      subMessage: subMessage,
      progress: progress,
    );
  }
}
