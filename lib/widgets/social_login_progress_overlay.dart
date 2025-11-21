import 'package:flutter/foundation.dart';
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
      color: (isDark ? Colors.black : Colors.white).withOpacity(0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘과 로딩 인디케이터
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.blue[900]!.withAlpha(77)
                      : const Color(0xFF2196F3).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 로딩 인디케이터
                    if (progress == null)
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                        ),
                      )
                    else
                      SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2196F3)),
                        ),
                      ),
                    
                    // 중앙 아이콘
                    Icon(
                      Icons.sync,
                      size: 24,
                      color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 메인 메시지 (다이얼로그 타이틀 스타일)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              
              // 서브 메시지 (다이얼로그 컨텐츠 스타일)
              if (subMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subMessage!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                      height: 1.5,
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
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
  static Future<void> show(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) async {
    if (kDebugMode) {
      debugPrint('🔄 [OVERLAY] Showing: $message');
    }
    
    // 기존 오버레이가 있으면 먼저 제거
    if (_currentOverlay != null) {
      hide();
      // 오버레이가 완전히 제거될 때까지 대기
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (kDebugMode) {
      debugPrint('✅ [OVERLAY] Creating new overlay: $message');
    }

    _currentOverlay = OverlayEntry(
      builder: (context) => SocialLoginProgressOverlay(
        message: message,
        subMessage: subMessage,
        progress: progress,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
    
    if (kDebugMode) {
      debugPrint('✅ [OVERLAY] Overlay inserted: $message');
    }
  }

  /// 오버레이 숨기기
  static void hide() {
    if (kDebugMode) {
      debugPrint('❌ [OVERLAY] Hiding overlay');
    }
    _currentOverlay?.remove();
    _currentOverlay = null;
  }

  /// 진행 상황 업데이트 (기존 오버레이를 새 것으로 교체)
  static Future<void> update(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) async {
    if (kDebugMode) {
      debugPrint('🔄 [OVERLAY] Updating to: $message');
    }
    
    hide();
    // 오버레이가 완전히 제거될 때까지 대기
    await Future.delayed(const Duration(milliseconds: 100));
    
    await show(
      context,
      message: message,
      subMessage: subMessage,
      progress: progress,
    );
  }
}
