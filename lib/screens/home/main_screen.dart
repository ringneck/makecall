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
    
    // 🎨 UX 개선: 소셜 로그인 오버레이 제거 (MainScreen 렌더링 완료 후)
    // 빈 화면이 보이는 것을 방지하기 위해 여기서 제거
    // 🔒 중복 실행 방지: 플래그로 첫 실행만 허용
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasRemovedOverlay) {
        _hasRemovedOverlay = true;
        
        // 🔔 FCM BuildContext 설정 (기기 승인 다이얼로그용)
        FCMService.setContext(context);
        if (kDebugMode) {
          debugPrint('📺 [MainScreen] FCMService.setContext() 호출 완료');
        }
        
        // 🎨 소셜 로그인 오버레이 제거 (MainScreen 렌더링 완료)
        // ⚠️ 약간의 지연을 추가하여 UI가 완전히 렌더링되도록 보장
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            SocialLoginProgressHelper.hide();
            if (kDebugMode) {
              debugPrint('✅ [UX] MainScreen 렌더링 완료 - 소셜 로그인 오버레이 제거');
            }
          }
        });
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // CallTab이 신규 사용자 감지 및 ProfileDrawer 자동 열기를 처리
    return CallTab(
      autoOpenProfileForNewUser: true,
      initialTabIndex: widget.initialTabIndex, // FCM에서 지정한 탭으로 이동
      showWelcomeDialog: widget.showWelcomeDialog, // 회원가입 완료 다이얼로그 플래그 전달
    );
  }
}
