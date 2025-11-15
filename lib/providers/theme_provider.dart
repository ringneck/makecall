import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎨 테마 모드 관리 Provider
/// 
/// 전역 테마 설정을 관리하며, 모든 계정이 동일한 테마를 공유합니다.
/// SharedPreferences를 사용하여 사용자의 테마 선택을 영구적으로 저장합니다.
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  /// 앱 시작 시 저장된 테마 모드 로드
  Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey) ?? 'system';
      _themeMode = _parseThemeMode(savedTheme);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ 테마 로드 실패: $e');
    }
  }
  
  /// 테마 모드 변경 및 저장
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.name);
      _themeMode = mode;
      notifyListeners();
      debugPrint('✅ 테마 변경: ${mode.name}');
    } catch (e) {
      debugPrint('❌ 테마 저장 실패: $e');
    }
  }
  
  /// String을 ThemeMode로 변환
  ThemeMode _parseThemeMode(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }
  
  /// 현재 테마가 라이트 모드인지 확인 (디버그용)
  bool get isLightMode => _themeMode == ThemeMode.light;
  
  /// 현재 테마가 다크 모드인지 확인 (디버그용)
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  /// 현재 테마가 시스템 모드인지 확인 (디버그용)
  bool get isSystemMode => _themeMode == ThemeMode.system;
  
  /// 테마 모드 표시명 가져오기
  String get themeModeDisplayName {
    switch (_themeMode) {
      case ThemeMode.light:
        return '라이트 모드';
      case ThemeMode.dark:
        return '다크 모드';
      case ThemeMode.system:
        return '시스템 설정';
    }
  }
}
