// 조건부 import: 웹과 모바일 플랫폼 분리
import 'platform_user_agent_stub.dart'
    if (dart.library.html) 'platform_user_agent_web.dart'
    if (dart.library.io) 'platform_user_agent_mobile.dart';

/// 플랫폼에 독립적인 User-Agent 접근 인터페이스
class PlatformUserAgent {
  /// 현재 플랫폼의 User-Agent 문자열을 반환
  /// - 웹: 브라우저의 실제 User-Agent
  /// - 모바일/데스크톱: 플랫폼 식별 문자열
  static String getUserAgent() {
    return getUserAgentImpl();
  }
}
