import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

/// 🛑 서비스 이용 중지 섹션
/// 
/// Features:
/// - 사용자에게 이용 중지 안내 표시
/// - Firebase Authentication 계정 비활성화 처리
/// - Material Design 3 다이얼로그
/// - 다크 모드 지원
class ServiceSuspensionSection extends StatelessWidget {
  const ServiceSuspensionSection({super.key});

  /// 서비스 이용 중지 확인 다이얼로그 표시
  Future<void> _showSuspensionDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // 외부 터치로 닫기 방지
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: isDark ? Colors.orange[300] : Colors.orange[700],
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '서비스 이용중지 안내',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? Colors.red[900]!.withValues(alpha: 0.2) 
                        : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.red[700]! : Colors.red[200]!,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(
                        '1.',
                        '서비스 이용중지를 하시면 MAKECALL 주요서비스인 클릭투콜, 착신전환, 수신전화알림 등의 서비스를 이용하실 수 없습니다.',
                        isDark,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        '2.',
                        '서비스 이용중지를 하시더라도 서비스가 해지되는 것은 아니며 해지를 원하시는 경우는 영업사에 문의를 하여 주시기 바랍니다.',
                        isDark,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'MAKECALL 서비스 이용을 중지하시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            // 취소 버튼
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            
            // 이용 중지 버튼
            ElevatedButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // 다이얼로그 닫기
                await _handleServiceSuspension(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.red[700] : Colors.red[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                '이용 중지',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 정보 행 빌더
  Widget _buildInfoRow(String number, String text, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.red[300] : Colors.red[700],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }

  /// 서비스 이용 중지 처리
  Future<void> _handleServiceSuspension(BuildContext context) async {
    final authService = context.read<AuthService>();
    
    try {
      // 로딩 다이얼로그 표시
      _showLoadingDialog(context);
      
      // 계정 비활성화 처리
      await authService.suspendAccount();
      
      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // 성공 메시지 표시
        _showSuccessDialog(context);
      }
      
    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (context.mounted) {
        Navigator.of(context).pop();
        
        // 에러 메시지 표시
        _showErrorDialog(context, e.toString());
      }
    }
  }

  /// 로딩 다이얼로그 표시
  void _showLoadingDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: isDark ? Colors.blue[300] : Colors.blue,
              ),
              const SizedBox(height: 20),
              Text(
                '계정을 비활성화하는 중...',
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[300] : Colors.black87,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 성공 다이얼로그 표시
  void _showSuccessDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.check_circle,
                color: isDark ? Colors.green[300] : Colors.green,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '이용 중지 완료',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            'MAKECALL 서비스 이용이 중지되었습니다.\n로그인 화면으로 이동합니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // 다이얼로그 닫고 로그인 화면으로 이동
                  Navigator.of(context).pop();
                  // AuthService.signOut()이 자동으로 로그인 화면으로 이동시킴
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 에러 다이얼로그 표시
  void _showErrorDialog(BuildContext context, String error) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.error,
                color: isDark ? Colors.red[300] : Colors.red,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                '이용 중지 실패',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            '계정 비활성화 중 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.\n\n오류: $error',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey[300] : Colors.black87,
            ),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.red[900]!.withValues(alpha: 0.3) 
              : Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.red[700]! : Colors.red[100]!,
          ),
        ),
        child: ListTile(
          leading: Icon(
            Icons.block,
            color: isDark ? Colors.red[300] : Colors.red[700],
          ),
          title: Text(
            '서비스 이용 중지',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            'MAKECALL 서비스 이용을 일시 중지합니다',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.black54,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right,
            color: isDark ? Colors.red[300] : Colors.red[700],
          ),
          onTap: () => _showSuspensionDialog(context),
        ),
      ),
    );
  }
}
