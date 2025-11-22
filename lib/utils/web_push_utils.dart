import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/fcm_service.dart';
import 'dialog_utils.dart';

/// 🌐 웹 푸시 알림 유틸리티
/// 
/// 웹 플랫폼에서 푸시 알림 권한 요청 및 토큰 관리를 담당하는 정적 유틸리티 클래스
/// 
/// Features:
/// - 웹 푸시 권한 요청 (브라우저 알림 API)
/// - FCM 토큰 생성 및 Firestore 저장
/// - 권한 상태에 따른 UI 피드백
/// - 다크 모드 지원 다이얼로그
class WebPushUtils {
  WebPushUtils._(); // Private constructor to prevent instantiation

  /// 웹 푸시 권한 요청
  /// 
  /// 웹 플랫폼에서만 동작하며, 브라우저 알림 권한을 요청하고
  /// FCM 토큰을 생성하여 Firestore에 저장합니다.
  /// 
  /// [context]: BuildContext for dialog display
  static Future<void> requestWebPushPermission(BuildContext context) async {
    if (!kIsWeb) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    try {
      // FCM 서비스 가져오기
      final fcmService = FCMService();
      final userId = AuthService().currentUser?.uid;
      
      if (userId == null) {
        if (context.mounted) {
          await DialogUtils.showError(context, '로그인이 필요합니다', duration: const Duration(seconds: 1));
        }
        return;
      }
      
      // 로딩 다이얼로그 표시
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('웹 푸시 알림 권한 요청 중...'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      
      // FCM 초기화 및 권한 요청
      await fcmService.initialize(userId);
      
      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      // 결과 확인
      final token = fcmService.fcmToken;
      if (token != null) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              icon: Icon(
                Icons.check_circle, 
                color: isDark ? Colors.green[300] : Colors.green, 
                size: 48,
              ),
              title: Text(
                '웹 푸시 알림 활성화 완료',
                style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '브라우저 알림이 활성화되었습니다.',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green[900]!.withAlpha(77) : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark ? Colors.green[700]! : Colors.green[200]!,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline, 
                              size: 16, 
                              color: isDark ? Colors.green[300] : Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '이제 다음 알림을 받을 수 있습니다:',
                              style: TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[300] : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• 수신 전화 알림', 
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                        Text(
                          '• 부재중 전화 알림', 
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                        Text(
                          '• 시스템 알림', 
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '💡 브라우저를 닫아도 알림을 받을 수 있습니다.',
                    style: TextStyle(
                      fontSize: 11, 
                      color: isDark ? Colors.grey[500] : Colors.grey,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      } else {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark ? Colors.grey[900] : Colors.white,
              icon: Icon(
                Icons.error, 
                color: isDark ? Colors.orange[300] : Colors.orange, 
                size: 48,
              ),
              title: Text(
                '알림 권한 필요',
                style: TextStyle(color: isDark ? Colors.grey[200] : Colors.black87),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '웹 푸시 알림을 받으려면 브라우저 알림 권한이 필요합니다.',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '브라우저 설정에서 알림 권한을 허용해주세요:',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '1. 브라우저 주소창 왼쪽의 자물쇠 아이콘 클릭', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                  Text(
                    '2. "알림" 또는 "Notifications" 찾기', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                  Text(
                    '3. "허용" 또는 "Allow"로 변경', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                  Text(
                    '4. 페이지 새로고침', 
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.black87,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ 웹 푸시 권한 요청 오류: $e');
      }
      
      // 로딩 다이얼로그가 열려있으면 닫기
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      if (context.mounted) {
        await DialogUtils.showError(context, '알림 권한 요청 중 오류 발생: $e');
      }
    }
  }
}
