import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import '../call/call_tab.dart';
import '../auth/approval_waiting_screen.dart';
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
  
  @override
  void initState() {
    super.initState();
    
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
          debugPrint('   - isFcmInitializing: ${authService.isFcmInitializing}');
          debugPrint('   - isWaitingForApproval: ${authService.isWaitingForApproval}');
          debugPrint('   - approvalRequestId: ${authService.approvalRequestId}');
        }
        
        // 🔄 CRITICAL: FCM 초기화 중이면 로딩 오버레이 표시
        // ⚠️ 승인 대기 체크보다 먼저 확인 (로딩 우선!)
        if (authService.isFcmInitializing) {
          if (kDebugMode) {
            debugPrint('🔄 [MainScreen] FCM 초기화 로딩 오버레이 표시');
          }
          
          // 🧹 소셜 로그인 오버레이 제거 (충돌 방지)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SocialLoginProgressHelper.forceHide();
          });
          
          // 🔥 EVENT-BASED: 오버레이 렌더링 완료 후 AuthService에 알림
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (kDebugMode) {
                debugPrint('✅ [MainScreen] "서비스 로딩중" 오버레이 렌더링 완료');
              }
              // AuthService에 오버레이 표시 완료 이벤트 발행
              authService.notifyFcmLoadingOverlayRendered();
            });
          });
          
          // Scaffold 위에 오버레이 표시 (빈 화면 + 로딩)
          return Scaffold(
            body: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        '서비스 로딩중...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '잠시만 기다려 주세요',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
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
        // 🔑 CRITICAL: ValueKey 사용으로 재로그인 시 CallTab 위젯 완전 재생성 보장
        // - 로그인된 사용자의 UID를 key로 사용
        // - 로그아웃 후 재로그인 시 다른 UID → CallTab 재생성 → initState() 호출
        // - 이를 통해 공지사항 및 설정 체크 플래그가 매 로그인마다 초기화됨
        final userId = authService.currentUser?.uid ?? 'guest';
        final callTabKey = 'call_tab_$userId';
        
        if (kDebugMode) {
          debugPrint('🔑 [MainScreen] CallTab key 생성: $callTabKey');
          debugPrint('   - User ID: $userId');
        }
        
        return CallTab(
          key: ValueKey(callTabKey), // 🔑 사용자별 고유 키
          autoOpenProfileForNewUser: true,
          initialTabIndex: widget.initialTabIndex, // FCM에서 지정한 탭으로 이동
          showWelcomeDialog: widget.showWelcomeDialog, // 회원가입 완료 다이얼로그 플래그 전달
        );
      },
    );
  }
}
