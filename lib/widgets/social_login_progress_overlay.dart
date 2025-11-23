import 'dart:async';

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
  static void show(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) {
    if (kDebugMode) {
      debugPrint('🔄 [OVERLAY] Showing: $message');
    }
    
    // 기존 오버레이 즉시 제거
    _currentOverlay?.remove();
    _currentOverlay = null;

    if (kDebugMode) {
      debugPrint('✅ [OVERLAY] Creating new overlay: $message');
    }

    // 새 오버레이 즉시 생성 및 삽입
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

  /// 오버레이 숨기기 (이벤트 기반 - 마이크로태스크 큐 사용)
  static void hide() {
    if (kDebugMode) {
      debugPrint('❌ [OVERLAY] Scheduling hide via microtask');
    }
    
    // 오버레이가 없으면 즉시 종료
    if (_currentOverlay == null) {
      if (kDebugMode) {
        debugPrint('ℹ️  [OVERLAY] No overlay to hide');
      }
      return;
    }
    
    // Microtask를 사용해 현재 실행 스택이 완료된 직후 오버레이 제거
    // WidgetsBinding.addPostFrameCallback보다 빠르고 확실하게 실행됨
    // 앱 라이프사이클 변경이나 다이얼로그 표시와 무관하게 동작
    scheduleMicrotask(() {
      if (kDebugMode) {
        debugPrint('✅ [OVERLAY] Executing hide via microtask');
      }
      try {
        _currentOverlay?.remove();
        _currentOverlay = null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [OVERLAY] Error during hide (expected if context disposed): $e');
        }
        _currentOverlay = null;
      }
    });
  }
  
  /// 강제 오버레이 제거 (화면 전환 시 안전장치)
  static void forceHide() {
    if (kDebugMode) {
      debugPrint('🚨 [OVERLAY] Force hiding overlay (safety net)');
    }
    try {
      _currentOverlay?.remove();
      _currentOverlay = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [OVERLAY] Force hide error (expected during navigation): $e');
      }
    }
  }

  /// 진행 상황 업데이트 (기존 오버레이를 새 것으로 즉시 교체)
  static void update(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) {
    if (kDebugMode) {
      debugPrint('🔄 [OVERLAY] Updating to: $message');
    }
    
    // 즉시 교체
    show(
      context,
      message: message,
      subMessage: subMessage,
      progress: progress,
    );
  }
}
