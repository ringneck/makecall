/// 카카오 SDK 설정
/// 
/// 카카오 로그인을 사용하기 위한 API 키 설정
/// 
/// 🔑 API 키 발급 방법:
/// 1. 카카오 개발자 콘솔 접속: https://developers.kakao.com
/// 2. 내 애플리케이션 선택
/// 3. 앱 설정 > 앱 키 메뉴
/// 4. Native App Key와 JavaScript 키 복사
/// 
/// ⚠️ 보안 주의사항:
/// - 이 파일을 Git에 커밋하지 마세요 (.gitignore에 추가 권장)
/// - 실제 배포 시에는 환경 변수 또는 secure storage 사용 권장
class KakaoConfig {
  /// 카카오 Native App Key
  /// 
  /// - Android/iOS 네이티브 앱에서 사용
  /// - 필수 설정
  /// 
  /// 발급 위치: 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 설정 > 앱 키 > Native 앱 키
  static const String nativeAppKey = '737f26c4d0d81077b35b8f0313ec3536';
  
  /// 카카오 JavaScript Key
  /// 
  /// - 웹 플랫폼에서 카카오 로그인 사용 시 필요
  /// - 선택 설정 (웹 로그인 사용하지 않으면 불필요)
  /// 
  /// 발급 위치: 카카오 개발자 콘솔 > 내 애플리케이션 > 앱 설정 > 앱 키 > JavaScript 키
  /// 
  /// 🔧 웹 로그인 활성화 방법:
  /// 1. 카카오 개발자 콘솔에서 JavaScript 키 복사
  /// 2. 아래 'YOUR_KAKAO_JAVASCRIPT_KEY'를 실제 키로 교체
  /// 3. 웹 플랫폼 도메인 등록:
  ///    - 카카오 개발자 콘솔 > 내 애플리케이션 > 플랫폼 > Web
  ///    - 사이트 도메인 추가 (예: https://makecallio.web.app)
  static const String javaScriptAppKey = 'de5d0c0b8b89bad57d4f60cc5ac70a7a'; // 웹 로그인 활성화됨
  
  /// 웹 플랫폼 카카오 로그인 활성화 여부
  /// 
  /// - true: JavaScript 키가 설정되어 웹에서 카카오 로그인 가능
  /// - false: JavaScript 키 미설정, 웹에서 카카오 로그인 비활성화
  static bool get isWebLoginEnabled {
    final notPlaceholder = javaScriptAppKey != 'YOUR_KAKAO_JAVASCRIPT_KEY';
    final notEmpty = javaScriptAppKey.isNotEmpty;
    return notPlaceholder && notEmpty;
  }
  
  /// 카카오 로그인 Redirect URI (선택사항)
  /// 
  /// 웹 플랫폼에서 카카오 로그인 후 리다이렉트될 URI
  /// 카카오 개발자 콘솔에 등록된 Redirect URI와 일치해야 함
  static const String redirectUri = 'https://makecallio.web.app/auth/callback';
  
  /// 설정 검증
  /// 
  /// 카카오 SDK 초기화 전 설정이 올바른지 검증
  static bool validateConfig() {
    // 디버그: 검증 과정 로그
    final isEmpty = nativeAppKey.isEmpty;
    final isPlaceholder = nativeAppKey == 'YOUR_KAKAO_NATIVE_KEY';
    final actualKey = nativeAppKey;
    
    if (isEmpty || isPlaceholder) {
      return false;
    }
    return true;
  }
  
  /// 설정 정보 출력 (디버깅용)
  static String getConfigInfo() {
    return '''
카카오 SDK 설정 정보:
- Native App Key: ${nativeAppKey.substring(0, 10)}...
- JavaScript Key: ${isWebLoginEnabled ? '설정됨 (${javaScriptAppKey.substring(0, 10)}...)' : '미설정 (웹 로그인 비활성화)'}
- 웹 로그인 가능: ${isWebLoginEnabled ? '✅' : '❌'}
- Redirect URI: $redirectUri
''';
  }
}
