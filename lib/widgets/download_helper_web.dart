// 웹 플랫폼용 다운로드 헬퍼
import 'dart:html' as html;

/// 웹 플랫폼에서 파일 다운로드
void downloadFile(String url, String filename) {
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..setAttribute('target', '_blank');
  
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
}
