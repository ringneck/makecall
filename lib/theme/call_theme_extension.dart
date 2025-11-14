import 'package:flutter/material.dart';

/// 🎨 통화 관련 테마 색상 헬퍼 클래스
/// 
/// 최근통화 탭 및 통화 관련 UI의 색상을 테마 기반으로 통일성 있게 관리
/// 라이트/다크 모드를 자동으로 지원합니다.
class CallThemeColors {
  final bool isDark;
  
  CallThemeColors(BuildContext context) 
      : isDark = Theme.of(context).brightness == Brightness.dark;

  /// 📞 수신 통화 색상 (초록색)
  Color get incomingCallColor => isDark 
      ? Colors.green[300]! 
      : Colors.green;
  
  /// 📞 수신 통화 배경색
  Color get incomingCallBackgroundColor => isDark
      ? Colors.green[900]!.withAlpha(77)
      : Colors.green.withValues(alpha: 0.1);
  
  /// 📞 발신 통화 색상 (파란색)
  Color get outgoingCallColor => isDark 
      ? Colors.blue[300]! 
      : Colors.blue;
  
  /// 📞 발신 통화 배경색
  Color get outgoingCallBackgroundColor => isDark
      ? Colors.blue[900]!.withAlpha(77)
      : Colors.blue.withValues(alpha: 0.1);
  
  /// 📞 부재중 통화 색상 (빨간색)
  Color get missedCallColor => isDark 
      ? Colors.red[300]! 
      : Colors.red;
  
  /// 📞 부재중 통화 배경색
  Color get missedCallBackgroundColor => isDark
      ? Colors.red[900]!.withAlpha(77)
      : Colors.red.withValues(alpha: 0.1);
  
  /// 🔄 착신전환 활성화 색상 (주황색)
  Color get forwardedCallColor => isDark 
      ? Colors.orange[300]! 
      : Colors.orange[700]!;
  
  /// 🔄 착신전환 배경색
  Color get forwardedCallBackgroundColor => isDark
      ? Colors.orange[900]!.withAlpha(77)
      : Colors.orange.withValues(alpha: 0.1);
  
  /// 🔄 착신전환 테두리 색상
  Color get forwardedCallBorderColor => isDark
      ? Colors.orange[700]!
      : Colors.orange.withValues(alpha: 0.3);
  
  /// 📱 단말수신 색상 (초록색)
  Color get deviceAnsweredColor => isDark
      ? Colors.green[300]!
      : Colors.green[700]!;
  
  /// 📱 단말수신 배경색
  Color get deviceAnsweredBackgroundColor => isDark
      ? Colors.green[900]!.withAlpha(77)
      : Colors.green.withValues(alpha: 0.1);
  
  /// 🔔 알림확인 색상 (파란색)
  Color get confirmedCallColor => isDark
      ? Colors.blue[300]!
      : Colors.blue[700]!;
  
  /// 🔔 알림확인 배경색
  Color get confirmedCallBackgroundColor => isDark
      ? Colors.blue[900]!.withAlpha(77)
      : Colors.blue.withValues(alpha: 0.1);
  
  /// 👤 연락처 추가 버튼 색상
  Color get addContactButtonColor => isDark
      ? Colors.green[300]!
      : Colors.green[700]!;
  
  /// 👤 연락처 추가 버튼 배경색
  Color get addContactButtonBackgroundColor => isDark
      ? Colors.green[900]!.withAlpha(77)
      : Colors.green.withValues(alpha: 0.1);
  
  /// 📞 전화 걸기 버튼 Gradient 색상 (시작)
  Color get callButtonGradientStart => const Color(0xFF2196F3).withValues(alpha: 0.8);
  
  /// 📞 전화 걸기 버튼 Gradient 색상 (끝)
  Color get callButtonGradientEnd => const Color(0xFF2196F3);
  
  /// 📞 전화 걸기 버튼 그림자 색상
  Color get callButtonShadowColor => const Color(0xFF2196F3).withValues(alpha: 0.3);
  
  /// 🎨 기본 배지 색상 (파란색)
  Color get defaultBadgeColor => isDark
      ? Colors.blue[300]!
      : Colors.blue[700]!;
  
  /// 🎨 기본 배지 배경색
  Color get defaultBadgeBackgroundColor => isDark
      ? Colors.blue[900]!.withAlpha(77)
      : Colors.blue.withValues(alpha: 0.1);
  
  /// ⚠️ 폴백 테두리 색상 (statusColor가 null일 때)
  Color get fallbackBorderColor => isDark
      ? Colors.grey[600]!
      : Colors.grey;
}
