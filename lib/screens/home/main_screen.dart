import 'package:flutter/material.dart';
import '../call/call_tab.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  Widget build(BuildContext context) {
    // CallTab이 신규 사용자 감지 및 ProfileDrawer 자동 열기를 처리
    return const CallTab(autoOpenProfileForNewUser: true);
  }
}
