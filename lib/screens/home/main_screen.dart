import 'package:flutter/material.dart';
import 'home_tab.dart';
import '../call/call_tab.dart';
import '../profile/profile_tab.dart';
import '../settings/settings_tab.dart';

class MainScreen extends StatefulWidget {
  final int initialTab; // 초기 탭 인덱스 (0: 홈, 1: 통화, 2: 단말, 3: 설정)
  
  const MainScreen({super.key, this.initialTab = 1});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  void _changeTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab; // 전달된 초기 탭으로 설정
    _tabs = [
      HomeTab(onNavigateToProfile: () => _changeTab(2)),
      const CallTab(),
      const ProfileTab(),
      const SettingsTab(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF2196F3),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.phone),
            label: '통화',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '단말',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}
