import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// 🎨 화면 테마 설정 다이얼로그
/// 
/// 사용자가 라이트 모드, 다크 모드, 시스템 설정 중 선택할 수 있습니다.
class ThemeSettingsDialog extends StatelessWidget {
  const ThemeSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final currentThemeMode = themeProvider.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.brightness_6,
            color: isDark ? Colors.amber[300] : Colors.amber[700],
          ),
          const SizedBox(width: 12),
          const Text('화면 테마'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 라이트 모드
          _ThemeOptionTile(
            icon: Icons.light_mode,
            iconColor: isDark ? Colors.yellow[300]! : Colors.orange,
            title: '라이트 모드',
            subtitle: '밝은 화면으로 표시',
            isSelected: currentThemeMode == ThemeMode.light,
            onTap: () async {
              await themeProvider.setThemeMode(ThemeMode.light);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 8),
          
          // 다크 모드
          _ThemeOptionTile(
            icon: Icons.dark_mode,
            iconColor: isDark ? Colors.indigo[300]! : Colors.indigo,
            title: '다크 모드',
            subtitle: '어두운 화면으로 표시',
            isSelected: currentThemeMode == ThemeMode.dark,
            onTap: () async {
              await themeProvider.setThemeMode(ThemeMode.dark);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          const SizedBox(height: 8),
          
          // 시스템 설정
          _ThemeOptionTile(
            icon: Icons.brightness_auto,
            iconColor: isDark ? Colors.teal[300]! : Colors.teal,
            title: '시스템 설정',
            subtitle: '기기 설정에 따라 자동 전환',
            isSelected: currentThemeMode == ThemeMode.system,
            onTap: () async {
              await themeProvider.setThemeMode(ThemeMode.system);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

/// 테마 옵션 타일 위젯
class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? iconColor.withValues(alpha: 0.2)
                  : iconColor.withValues(alpha: 0.1))
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? iconColor
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // 아이콘
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? iconColor.withValues(alpha: 0.2)
                    : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            
            // 텍스트
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            // 선택 표시
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: iconColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
