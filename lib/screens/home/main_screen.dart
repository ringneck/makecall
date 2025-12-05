import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../call/call_tab.dart';
import '../../services/fcm_service.dart';
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
              debugPrint('✅ [UX] MainScreen paint 완료 - 소셜 로그인 오버레이 제거');
            }
            
            SocialLoginProgressHelper.hide();
          }
        });
      });
    }
    
    // CallTab이 신규 사용자 감지 및 ProfileDrawer 자동 열기를 처리
    return CallTab(
      autoOpenProfileForNewUser: true,
      initialTabIndex: widget.initialTabIndex, // FCM에서 지정한 탭으로 이동
      showWelcomeDialog: widget.showWelcomeDialog, // 회원가입 완료 다이얼로그 플래그 전달
    );
  }
}
