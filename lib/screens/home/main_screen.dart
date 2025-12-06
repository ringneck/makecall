import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../call/call_tab.dart';
import '../auth/approval_waiting_screen.dart';
import '../auth/login_screen.dart';
import '../../services/fcm_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/social_login_progress_overlay.dart';

class MainScreen extends StatefulWidget {
  final int? initialTabIndex; // 초기 탭 인덱스 (null이면 기본값 사용)
  final bool showWelcomeDialog; // 회원가입 완료 다이얼로그 표시 여부
  
  const MainScreen({
    super.key, 
    this.initialTabIndex,
    this.showWelcomeDialog = false, // 기본값: false
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // 🎯 오버레이 제거 플래그: 이 인스턴스에서만 한 번만 제거
  bool _hasRemovedOverlay = false;
  
  // 🔑 CRITICAL: CallTab GlobalKey - rebuild 시 인스턴스 유지
  // - ValueKey는 rebuild 시 새 인스턴스 생성 → initState() 재호출
  // - GlobalKey는 같은 위젯 인스턴스 유지 → initState() 1번만 호출
  GlobalKey? _callTabKey;
  String? _currentUserId; // 현재 사용자 ID 추적 (사용자 변경 감지용)
  
  @override
  void initState() {
    super.initState();
    
    // 🔑 CRITICAL FIX: _currentUserId 초기화 제거
    // - initState()에서 authService.currentUser를 가져올 때 null일 수 있음
    // - 첫 build()에서 실제 userId와 비교 시 불일치 → GlobalKey 중복 생성
    // - 해결: _currentUserId를 null로 유지하고, 첫 build()에서만 GlobalKey 생성
    // - 이후 build()에서는 userId가 변경될 때만 새 GlobalKey 생성
    
    // 🔔 FCM BuildContext 설정 (기기 승인 다이얼로그용)
    // 이것은 즉시 실행 (context 필요)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FCMService.setContext(context);
        if (kDebugMode) {
          debugPrint('📺 [MainScreen] FCMService.setContext() 호출 완료');
        }
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // 🎨 UX 개선: 이벤트 기반 오버레이 제거
    // build() 시작 시점에 다음 프레임 paint 완료 후 실행 예약
    if (!_hasRemovedOverlay) {
      _hasRemovedOverlay = true;
      
      if (kDebugMode) {
        debugPrint('🎬 [UX] MainScreen build() 시작 - paint 완료 대기');
      }
      
      // 🔥 CRITICAL: SchedulerBinding을 사용하여 paint 완료 이벤트 감지
      // addPostFrameCallback: 현재 프레임의 build 완료 후 실행
      // 그 후 한 프레임 더 대기하여 paint까지 완전히 완료되도록 보장
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // 첫 번째 프레임: build 완료
        if (kDebugMode) {
          debugPrint('🎨 [UX] MainScreen 첫 프레임 build 완료 - paint 대기');
        }
        
        // 두 번째 프레임: paint 완료 보장
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (kDebugMode) {
              debugPrint('✅ [UX] MainScreen paint 완료 - 소셜 로그인 오버레이 강제 제거');
            }
            
            // 🔥 CRITICAL: context 기반 강제 제거로 모든 오버레이 제거
            SocialLoginProgressHelper.forceRemoveAll(context);
            
            if (kDebugMode) {
              debugPrint('✅ [UX] SocialLoginProgressHelper.forceRemoveAll() 호출 완료');
            }
          }
        });
      });
    }
    
    // 🔥 CRITICAL: Consumer<AuthService>로 승인 대기 상태 감지
    // MainScreen에서 직접 감지하여 ApprovalWaitingScreen 표시
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // 📋 디버그 로그: Consumer rebuild 감지
        if (kDebugMode) {
          debugPrint('🔄 [MainScreen] Consumer<AuthService> rebuild');
          debugPrint('   - isLoggingOut: ${authService.isLoggingOut}');
          debugPrint('   - isFcmInitializing: ${authService.isFcmInitializing}');
          debugPrint('   - isWaitingForApproval: ${authService.isWaitingForApproval}');
          debugPrint('   - approvalRequestId: ${authService.approvalRequestId}');
        }
        
        // 🚨 CRITICAL: 로그아웃 중이면 즉시 LoginScreen 반환
        // main.dart Consumer 재빌드 실패 시 보조 수단 - 직접 LoginScreen으로 전환
        if (authService.isLoggingOut) {
          if (kDebugMode) {
            debugPrint('🚪 [MainScreen] 로그아웃 중 감지 - LoginScreen 직접 반환');
            debugPrint('   → main.dart Consumer 재빌드 대기 중 fallback');
          }
          
          // 🔥 CRITICAL: 소셜 로그인 오버레이 강제 제거
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              SocialLoginProgressHelper.forceRemoveAll(context);
            }
          });
          
          return LoginScreen(
            key: ValueKey('login_logout_${DateTime.now().millisecondsSinceEpoch}'),
          );
        }
        
        // 🔄 CRITICAL: FCM 초기화 중이면 로딩 오버레이 표시
        // main.dart Consumer가 rebuild되지 않는 경우를 위한 fallback
        if (authService.isFcmInitializing) {
          if (kDebugMode) {
            debugPrint('⏳ [MainScreen] FCM 초기화 중 → "서비스 로딩중..." 오버레이 표시');
          }
          
          return Scaffold(
            body: Container(
              color: Colors.black.withOpacity(0.7),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                      const SizedBox(height: 20),
                      DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          decoration: TextDecoration.none,
                        ),
                        child: const Text('서비스 로딩중...'),
                      ),
                      const SizedBox(height: 8),
                      DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          decoration: TextDecoration.none,
                        ),
                        child: const Text('잠시만 기다려주세요'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
        
        // 🔒 기기 승인 대기 중이면 ApprovalWaitingScreen 표시
        if (authService.isWaitingForApproval) {
          final requestId = authService.approvalRequestId;
          final userId = authService.currentUser?.uid;
          
          // 필수 데이터 검증
          if (requestId == null || userId == null) {
            if (kDebugMode) {
              debugPrint('⚠️ [MainScreen] ApprovalWaitingScreen 표시 실패: 필수 데이터 누락');
              debugPrint('   - requestId: $requestId');
              debugPrint('   - userId: $userId');
            }
            // 데이터 누락 시 CallTab으로 fallback (에러 방지)
            return CallTab(
              key: ValueKey('call_tab_fallback'),
              autoOpenProfileForNewUser: true,
              initialTabIndex: widget.initialTabIndex,
              showWelcomeDialog: widget.showWelcomeDialog,
            );
          }
          
          if (kDebugMode) {
            debugPrint('📺 [MainScreen] ApprovalWaitingScreen 표시');
            debugPrint('   - requestId: $requestId');
            debugPrint('   - userId: $userId');
          }
          
          return ApprovalWaitingScreen(
            approvalRequestId: requestId,
            userId: userId,
          );
        }
        
        // 정상 로그인: CallTab 표시
        // CallTab이 신규 사용자 감지 및 ProfileDrawer 자동 열기를 처리
        // 공지사항 및 설정 체크도 CallTab에서 처리
        // 
        // 🔑 CRITICAL: GlobalKey 사용으로 rebuild 시 위젯 인스턴스 유지
        // - 로그인된 사용자의 UID를 기준으로 GlobalKey 생성/재사용
        // - 같은 사용자 → 같은 GlobalKey → 위젯 인스턴스 유지 → initState() 1번만
        // - 다른 사용자 → 새 GlobalKey → 위젯 재생성 → initState() 호출
        final userId = authService.currentUser?.uid ?? 'guest';
        
        // 사용자가 변경되면 새로운 GlobalKey 생성
        if (_currentUserId != userId) {
          _currentUserId = userId;
          _callTabKey = GlobalKey(debugLabel: 'call_tab_$userId');
          
          if (kDebugMode) {
            debugPrint('🔑 [MainScreen] CallTab GlobalKey 생성 (사용자 변경)');
            debugPrint('   - New User ID: $userId');
          }
        } else if (kDebugMode) {
          debugPrint('🔑 [MainScreen] CallTab GlobalKey 재사용 (같은 사용자)');
          debugPrint('   - User ID: $userId');
        }
        
        return CallTab(
          key: _callTabKey, // 🔑 GlobalKey로 위젯 인스턴스 유지
          autoOpenProfileForNewUser: true,
          initialTabIndex: widget.initialTabIndex, // FCM에서 지정한 탭으로 이동
          showWelcomeDialog: widget.showWelcomeDialog, // 회원가입 완료 다이얼로그 플래그 전달
        );
      },
    );
  }
}
