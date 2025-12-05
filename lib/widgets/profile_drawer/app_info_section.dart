import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/version_check_service.dart';

/// 📱 앱 정보 섹션
/// 
/// 앱 버전 및 빌드 번호를 표시하는 위젯
/// 
/// Features:
/// - PackageInfo를 사용한 앱 버전 자동 조회
/// - Material Design 3 카드 스타일
/// - 다크 모드 지원
/// - 비동기 버전 정보 로딩
/// - 버전 체크 및 업데이트 안내
class AppInfoSection extends StatelessWidget {
  const AppInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final versionCheckService = VersionCheckService();

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
        child: FutureBuilder<VersionCheckResult>(
          future: versionCheckService.checkVersion(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              // 로딩 중
              return ListTile(
                leading: Icon(
                  Icons.phone_android, 
                  color: isDark ? Colors.green[300] : Colors.green,
                ),
                title: Text(
                  '앱 버전',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[200] : Colors.black87,
                  ),
                ),
                subtitle: const Text(
                  '확인 중...',
                  style: TextStyle(
                    fontSize: 12, 
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }
            
            final result = snapshot.data!;
            final version = result.currentVersion;
            
            return FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, pkgSnapshot) {
                final buildNumber = pkgSnapshot.data?.buildNumber ?? '1';
                
                return ListTile(
                  leading: Icon(
                    Icons.phone_android, 
                    color: isDark ? Colors.green[300] : Colors.green,
                  ),
                  title: Row(
                    children: [
                      Text(
                        '앱 버전',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[200] : Colors.black87,
                        ),
                      ),
                      // 업데이트 알림 아이콘 (업데이트 있을 때만)
                      if (result.isUpdateAvailable) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.error,
                          size: 18,
                          color: result.statusColor,
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        '$version ($buildNumber)',
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.grey[400] : Colors.black54,
                        ),
                      ),
                      if (result.isUpdateAvailable) ...[
                        const SizedBox(height: 4),
                        Text(
                          '최신 버전: ${result.latestVersion}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: result.statusColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
