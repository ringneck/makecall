import 'package:flutter/material.dart';
import '../../screens/profile/api_settings_dialog.dart';
import '../theme_settings_dialog.dart';

/// 🎯 일반 설정 섹션
/// 
/// 기본 API 설정 및 화면 테마 설정을 포함하는 통합 위젯
/// 
/// Features:
/// - 기본 API 설정 (REST, WebSocket)
/// - 화면 테마 설정 (라이트, 다크, 시스템)
/// - Material Design 3 카드 스타일
/// - 다크 모드 지원
class GeneralSettingsSection extends StatelessWidget {
  const GeneralSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 설정 서브 텍스트
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              '설정',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),

          // 기본 API 설정 카드
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Colors.blue[900]!.withValues(alpha: 0.3), Colors.blue[800]!.withValues(alpha: 0.3)]
                    : [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.blue[700]! : Colors.blue[200]!, 
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.blue[900]!.withValues(alpha: 0.5) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: isDark ? Colors.blue[300] : const Color(0xFF2196F3),
                ),
              ),
              title: Text(
                '기본 API 설정',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.blue[200] : Colors.blue[900],
                ),
              ),
              subtitle: Text(
                'REST, WebSocket 설정',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.blue[300] : Colors.blue[700],
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.blue[400] : Colors.blue[600],
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const ApiSettingsDialog(),
                );
              },
            ),
          ),
          
          const SizedBox(height: 12),

          // 화면 테마 카드
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark 
                    ? [Colors.amber[900]!.withValues(alpha: 0.3), Colors.orange[900]!.withValues(alpha: 0.3)]
                    : [Colors.amber[50]!, Colors.orange[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.amber[700]! : Colors.orange[200]!, 
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: isDark ? 0.2 : 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber[900]!.withValues(alpha: 0.5) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.brightness_6,
                  size: 20,
                  color: isDark ? Colors.amber[300] : Colors.orange[700],
                ),
              ),
              title: Text(
                '화면 테마',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.amber[200] : Colors.orange[900],
                ),
              ),
              subtitle: Text(
                '라이트 모드, 다크 모드, 시스템 설정',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.amber[300] : Colors.orange[700],
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark ? Colors.amber[400] : Colors.orange[600],
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => const ThemeSettingsDialog(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
