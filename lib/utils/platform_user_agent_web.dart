import 'dart:html' as html;

/// 웹 플랫폼 User-Agent 구현
String getUserAgentImpl() {
  return html.window.navigator.userAgent;
}
