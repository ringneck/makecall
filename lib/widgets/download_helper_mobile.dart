// 모바일 플랫폼용 다운로드 헬퍼 (stub 구현)

/// 모바일 플랫폼에서는 다운로드 기능 미지원
/// 웹 플랫폼에서만 사용 가능
void downloadFile(String url, String filename) {
  // 모바일에서는 아무 동작도 하지 않음
  // 필요시 share 패키지나 다른 방법으로 구현 가능
  throw UnsupportedError('다운로드는 웹 플랫폼에서만 지원됩니다.');
}
