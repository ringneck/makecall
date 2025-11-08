// 웹 플랫폼용 다운로드 헬퍼
import 'dart:html' as html;

/// 웹 플랫폼에서 파일 다운로드
Future<void> downloadFile(String url, String filename) async {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..setAttribute('target', '_blank');
  
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
