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
      color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
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
  
  // 🔥 CRITICAL: 모든 오버레이를 추적하기 위한 List
  static final List<OverlayEntry> _allOverlays = [];

  /// 진행 상황 오버레이 표시
  static void show(
    BuildContext context, {
    required String message,
    String? subMessage,
    double? progress,
  }) {
    // 기존 오버레이 즉시 제거
    _currentOverlay?.remove();
    _currentOverlay = null;

    // 새 오버레이 즉시 생성 및 삽입
    _currentOverlay = OverlayEntry(
      builder: (context) => SocialLoginProgressOverlay(
        message: message,
        subMessage: subMessage,
        progress: progress,
      ),
    );

    // 🔥 CRITICAL: rootOverlay 사용하여 화면 전환과 무관하게 오버레이 유지
    Overlay.of(context, rootOverlay: true).insert(_currentOverlay!);
    
    // 🔥 NEW: List에도 추가하여 모든 오버레이 추적
    _allOverlays.add(_currentOverlay!);
    
    if (kDebugMode) {
      debugPrint('📌 [OVERLAY] show() 완료 - rootOverlay에 삽입: $message');
      debugPrint('   현재 총 오버레이 개수: ${_allOverlays.length}');
    }
  }

  /// 오버레이 숨기기 (즉시 제거)
  static void hide() {
    if (_currentOverlay == null) return;
    
    try {
      _currentOverlay?.remove();
      _currentOverlay = null;
    } catch (e) {
      _currentOverlay = null;
    }
  }
  
  /// 강제 오버레이 제거 (화면 전환 시 안전장치)
  static void forceHide() {
    try {
      _currentOverlay?.remove();
      _currentOverlay = null;
      if (kDebugMode) {
        debugPrint('✅ [OVERLAY] forceHide() 완료 - _currentOverlay 제거됨');
      }
    } catch (e) {
      _currentOverlay = null;
      if (kDebugMode) {
        debugPrint('⚠️ [OVERLAY] forceHide() 예외 발생: $e');
      }
    }
  }
  
  /// 모든 오버레이 제거 (context 기반 강제 제거)
  static void forceRemoveAll(BuildContext context) {
    try {
      if (kDebugMode) {
        debugPrint('🧹 [OVERLAY] forceRemoveAll() 시작');
        debugPrint('   제거할 오버레이 개수: ${_allOverlays.length}');
      }
      
      // 1. List에 있는 모든 오버레이를 명시적으로 제거
      for (final entry in _allOverlays) {
        try {
          entry.remove();
          if (kDebugMode) {
            debugPrint('🗑️ [OVERLAY] List에서 오버레이 제거 완료');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [OVERLAY] List 오버레이 제거 실패: $e');
          }
        }
      }
      _allOverlays.clear();
      
      // 2. _currentOverlay도 제거 (중복 제거 시도하지만 안전장치)
      if (_currentOverlay != null) {
        try {
          _currentOverlay?.remove();
          if (kDebugMode) {
            debugPrint('🗑️ [OVERLAY] _currentOverlay 제거 완료');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ [OVERLAY] _currentOverlay 제거 실패 (이미 제거됨): $e');
          }
        }
        _currentOverlay = null;
      }
      
      // 3. rootOverlay 전체 rebuild
      try {
        final overlay = Overlay.of(context, rootOverlay: true);
        
        if (overlay.mounted) {
          overlay.setState(() {
            // 빈 setState - 제거된 entry들이 화면에서 사라지도록
          });
          
          if (kDebugMode) {
            debugPrint('🔄 [OVERLAY] rootOverlay setState() 호출 - 전체 rebuild');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ [OVERLAY] rootOverlay 접근 실패: $e');
        }
      }
      
      if (kDebugMode) {
        debugPrint('✅ [OVERLAY] forceRemoveAll() 완료 - 모든 오버레이 제거 완료');
      }
    } catch (e) {
      _currentOverlay = null;
      _allOverlays.clear();
      if (kDebugMode) {
        debugPrint('⚠️ [OVERLAY] forceRemoveAll() 예외 발생: $e');
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
      debugPrint('🔄 [OVERLAY] update() 호출: $message');
    }
    
    // 즉시 교체 (rootOverlay 사용)
    show(
      context,
      message: message,
      subMessage: subMessage,
      progress: progress,
    );
  }
}
