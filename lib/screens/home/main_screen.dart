import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../call/call_tab.dart';
import '../../services/fcm_service.dart';

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
  @override
  void initState() {
    super.initState();
    
    // 🔔 FCM BuildContext 설정 (기기 승인 다이얼로그용)
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
    // CallTab이 신규 사용자 감지 및 ProfileDrawer 자동 열기를 처리
    return CallTab(
      autoOpenProfileForNewUser: true,
      initialTabIndex: widget.initialTabIndex, // FCM에서 지정한 탭으로 이동
      showWelcomeDialog: widget.showWelcomeDialog, // 회원가입 완료 다이얼로그 플래그 전달
    );
  }
}
