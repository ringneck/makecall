import 'dart:io';

/// 모바일/데스크톱 플랫폼 User-Agent 구현
String getUserAgentImpl() {
  // 모바일 플랫폼에서는 운영체제 정보 반환
  if (Platform.isIOS) {
    return 'iOS Mobile App';
  } else if (Platform.isAndroid) {
    return 'Android Mobile App';
  } else if (Platform.isMacOS) {
    return 'macOS Desktop App';
  } else if (Platform.isWindows) {
    return 'Windows Desktop App';
  } else if (Platform.isLinux) {
    return 'Linux Desktop App';
  }
  return 'Unknown Platform';
}
