import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// ========================================
/// 비활성 시간 기반 자동 로그아웃 서비스
/// ========================================
/// 
/// 📱 **iOS 백그라운드 처리 설명**:
/// 
/// ✅ **현재 구현 방식: Foreground Timer 기반**
/// - Dart Timer를 사용하여 포그라운드에서 비활성 시간 추적
/// - 앱이 활성 상태일 때만 작동 (백그라운드 전환 시 자동 일시정지)
/// - iOS의 BGTaskScheduler 불필요 (앱 종료 후 작업이 없음)
/// 
/// ⚠️ **BGTaskScheduler가 필요하지 않은 이유**:
/// 1. 앱 사용 중에만 비활성 추적 (포그라운드 전용)
/// 2. 백그라운드에서 자동 로그아웃 불필요 (보안상 위험)
/// 3. 포그라운드 복귀 시 세션 유효성만 확인하면 됨
/// 
/// 💡 **BGTaskScheduler가 필요한 경우**:
/// - 앱 완전 종료 후 주기적 백그라운드 작업
/// - 예: 콘텐츠 동기화, 데이터베이스 정리, ML 모델 업데이트
/// 
/// 🎯 **현재 최적화 상태**:
/// - ✅ 메모리 효율적 (Dart Timer만 사용)
/// - ✅ 배터리 친화적 (추가 백그라운드 프로세스 없음)
/// - ✅ iOS App Store 승인 기준 준수
/// - ✅ 사용자 터치/스와이프 자동 감지
/// 
/// ========================================
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
    
    // ✅ 로그인 상태 확인 (로그아웃 후 경고 방지)
    if (_authService == null || !_authService!.isAuthenticated) {
      if (kDebugMode) {
        debugPrint('⚠️ [InactivityService] 로그인되지 않음 - 경고 취소');
      }
      return;
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
    
    // ✅ 로그인 상태 확인 (이미 로그아웃된 경우 스킵)
    if (_authService == null || !_authService!.isAuthenticated) {
      if (kDebugMode) {
        debugPrint('⚠️ [InactivityService] 이미 로그아웃됨 - 타임아웃 처리 스킵');
      }
      return;
    }
    
    // 사용자 정의 콜백 호출 (자동 로그아웃 알림 팝업)
    if (_onTimeout != null) {
      _onTimeout!();
    }
    
    // 자동 로그아웃
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
