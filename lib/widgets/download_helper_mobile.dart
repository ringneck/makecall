// 모바일 플랫폼용 다운로드 헬퍼 (iOS/Android 구현)
import 'dart:io';
import 'dart:async';
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
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
    if (kDebugMode) {
      debugPrint('');
      debugPrint('='*60);
      debugPrint('📥 모바일 파일 다운로드 시작');
      debugPrint('='*60);
      debugPrint('🔗 URL: $url');
      debugPrint('📝 파일명: $filename');
      debugPrint('📱 플랫폼: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      debugPrint('');
    }
    
    // 1. HTTP GET 요청으로 파일 다운로드
    if (kDebugMode) {
      debugPrint('🌐 HTTP GET 요청 시작...');
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
      },
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('파일 다운로드 시간 초과 (30초)', const Duration(seconds: 30));
      },
    );
    
    if (kDebugMode) {
      debugPrint('✅ HTTP 응답 수신');
      debugPrint('   - 상태 코드: ${response.statusCode}');
      debugPrint('   - Content-Type: ${response.headers['content-type']}');
      debugPrint('   - Content-Length: ${response.headers['content-length'] ?? "N/A"}');
      debugPrint('   - 바디 크기: ${response.bodyBytes.length} bytes');
    }
    
    if (response.statusCode != 200) {
      throw HttpException(
        '파일 다운로드 실패: HTTP ${response.statusCode}\n'
        'URL: $url\n'
        '응답: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}'
      );
    }
    
    if (response.bodyBytes.isEmpty) {
      throw Exception('다운로드된 파일이 비어있습니다 (0 bytes)');
    }
    
    // 2. 임시 디렉토리 가져오기
    if (kDebugMode) {
      debugPrint('📂 임시 디렉토리 확인 중...');
    }
    
    final tempDir = await getTemporaryDirectory();
    final filePath = '${tempDir.path}/$filename';
    
    if (kDebugMode) {
      debugPrint('✅ 임시 디렉토리: ${tempDir.path}');
      debugPrint('📄 저장 경로: $filePath');
    }
    
    // 3. 파일 저장
    if (kDebugMode) {
      debugPrint('💾 파일 저장 중...');
    }
    
    final file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    
    // 파일 저장 확인
    final fileExists = await file.exists();
    final fileSize = await file.length();
    
    if (kDebugMode) {
      debugPrint('✅ 파일 저장 완료');
      debugPrint('   - 존재 여부: $fileExists');
      debugPrint('   - 파일 크기: $fileSize bytes');
    }
    
    if (!fileExists || fileSize == 0) {
      throw Exception('파일 저장 실패: 파일이 생성되지 않았거나 비어있습니다');
    }
    
    // 4. 네이티브 Share Sheet로 공유 (iOS/Android 자동 처리)
    if (kDebugMode) {
      debugPrint('📤 Share Sheet 실행 중...');
    }
    
    // iPad에서는 sharePositionOrigin이 필수 (팝오버 위치 지정)
    // iPhone에서는 무시됨
    final result = await Share.shareXFiles(
      [XFile(filePath)],
      text: '녹음 파일: $filename',
      subject: '통화 녹음',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 100, 100), // iPad용 팝오버 위치
    );
    
    if (kDebugMode) {
      debugPrint('✅ Share Sheet 결과: ${result.status}');
      debugPrint('='*60);
      debugPrint('');
    }
    
    // 5. 공유 완료 후 임시 파일 정리는 시스템이 자동으로 처리
    
  } on TimeoutException catch (e) {
    if (kDebugMode) {
      debugPrint('❌ 타임아웃 오류: $e');
    }
    throw Exception('네트워크 연결 시간 초과. 인터넷 연결을 확인하세요.');
  } on SocketException catch (e) {
    if (kDebugMode) {
      debugPrint('❌ 소켓 오류: $e');
      debugPrint('   - 주소: ${e.address}');
      debugPrint('   - 포트: ${e.port}');
      debugPrint('   - OS 오류: ${e.osError}');
    }
    throw Exception('네트워크 연결 실패. 서버에 접근할 수 없습니다.\n상세: ${e.message}');
  } on HttpException catch (e) {
    if (kDebugMode) {
      debugPrint('❌ HTTP 오류: $e');
    }
    rethrow;
  } on FileSystemException catch (e) {
    if (kDebugMode) {
      debugPrint('❌ 파일 시스템 오류: $e');
      debugPrint('   - 경로: ${e.path}');
      debugPrint('   - OS 오류: ${e.osError}');
    }
    throw Exception('파일 저장 실패. 저장 공간을 확인하세요.\n상세: ${e.message}');
  } catch (e, stackTrace) {
    if (kDebugMode) {
      debugPrint('❌ 알 수 없는 오류: $e');
      debugPrint('스택 추적:\n$stackTrace');
    }
    throw Exception('파일 다운로드 중 오류 발생.\n상세: $e');
  }
}
