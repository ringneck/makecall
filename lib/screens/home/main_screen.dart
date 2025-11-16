import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../call/call_tab.dart';

class MainScreen extends StatefulWidget {
  final int? initialTabIndex; // 초기 탭 인덱스 (null이면 기본값 사용)
  
  const MainScreen({super.key, this.initialTabIndex});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      debugPrint('🚨 [MainScreen] initState 호출됨!');
      debugPrint('   initialTabIndex: ${widget.initialTabIndex}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('🚨 [MainScreen] build 호출됨!');
    }
    
    // CallTab이 신규 사용자 감지 및 ProfileDrawer 자동 열기를 처리
    return CallTab(
      autoOpenProfileForNewUser: true,
      initialTabIndex: widget.initialTabIndex, // FCM에서 지정한 탭으로 이동
    );
  }
}
