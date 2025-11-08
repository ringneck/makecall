// 모바일 플랫폼용 다운로드 헬퍼 (iOS/Android 구현)
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;

/// 모바일 플랫폼에서 파일을 다운로드하고 공유/저장
/// 
/// iOS에서는:
/// - 파일을 다운로드하여 임시 디렉토리에 저장
/// - iOS 네이티브 Share Sheet를 통해 사용자가 저장 위치 선택
/// - "파일로 저장" 옵션을 통해 사용자의 파일 앱에 저장 가능
/// 
/// Android에서는:
/// - 파일을 다운로드하여 임시 디렉토리에 저장
/// - Android Share Intent를 통해 공유/저장
Future<void> downloadFile(String url, String filename) async {
  try {
    // 1. HTTP GET 요청으로 파일 다운로드
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode != 200) {
      throw Exception('파일 다운로드 실패: HTTP ${response.statusCode}');
    }
    
    // 2. 임시 디렉토리 가져오기
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$filename';
    
    // 3. 파일 저장
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    
    // 4. 네이티브 Share Sheet로 공유 (iOS/Android 자동 처리)
    // iOS: Share Sheet에서 "파일로 저장" 옵션으로 저장 가능
    // Android: 공유 또는 다운로드 폴더로 저장 가능
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      text: '녹음 파일: $filename',
      subject: '통화 녹음',
    );
    
    // 5. 공유 완료 후 임시 파일 정리는 시스템이 자동으로 처리
    // (사용자가 저장을 완료한 후에 정리됨)
    
  } catch (e) {
    // 에러 발생 시 상위로 전파
    throw Exception('파일 다운로드 중 오류 발생: $e');
  }
}
