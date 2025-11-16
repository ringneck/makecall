import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 📱 앱 정보 섹션
/// 
/// 앱 버전 및 빌드 번호를 표시하는 위젯
/// 
/// Features:
/// - PackageInfo를 사용한 앱 버전 자동 조회
/// - Material Design 3 카드 스타일
/// - 다크 모드 지원
/// - 비동기 버전 정보 로딩
class AppInfoSection extends StatelessWidget {
  const AppInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.green[700]! : Colors.green[100]!,
          ),
        ),
        child: FutureBuilder<PackageInfo>(
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) {
            final version = snapshot.data?.version ?? '1.0.0';
            final buildNumber = snapshot.data?.buildNumber ?? '1';
            return ListTile(
              leading: Icon(
                Icons.info, 
                color: isDark ? Colors.green[300] : Colors.green,
              ),
              title: Text(
                '앱 버전',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[200] : Colors.black87,
                ),
              ),
              subtitle: Text(
                '$version ($buildNumber)',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : Colors.black54,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
