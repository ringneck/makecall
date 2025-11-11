import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// 비활성 시간 기반 자동 로그아웃 서비스
/// 
/// 사용자 활동을 추적하고 일정 시간 동안 활동이 없으면 자동으로 로그아웃합니다.
/// - 기본 타임아웃: 30분
/// - 경고 타임아웃: 25분 (5분 전 경고)
class InactivityService {
  static final InactivityService _instance = InactivityService._internal();
  factory InactivityService() => _instance;
  InactivityService._internal();

  // 설정
  static const Duration _inactivityTimeout = Duration(minutes: 30);
  static const Duration _warningTimeout = Duration(minutes: 25);
  
  // 타이머
  Timer? _inactivityTimer;
  Timer? _warningTimer;
  
  // 마지막 활동 시간
  DateTime _lastActivityTime = DateTime.now();
  
  // AuthService 참조
  AuthService? _authService;
  
  // 경고 콜백
  VoidCallback? _onWarning;
  VoidCallback? _onTimeout;
  
  /// 서비스 초기화
  void initialize({
    required AuthService authService,
    VoidCallback? onWarning,
    VoidCallback? onTimeout,
  }) {
    _authService = authService;
    _onWarning = onWarning;
    _onTimeout = onTimeout;
    
    if (kDebugMode) {
      debugPrint('🔒 [InactivityService] 초기화 완료');
      debugPrint('   - 타임아웃: ${_inactivityTimeout.inMinutes}분');
      debugPrint('   - 경고: ${_warningTimeout.inMinutes}분');
    }
    
    // 초기 타이머 시작
    _resetTimers();
  }
  
  /// 사용자 활동 감지 시 호출
  void updateActivity() {
    _lastActivityTime = DateTime.now();
    _resetTimers();
    
    if (kDebugMode) {
      debugPrint('👆 [InactivityService] 사용자 활동 감지 - 타이머 리셋');
    }
  }
  
  /// 타이머 리셋
  void _resetTimers() {
    // 기존 타이머 취소
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    
    // 경고 타이머 시작 (25분 후)
    _warningTimer = Timer(_warningTimeout, _handleWarning);
    
    // 자동 로그아웃 타이머 시작 (30분 후)
    _inactivityTimer = Timer(_inactivityTimeout, _handleTimeout);
  }
  
  /// 경고 처리 (5분 전)
  void _handleWarning() {
    if (kDebugMode) {
      debugPrint('⚠️ [InactivityService] 비활성 경고 - 5분 후 자동 로그아웃');
    }
    
    if (_onWarning != null) {
      _onWarning!();
    }
  }
  
  /// 타임아웃 처리 (자동 로그아웃)
  void _handleTimeout() async {
    if (kDebugMode) {
      debugPrint('🔒 [InactivityService] 비활성 타임아웃 - 자동 로그아웃 실행');
    }
    
    // 사용자 정의 콜백 호출
    if (_onTimeout != null) {
      _onTimeout!();
    }
    
    // 자동 로그아웃
    if (_authService != null && _authService!.isAuthenticated) {
      try {
        await _authService!.signOut();
        
        if (kDebugMode) {
          debugPrint('✅ [InactivityService] 자동 로그아웃 완료');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ [InactivityService] 자동 로그아웃 실패: $e');
        }
      }
    }
  }
  
  /// 서비스 정지
  void pause() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    
    if (kDebugMode) {
      debugPrint('⏸️ [InactivityService] 일시 정지');
    }
  }
  
  /// 서비스 재개
  void resume() {
    _resetTimers();
    
    if (kDebugMode) {
      debugPrint('▶️ [InactivityService] 재개');
    }
  }
  
  /// 서비스 종료
  void dispose() {
    _inactivityTimer?.cancel();
    _warningTimer?.cancel();
    _authService = null;
    _onWarning = null;
    _onTimeout = null;
    
    if (kDebugMode) {
      debugPrint('🗑️ [InactivityService] 종료');
    }
  }
  
  /// 남은 시간 가져오기
  Duration get remainingTime {
    final elapsed = DateTime.now().difference(_lastActivityTime);
    final remaining = _inactivityTimeout - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  /// 활성 상태 확인
  bool get isActive => _inactivityTimer != null && _inactivityTimer!.isActive;
}
